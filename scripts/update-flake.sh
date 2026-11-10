#!/usr/bin/env bash
set -euo pipefail
if (( $# != 0 )); then
  echo 'usage: update-flake.sh' >&2
  exit 2
fi
repo=/home/linux/github/kimseungsu-nixos/nixos
state="${XDG_RUNTIME_DIR:?}/nixos-rebuild-update"
mkdir -p "$state"
exec 9>"$state/lock"
flock 9
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 20 \
  --output /dev/null https://github.com/ || {
    echo 'Internet connection is required before rebuilding.' >&2
    exit 1
  }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Evaluate a separate copy so failed updates never alter the working lock file.
tar -C "$repo" --exclude=.git -cf - . | tar -C "$work" -xf -
cp "$work/flake.lock" "$work/original.lock"
cp "$work/flake.nix" "$work/original.flake.nix"
cd "$work"
export GIT_TERMINAL_PROMPT=0
nix flake update --accept-flake-config
nix eval --accept-flake-config --raw .#nixosConfigurations.linux.config.system.build.toplevel.drvPath > /dev/null
# Do not replace a lock edited while the update was running.
if ! cmp -s "$repo/flake.lock" "$work/original.lock" || \
   ! cmp -s "$repo/flake.nix" "$work/original.flake.nix"; then
  echo 'flake configuration changed concurrently; retrying later.' >&2
  exit 1
fi
if ! cmp -s "$work/flake.lock" "$repo/flake.lock"; then
  cp "$repo/flake.lock" "$state/previous.lock"
  updated_lock=$(mktemp "$repo/.flake.lock.XXXXXXXX")
  cp "$work/flake.lock" "$updated_lock"
  chmod --reference="$repo/flake.lock" "$updated_lock"
  mv -f "$updated_lock" "$repo/flake.lock"
  echo 'flake.lock updated and evaluated successfully; system switch is separate.'
else
  echo 'flake.lock is already up to date.'
fi
