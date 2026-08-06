# dotfiles

Personal one-shot setup for a clean shell environment.

## Supported Systems

- Ubuntu 22.04 or newer and Debian 12 or newer
- Current Arch Linux and Arch-based distributions
- WSL2 running one of the supported Linux distributions
- Current macOS releases

Other Linux package managers are intentionally unsupported.

## Bootstrap

Install Git before cloning the repository. On Debian, Ubuntu, or an equivalent
WSL2 distribution:

```sh
sudo apt-get update
sudo apt-get install -y git
```

On Arch or an Arch-based WSL2 distribution:

```sh
sudo pacman -Syu --needed git
```

On a clean macOS installation, install the Command Line Tools and wait for the
installation to finish:

```sh
xcode-select --install
```

Then clone and run the installer as your regular user. The account must have
`sudo` access; do not run the installer itself with `sudo`.

```sh
git clone https://github.com/lork27/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Homebrew is installed automatically on macOS when it is missing. Its installer
may request a password or confirmation.

## Installed Tools

The script installs and configures:

- Git
- Zsh and Oh My Zsh
- tmux
- zoxide
- Neovim
- Fastfetch
- `dig`
- Ghostty terminfo for SSH sessions
- NVM
- The latest Node.js LTS release
- The latest pnpm release

Arch systems receive a full `pacman -Syu` upgrade before dependencies are
installed. Debian and Ubuntu use their configured APT repositories. If zoxide
or Fastfetch is unavailable through APT, the installer downloads it from the
project's upstream GitHub repository.

The installer automatically changes the login shell to Zsh. Start a new
terminal after it completes, or run:

```sh
exec zsh
```

## Configuration Links

All systems receive these links:

- `.zshrc` to `~/.zshrc`
- `.tmux.conf` to `~/.tmux.conf`

Native Linux and macOS also link `zed.settings.json` to
`~/.config/zed/settings.json`. macOS additionally links `kanata.kbd` to
`~/.config/kanata/kanata.kbd`.

WSL2 skips Zed and Kanata links because those applications normally run on the
Windows host. tmux clipboard copying uses `clip.exe` inside WSL2, `pbcopy` on
macOS, and `wl-copy` or `xclip` when available on native Linux.

Zed, Ghostty, and Kanata themselves are not installed automatically.

## Ghostty And SSH

Ghostty exports `TERM=xterm-ghostty`. The installer adds the appropriate
ncurses package and compiles the `xterm-ghostty` alias into `~/.terminfo` when
the operating system only provides a `ghostty` entry. If the entry remains
unavailable, `.zshrc` falls back to `TERM=xterm-256color` before Oh My Zsh is
loaded so that Backspace, Delete, and navigation keys continue to work.

## Backups And Recovery

Existing files are moved under
`~/.dotfiles-backups/<timestamp>-<process-id>/` before links are created. The
original directory structure is preserved. Incomplete Oh My Zsh and NVM
directories are backed up and reinstalled automatically.

To restore a file, remove its symlink and move the corresponding file from the
latest backup directory back to its original location.

## Verification

After opening a new terminal, verify the setup with:

```sh
command -v zsh tmux zoxide nvim fastfetch node npm pnpm
printf '%s\n' "$SHELL"
```

The installer accepts no configuration options because it is intended for
this repository's fixed personal setup. Use `./install.sh --help` to display
its usage summary.
