#!/usr/bin/env bash
# Copy only public source roots. Never sweep private bootstrap or local state.
set -Eeuo pipefail
[[ $# == 2 ]] || { printf 'Usage: copy-source-fixture.sh SOURCE DESTINATION\n' >&2; exit 2; }
source_root="$1"
destination="$2"
mkdir -p -- "$destination"
for path in .config .local bin scripts services themes docs profiles bootstrap CONTRIBUTING.md LICENSE AGENTS.md CONTEXT.md README.md STATE.md BACKLOG.md system.yaml components.tsv install.sh .gitconfig .zprofile .zshrc .zshenv .gitattributes .gitignore; do
  if [[ -e "$source_root/$path" ]]; then
    cp -a -- "$source_root/$path" "$destination/"
  fi
done
