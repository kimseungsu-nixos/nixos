#!/usr/bin/env bash
set -euo pipefail

repo=/home/linux/github/kimseungsu-nixos/nixos
action=${1:-switch}
case "$action" in
  build|switch|test|boot) shift || true ;;
  *) echo 'usage: rebuild.sh [build|switch|test|boot] [nixos-rebuild options...]' >&2; exit 2 ;;
esac

"$repo/scripts/update-flake.sh"
exec nixos-rebuild --sudo "$action" --flake "$repo#linux" "$@"
