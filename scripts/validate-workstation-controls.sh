#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
menu_dir="$repo_dir/.config/elephant/menus"
installer="$repo_dir/install.sh"
components="$repo_dir/components.tsv"

fail() {
  printf 'validate-workstation-controls: %s\n' "$*" >&2
  exit 1
}

for menu in workstation workstation-notifications workstation-tools workstation-capture; do
  file="$menu_dir/$menu.toml"
  [[ -f "$file" && ! -L "$file" ]] || fail "missing menu: $file"
  grep -Fqx "name = \"$menu\"" "$file" || fail "menu name does not match filename: $file"
  grep -Eq '^\[\[entries\]\]$' "$file" || fail "menu has no entries: $file"
done

[[ -f "$components" ]] || fail 'components.tsv is missing'

declared_executable() {
  local command_name="$1"
  awk -F '\t' -v command_name="$command_name" \
    '$1 !~ /^#/ && $3 == command_name { found = 1 } END { exit !found }' \
    "$components"
}

# Inspect the commands in the menu files themselves. components.tsv owns the
# package mapping; this check only prevents a typo or an undeclared helper from
# becoming reachable through Walker.
for menu in workstation workstation-notifications workstation-tools workstation-capture; do
  file="$menu_dir/$menu.toml"
  action_found=false
  while IFS= read -r action; do
    [[ -n "$action" ]] || continue
    action_found=true
    read -r command_name argument value _ <<< "$action"
    declared_executable "$command_name" || fail "$command_name is not declared in components.tsv ($menu.toml)"
    if [[ "$command_name" == session-terminal ]]; then
      [[ "$argument" == '-e' && -n "$value" ]] || fail "invalid session-terminal action: $action"
      declared_executable "$value" || fail "$value is not declared in components.tsv ($menu.toml)"
    fi
  done < <(sed -nE 's/.*actions = \{[^\"]*\"[^\"]*\" = \"([^\"]+)\".*/\1/p' "$file")
  [[ "$action_found" == true ]] || fail "$menu.toml contains no actions"
done

grep -Fq 'walker --provider clipboard' "$menu_dir/workstation.toml" || fail 'clipboard Walker command is missing'
grep -Fq 'walker --provider symbols' "$menu_dir/workstation.toml" || fail 'symbols Walker command is missing'
grep -Fq 'walker --provider windows' "$menu_dir/workstation.toml" || fail 'windows Walker command is missing'
grep -Fq '"workstation-controls power"' "$menu_dir/workstation.toml" || fail 'native power controls are not exposed'
[[ ! -e "$menu_dir/power.toml" ]] || fail 'retired power menu remains'
grep -Fq 'submenu = "workstation-notifications"' "$menu_dir/workstation.toml" || fail 'notifications menu is not exposed'

for menu in workstation workstation-notifications workstation-tools workstation-capture; do
  grep -Fq ".config/elephant/menus/$menu.toml" "$installer" ||
    fail "$menu.toml is not deployed by install.sh"
  while IFS= read -r submenu; do
    [[ -f "$menu_dir/$submenu.toml" ]] || fail "missing submenu: $submenu"
    grep -Fq ".config/elephant/menus/$submenu.toml" "$installer" ||
      fail "submenu $submenu.toml is not deployed by install.sh"
  done < <(sed -n 's/^submenu = "\([^"]*\)"$/\1/p' "$menu_dir/$menu.toml")
done

printf 'workstation controls validation passed.\n'
