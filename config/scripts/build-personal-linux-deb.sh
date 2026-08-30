#!/usr/bin/env bash
# Build a personal Linux .deb from this checkout (optionally syncing upstream first).
# Usage:
#   ./config/scripts/build-personal-linux-deb.sh
#   ./config/scripts/build-personal-linux-deb.sh --no-sync
#   ./config/scripts/build-personal-linux-deb.sh --install
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

SYNC=1
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --no-sync) SYNC=0 ;;
    --install) INSTALL=1 ;;
    -h | --help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script only packages Linux .deb builds." >&2
  exit 1
fi

if [[ "$SYNC" -eq 1 ]]; then
  if ! git remote get-url upstream >/dev/null 2>&1; then
    git remote add upstream https://github.com/stablyai/orca.git
  fi
  git fetch upstream main
  echo "Merging upstream/main into $(git branch --show-current)..."
  git merge --no-edit upstream/main
fi

pnpm install
pnpm run build:desktop
pnpm run ensure:electron-runtime
pnpm exec electron-builder --config config/electron-builder.config.cjs --linux deb --publish never

shopt -s nullglob
deb_files=(dist/*.deb)
if (( ${#deb_files[@]} == 0 )); then
  echo "No .deb found in dist/" >&2
  exit 1
fi

echo "Built:"
printf '  %s\n' "${deb_files[@]}"

if [[ "$INSTALL" -eq 1 ]]; then
  latest="$(ls -1t "${deb_files[@]}" | head -n1)"
  echo "Installing $latest..."
  sudo dpkg -i "$latest" || sudo apt-get install -f -y
fi
