#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
repo=${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/package-repo
case ${1:-} in
  publish)
    [[ $# == 2 ]] || { echo "Usage: $0 publish PACKAGE" >&2; exit 2; }
    command -v repo-add >/dev/null || { echo 'Arch repo-add is required.' >&2; exit 1; }
    bash "$root/scripts/validate-rustdesk.sh" --package "$2"
    mkdir -p "$repo"
    cp -- "$2" "$repo/$(basename -- "$2")"
    repo-add "$repo/workstation-local.db.tar.gz" "$repo/$(basename -- "$2")"
    ;;
  serve)
    [[ $# == 1 && -f $repo/workstation-local.db ]] || {
      echo 'Publish a validated native package before serving the local repository.' >&2; exit 1;
    }
    echo 'Keep this process running throughout sudo akshara update.'
    exec python3 -m http.server 18789 --bind 127.0.0.1 --directory "$repo"
    ;;
  *) echo "Usage: $0 {publish PACKAGE|serve}" >&2; exit 2 ;;
esac
