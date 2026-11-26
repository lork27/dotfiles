#!/usr/bin/env bash

# Push this machine's herdr saved-machine catalog (~/.local/state/herdr/client/endpoints.json)
# to every other saved machine over SSH, so every herdr client shows the same machine list.
#
# Herdr deliberately refuses to write this catalog through a symlink, so instead of
# linking it from the dotfiles we keep a copy here and sync it explicitly:
#
#   ./herdr-sync-machines.sh            # push local catalog to all saved machines
#   ./herdr-sync-machines.sh --pull     # fetch the catalog from a machine instead
#
# After replacing the file on a machine, its running herdr client reloads the
# saved machines automatically.

set -Eeuo pipefail

readonly CATALOG="$HOME/.local/state/herdr/client/endpoints.json"
readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

[[ -f "$CATALOG" ]] || die "no local herdr endpoint catalog at $CATALOG"
command -v jq >/dev/null 2>&1 || die "jq is required"

remote_catalog_path() {
  # herdr keeps the catalog in the XDG state dir on both macOS and Linux clients.
  printf '~/.local/state/herdr/client/endpoints.json\n'
}

push_to() {
  local target="$1"
  printf '==> pushing to %s\n' "$target"
  ssh -n -o ConnectTimeout=15 "$target" 'mkdir -p "$HOME/.local/state/herdr/client"' || return 1
  scp -q -o ConnectTimeout=15 "$CATALOG" "$target:.local/state/herdr/client/endpoints.json.tmp" < /dev/null || return 1
  ssh -n -o ConnectTimeout=15 "$target" 'chmod 600 "$HOME/.local/state/herdr/client/endpoints.json.tmp" && mv "$HOME/.local/state/herdr/client/endpoints.json.tmp" "$HOME/.local/state/herdr/client/endpoints.json"' || return 1
}

pull_from() {
  local target="$1"
  printf '==> pulling from %s\n' "$target"
  scp -q -o ConnectTimeout=15 "$target:$(remote_catalog_path)" "$CATALOG" < /dev/null || return 1
}

case "${1:-push}" in
  push)
    while IFS= read -r target; do
      push_to "$target" || printf 'Warning: failed to push to %s\n' "$target" >&2
    done < <(jq -r '.ssh[] | select(.enabled) | .target' "$CATALOG")
    ;;
  pull)
    [[ "${2:-}" == "${2#-}" && -n "${2:-}" ]] || die "pull needs a target: ./herdr-sync-machines.sh pull <ssh-target>"
    pull_from "$2"
    printf 'Catalog replaced locally; review with: git diff herdr-endpoints.json\n'
    ;;
  *)
    die "usage: ./herdr-sync-machines.sh [push | pull <ssh-target>]"
    ;;
esac

# Keep the dotfiles copy in sync with the local catalog.
cp "$CATALOG" "$SCRIPT_DIR/herdr-endpoints.json"
