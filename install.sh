#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_ROOT="$HOME/.dotfiles-backups"

PACKAGE_MANAGER=""
IS_WSL=false
BACKUP_DIR=""
LAST_BACKUP_DESTINATION=""

info() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install.sh

Set up these dotfiles on Debian/Ubuntu, Arch, WSL2, or macOS.
EOF
}

if [[ "$#" -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
fi

run_privileged() {
  command -v sudo >/dev/null 2>&1 || die "sudo is required to install system packages"
  sudo "$@"
}

detect_platform() {
  [[ "${EUID}" -ne 0 ]] || die "run this installer as your regular user, not as root"

  case "$(uname -s)" in
    Darwin)
      PACKAGE_MANAGER=brew
      ;;
    Linux)
      case "$(uname -r)" in
        *[Mm]icrosoft*|*WSL*) IS_WSL=true ;;
      esac

      if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER=apt
      elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER=pacman
      else
        die "unsupported Linux distribution; apt or pacman is required"
      fi
      ;;
    *)
      die "unsupported operating system: $(uname -s)"
      ;;
  esac
}

install_homebrew() {
  local brew_path
  local installer

  if ! command -v brew >/dev/null 2>&1; then
    command -v curl >/dev/null 2>&1 || die "curl is required to install Homebrew"
    installer="$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")"
    info "Installing Homebrew"

    if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
      rm -f "$installer"
      die "could not download the Homebrew installer"
    fi
    if ! /bin/bash "$installer"; then
      rm -f "$installer"
      die "could not install Homebrew"
    fi
    rm -f "$installer"
  fi

  if command -v brew >/dev/null 2>&1; then
    brew_path="$(command -v brew)"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew_path=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_path=/usr/local/bin/brew
  else
    die "Homebrew was installed but could not be found"
  fi

  eval "$("$brew_path" shellenv)"
}

apt_package_is_available() {
  apt-cache show "$1" >/dev/null 2>&1
}

install_zoxide_fallback() {
  local installer

  command -v zoxide >/dev/null 2>&1 && return 0
  installer="$(mktemp "${TMPDIR:-/tmp}/zoxide-install.XXXXXX")"
  info "Installing zoxide from its upstream installer"

  if ! curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o "$installer"; then
    rm -f "$installer"
    die "could not download the zoxide installer"
  fi

  if ! bash "$installer"; then
    rm -f "$installer"
    die "could not install zoxide"
  fi
  rm -f "$installer"
}

install_fastfetch_fallback() {
  local architecture
  local asset_architecture
  local package_file

  command -v fastfetch >/dev/null 2>&1 && return 0
  architecture="$(dpkg --print-architecture)"

  case "$architecture" in
    amd64) asset_architecture=amd64 ;;
    arm64) asset_architecture=aarch64 ;;
    *)
      warn "Fastfetch is unavailable for Debian architecture: $architecture"
      return 0
      ;;
  esac

  package_file="$(mktemp "${TMPDIR:-/tmp}/fastfetch.XXXXXX.deb")"
  info "Installing Fastfetch from its latest upstream Debian package"

  if ! curl -fL \
    "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${asset_architecture}-polyfilled.deb" \
    -o "$package_file"; then
    rm -f "$package_file"
    die "could not download Fastfetch"
  fi

  if ! run_privileged apt-get install -y "$package_file"; then
    rm -f "$package_file"
    die "could not install Fastfetch"
  fi
  rm -f "$package_file"
}

install_apt_packages() {
  local packages=(curl dnsutils git ncurses-bin ncurses-term neovim tmux zsh)

  info "Updating APT package metadata"
  run_privileged apt-get update

  if apt_package_is_available zoxide; then
    packages+=(zoxide)
  fi
  if apt_package_is_available fastfetch; then
    packages+=(fastfetch)
  fi

  info "Installing APT packages: ${packages[*]}"
  run_privileged apt-get install -y "${packages[@]}"
  install_zoxide_fallback
  install_fastfetch_fallback
}

install_pacman_packages() {
  local packages=(bind curl fastfetch git ncurses neovim tmux zoxide zsh)

  info "Updating Arch and installing packages: ${packages[*]}"
  run_privileged pacman -Syu --needed --noconfirm "${packages[@]}"
}

install_brew_packages() {
  local packages=(fastfetch git ncurses neovim tmux zoxide)

  install_homebrew
  info "Installing Homebrew packages: ${packages[*]}"
  brew install "${packages[@]}"
}

install_packages() {
  case "$PACKAGE_MANAGER" in
    apt) install_apt_packages ;;
    pacman) install_pacman_packages ;;
    brew) install_brew_packages ;;
  esac
}

install_ghostty_terminfo() {
  local infocmp_command=infocmp
  local tic_command=tic
  local ncurses_prefix

  if infocmp -x xterm-ghostty >/dev/null 2>&1; then
    info "Ghostty terminfo is already available"
    return 0
  fi

  if [[ "$PACKAGE_MANAGER" == brew ]]; then
    ncurses_prefix="$(brew --prefix ncurses)"
    infocmp_command="$ncurses_prefix/bin/infocmp"
    tic_command="$ncurses_prefix/bin/tic"
  fi

  if [[ ! -x "$(command -v "$infocmp_command" 2>/dev/null || true)" ]] ||
    [[ ! -x "$(command -v "$tic_command" 2>/dev/null || true)" ]]; then
    warn "Cannot install Ghostty terminfo because infocmp or tic is unavailable"
    return 0
  fi

  if ! "$infocmp_command" -x ghostty >/dev/null 2>&1; then
    warn "No Ghostty terminfo source is available; Zsh will use xterm-256color over SSH"
    return 0
  fi

  info "Installing the xterm-ghostty terminfo entry"
  mkdir -p "$HOME/.terminfo"
  if ! "$infocmp_command" -x ghostty |
    sed 's/^ghostty|/xterm-ghostty|ghostty|/' |
    "$tic_command" -x -o "$HOME/.terminfo" -; then
    warn "Could not install xterm-ghostty terminfo; Zsh will use xterm-256color over SSH"
  fi
}

backup_path() {
  local destination="$1"
  local relative_path
  local backup_destination

  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)-$$"
  fi

  relative_path="${destination#"$HOME"/}"
  backup_destination="$BACKUP_DIR/$relative_path"
  LAST_BACKUP_DESTINATION="$backup_destination"

  mkdir -p "$(dirname "$backup_destination")"
  mv "$destination" "$backup_destination"
  info "Backed up $destination to $backup_destination"
}

clone_repository() {
  local name="$1"
  local url="$2"
  local destination="$3"
  local marker="$4"
  local temporary_directory

  if [[ -f "$destination/$marker" ]]; then
    info "$name already exists; leaving it unchanged"
    return 0
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    warn "$name is incomplete; backing it up before reinstalling"
    backup_path "$destination"
  fi

  temporary_directory="$(mktemp -d "${destination}.tmp.XXXXXX")"
  info "Installing $name"

  if ! git clone --depth=1 "$url" "$temporary_directory"; then
    rm -rf "$temporary_directory"
    die "could not clone $name"
  fi

  if [[ ! -f "$temporary_directory/$marker" ]]; then
    rm -rf "$temporary_directory"
    die "the cloned $name repository is incomplete"
  fi

  if ! mv "$temporary_directory" "$destination"; then
    rm -rf "$temporary_directory"
    die "could not install $name"
  fi
}

install_oh_my_zsh() {
  clone_repository "Oh My Zsh" \
    https://github.com/ohmyzsh/ohmyzsh.git \
    "$HOME/.oh-my-zsh" \
    oh-my-zsh.sh
}

install_nvm() {
  clone_repository "NVM" \
    https://github.com/nvm-sh/nvm.git \
    "$HOME/.nvm" \
    nvm.sh
}

install_node_and_pnpm() {
  export NVM_DIR="$HOME/.nvm"
  set +eu
  # shellcheck source=/dev/null
  if ! source "$NVM_DIR/nvm.sh"; then
    set -eu
    die "could not load NVM"
  fi

  info "Installing the latest Node.js LTS release"
  if ! nvm install --lts --latest-npm; then
    set -eu
    die "could not install Node.js"
  fi
  if ! nvm alias default 'lts/*' || ! nvm use default; then
    set -eu
    die "could not activate the default Node.js release"
  fi

  info "Installing pnpm"
  if ! npm install --global pnpm@latest; then
    set -eu
    die "could not install pnpm"
  fi
  set -eu
}

link_file() {
  local source_relative="$1"
  local destination_relative="$2"
  local source="$SCRIPT_DIR/$source_relative"
  local destination="$HOME/$destination_relative"
  local temporary_link="${destination}.dotfiles.$$"
  local destination_was_backed_up=false

  [[ -e "$source" ]] || die "missing source file: $source"

  if [[ -L "$destination" ]] && [[ "$(readlink "$destination")" == "$source" ]]; then
    info "Already linked: $destination"
    return 0
  fi

  mkdir -p "$(dirname "$destination")"
  [[ ! -e "$temporary_link" && ! -L "$temporary_link" ]] || die "temporary link already exists: $temporary_link"
  ln -s "$source" "$temporary_link"

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_path "$destination"
    destination_was_backed_up=true
  fi

  if ! mv "$temporary_link" "$destination"; then
    if [[ "$destination_was_backed_up" == true ]]; then
      if ! mv "$LAST_BACKUP_DESTINATION" "$destination"; then
        warn "Could not restore the backup at $LAST_BACKUP_DESTINATION"
      fi
    fi
    die "could not install link: $destination"
  fi
  info "Linked $destination"
}

link_dotfiles() {
  link_file .zshrc .zshrc
  link_file .tmux.conf .tmux.conf

  if [[ "$IS_WSL" == true ]]; then
    info "Skipping native GUI configuration links inside WSL2"
  else
    link_file zed.settings.json .config/zed/settings.json
  fi

  if [[ "$PACKAGE_MANAGER" == brew ]]; then
    link_file kanata.kbd .config/kanata/kanata.kbd
  fi
}

set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [[ -n "$zsh_path" ]] || die "zsh was installed but could not be found"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    info "zsh is already the default shell"
    return 0
  fi

  info "Setting zsh as the default shell"
  chsh -s "$zsh_path"
}

main() {
  detect_platform
  info "Using package manager: $PACKAGE_MANAGER"
  [[ "$IS_WSL" == true ]] && info "Detected WSL2"

  install_packages
  install_ghostty_terminfo
  install_oh_my_zsh
  install_nvm
  install_node_and_pnpm
  link_dotfiles
  set_default_shell

  info "Installation complete"
  info "Start a new terminal or run: exec zsh"
}

main "$@"
