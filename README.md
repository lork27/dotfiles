# dotfiles

Personal one-shot setup for a clean shell environment.

## Supported Systems

- Ubuntu 22.04 or newer and Debian 12 or newer
- Current Arch Linux and Arch-based distributions
- WSL2 running one of the supported Linux distributions
- Current macOS releases
- The Windows host of a WSL2 setup, configured with `windows\apply.ps1` (see
  below); `install.sh` itself only runs on Linux and macOS

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
- Neru (keyboard-driven mouse control)
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
`~/.config/zed/settings.json`, `ghostty.config` to `~/.config/ghostty/config`,
`neru.toml` to `~/.config/neru/config.toml`, and
`herdr.toml` to `~/.config/herdr/config.toml`, plus the YoRHa theme files under
`themes/` (see below).

Herdr's saved SSH machine list lives in per-client state
(`~/.local/state/herdr/client/endpoints.json`) and herdr refuses to write it
through a symlink, so it is not linked from these dotfiles. Instead, the
catalog is kept as `herdr-endpoints.json` and `./herdr-sync-machines.sh` pushes
it to every saved machine over SSH (`--pull <ssh-target>` fetches one back).
macOS additionally links `kanata.kbd` to `~/.config/kanata/kanata.kbd`.

WSL2 skips the Zed, Kanata, Neru, and Herdr links because those applications normally
run on the Windows host. tmux clipboard copying uses `clip.exe` inside WSL2,
`pbcopy` on macOS, and `wl-copy` or `xclip` when available on native Linux.

Zed, Ghostty, and Kanata themselves are not installed automatically. Neru is:
on macOS it is installed from the `y3owk1n/tap` Homebrew cask, and on Linux the
installer downloads the release build from the upstream project after adding
the required runtime libraries.

## YoRHa Themes

`themes/` holds the NieR: Automata YoRHa palettes shared across this machine's
apps, so light/dark mode follows the OS appearance everywhere:

- `themes/zed/yorha.json` links to `~/.config/zed/themes/yorha.json` and provides
  Zed's `Yorha` (light) and `Yorha Dark` themes; `zed.settings.json` selects them
  with `"theme": {"mode": "system", ...}`.
- `themes/ghostty/yorha` and `themes/ghostty/yorha-dark` link into
  `~/.config/ghostty/themes/`; the Ghostty config selects them with
  `theme = light:yorha,dark:yorha-dark`.
- `themes/vscode/yorha-*.vsix` is installed as the `yorha.yorha-theme` VS Code
  extension (only when the `code` CLI is available); VS Code settings select it
  with `window.autoDetectColorScheme` plus
  `workbench.preferredLightColorTheme`/`workbench.preferredDarkColorTheme`.
- `themes/vscode/yorha-theme/` is the extension source; run
  `themes/vscode/build-vsix.sh` after editing it, then commit the rebuilt vsix.
- `themes/windows-terminal/yorha.schemes.json` holds the `Yorha` (light) and
  `Yorha Dark` color schemes. `windows\apply.ps1` merges them into Windows Terminal's
  own `settings.json` and sets `profiles.defaults.colorScheme` to the scheme for this
  machine. In each scheme the slot on the background side (`black` in Yorha Dark,
  `white` in Yorha) equals the background, as in Windows Terminal's built-in schemes;
  ink, paper, hues and selection colors match `themes/ghostty/*`. Two Windows Terminal
  details: a Microsoft Store install keeps its settings under
  `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\`
  (only `Fragments\` under `%LOCALAPPDATA%\Microsoft\Windows Terminal\` is read from
  there), and the palette is resolved when the process starts, so quit it completely
  and relaunch after any change. Herdr's `theme = "terminal"` follows this palette when
  it runs inside Windows Terminal.

## Windows Host

The Windows side of these dotfiles is applied with PowerShell instead of `install.sh`,
because Windows apps rewrite their own config files (so files are copied, not linked):

```powershell
powershell -NoProfile -File windows\apply.ps1     # -Light / -Dark override the detected mode
```

The script is idempotent, stops on the first error, backs a replaced file up to
`<name>.bak` once (the pre-dotfiles original is never overwritten), and applies:

- `windows\zed.settings.json` to `%APPDATA%\Zed\settings.json`, plus
  `themes\zed\yorha.json` to `%APPDATA%\Zed\themes\yorha.json`. Zed rewrites its own
  settings file, so it is replaced wholesale - edit `windows\zed.settings.json` instead
  of adding settings in `%APPDATA%`.
- `herdr.toml` (the same file as on macOS/Linux) to
  `%APPDATA%\herdr\config.toml`
- `themes\windows-terminal\yorha.schemes.json` merged into Windows Terminal's
  `settings.json` (Store installs: `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\`).
  The merge rewrites that file, so comments in it are lost; a file it cannot parse
  (for example one with `//` comments) is skipped with a message rather than rewritten.
- `windows\powershell.profile.ps1` to
  `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (the Windows PowerShell
  5.1 path, resolved from the user's Documents folder; PowerShell 7 uses
  `Documents\PowerShell\` and is not covered)

The PowerShell profile is the Windows counterpart of `.zshrc`: it launches Claude Code
with the matching `light-ansi`/`dark-ansi` theme and picks the palette mode. It does not
set console colors - those come from the Windows Terminal scheme, since Windows PowerShell
offers only the 16 named console colors. The mode follows Windows' own app appearance
setting
(`HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme`,
0 = dark), mirroring how `.zshrc` reads `AppleInterfaceStyle` on macOS. Precedence is
`apply.ps1 -Light`/`-Dark`, then `YORHA_MODE=light|dark`, then the Windows setting.

## Neru

Neru is a keyboard-driven mouse controller (hints, grids, and vim keys). The
installer links `neru.toml` to `~/.config/neru/config.toml` and, on Linux,
registers a login service that starts the daemon at every session.

After the install:

- macOS: grant Accessibility (and Input Monitoring, for OCR hints) in
  System Settings › Privacy & Security, then start the daemon with
  `neru launch` or register it for login with `neru services install`.
- Linux: the daemon starts at login automatically. On Wayland, log out and back
  in once so the `input` group membership takes effect.

The default hotkeys are `Super+Shift+Space` (hints), `Super+Shift+G` (grid),
`Super+Shift+C` (recursive grid), `Super+Shift+B` (bisect), and
`Super+Shift+S` (scroll). `Super` is the Command key on macOS and the Super key
on Linux.

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
