#!/usr/bin/env bash
# Thin wrapper around nixos-rebuild for interactive use.
#
#   pkexec ./rebuild.sh boot
#   pkexec ./rebuild.sh switch
#   NIXOS_HOST=sashi-letsnote ./rebuild.sh boot
#
# The automatic timer does NOT use this script; it rebuilds directly from the
# remote flake (see system/core/auto-upgrade.nix).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The machine was originally installed as sashi-mainpc; map the old hostname
# until `hostnamectl set-hostname sashi-main` has been run.
HOST="${NIXOS_HOST:-$(hostname)}"
case "$HOST" in
  sashi-mainpc) HOST="sashi-main" ;;
esac

ACTION="${1:-switch}"
if [[ $# -gt 0 ]]; then
  shift
fi

exec nixos-rebuild "$ACTION" \
  --flake "${REPO_DIR}#${HOST}" \
  "$@"
