#!/usr/bin/env bash
set -euo pipefail

repo=/home/linux/github/kimseungsu-nixos/nixos
action=${1:-switch}
case "$action" in
  build|switch|test|boot) shift || true ;;
  *) echo 'usage: rebuild.sh [build|switch|test|boot] [nixos-rebuild options...]' >&2; exit 2 ;;
esac

systemd-run --user --scope --quiet --property=CPUQuota=800% -- \
  "$repo/scripts/update-flake.sh"
# A root Nix invocation builds locally instead of using nix-daemon. Put the
# entire process tree in its own scope so the CPU limit covers those workers too.
exec sudo systemd-run --scope --quiet \
  --property=CPUQuota=800% --property=CPUWeight=25 \
  nixos-rebuild "$action" --flake "$repo#linux" --max-jobs 2 --cores 4 "$@"
