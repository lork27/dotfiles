# AGENTS.md

Personal dotfiles for Debian/Ubuntu, Arch, WSL2, and macOS. `install.sh` installs
tools and symlinks the tracked config files into `$HOME`. See `README.md` for
the full list of links and per-platform behavior.

## Rules

1. **Always check upstream first.** Before reading, editing, or committing
   anything, run `git fetch origin` and compare with `git status` /
   `git log HEAD..origin/main`. These dotfiles are edited from several
   machines, so the remote may have newer changes. If the branch is behind,
   pull (`git pull --rebase`) before making changes; if it has diverged, stop
   and tell the user instead of guessing.
2. **Files here are live.** Most files are symlinked into `~/.config` and
   `$HOME`, so editing them changes the running setup immediately. Keep edits
   minimal and don't reformat whole files.
3. **Keep `install.sh` and `README.md` in sync.** When adding, removing, or
   renaming a tracked config, update both the `link_file` calls in `install.sh`
   and the "Configuration Links" section of `README.md`. Respect the WSL2 skips.
4. **`install.sh` must stay idempotent and safe.** Keep `set -Eeuo pipefail`,
   back up existing files via `backup_path`, never run as root, and only support
   apt, pacman, and Homebrew. Check it with `bash -n install.sh` (and
   `shellcheck` if available).
5. **Themes.** After editing `themes/vscode/yorha-theme/`, run
   `themes/vscode/build-vsix.sh` and commit the rebuilt `.vsix`. Keep the Zed,
   Ghostty, and VS Code YoRHa palettes consistent.
6. **No secrets.** Don't commit tokens, keys, or host-specific credentials.
   `herdr-endpoints.json` is synced with `./herdr-sync-machines.sh`, not linked.
7. **Commits.** Only commit or push when asked. Use the existing message style:
   `<area>: <short description>` (for example `zed: ...`, `themes: ...`).
