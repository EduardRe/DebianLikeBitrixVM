#!/usr/bin/env bash

menu_update_branch() {
  local installed=$1 os_release=${2:-/etc/os-release}
  local ID= VERSION_ID=
  [[ -r "$os_release" ]] || return 1
  source "$os_release"
  case "$ID:$VERSION_ID" in
    debian:12|debian:13) ;;
    *) return 1 ;;
  esac
  local pattern="^${VERSION_ID}\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"
  [[ "$installed" == 1.2.0 || "$installed" == 1.2.1 || "$installed" =~ $pattern ]] || return 1
  printf '%s.x\n' "$VERSION_ID"
}

menu_version_is_newer() {
  local version=$1
  local pattern="^${BS_BRANCH_UPDATE_MENU%.x}\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"
  [[ -n "$BS_BRANCH_UPDATE_MENU" && "$version" =~ $pattern ]] &&
    dpkg --compare-versions "$version" gt "$BS_VERSION_MENU"
}

menu_update_cache_is_fresh() {
  local now mtime
  [[ ${BS_CHECK_UPDATE_MENU_MINUTES:-} =~ ^[1-9][0-9]*$ ]] || return 1
  [[ -n "$BS_BRANCH_UPDATE_MENU" && -f "$BS_MENU_UPDATE_CACHE" ]] || return 1
  now=$(date +%s) || return 1
  mtime=$(stat -c %Y -- "$BS_MENU_UPDATE_CACHE") || return 1
  (( now >= mtime && now - mtime < BS_CHECK_UPDATE_MENU_MINUTES * 60 ))
}

action_check_new_version_menu() {
  local config version= pending
  [[ -n "$BS_BRANCH_UPDATE_MENU" && ${BS_CHECK_UPDATE_MENU_MINUTES:-} =~ ^[1-9][0-9]*$ ]] || return 0
  menu_update_cache_is_fresh && return 0
  if config=$(curl --fail --silent --location --connect-timeout 3 --max-time 5 "$BS_REPOSITORY_URL_FILE_VERSION"); then
    version=$(sed -nE 's/^BS_VERSION_MENU="([^"]*)"[[:space:]]*$/\1/p' <<< "$config")
  fi
  menu_version_is_newer "$version" || version=
  install -d -m 0700 -- "${BS_MENU_UPDATE_CACHE%/*}" || return 1
  pending=$(mktemp -- "${BS_MENU_UPDATE_CACHE}.XXXXXXXX") || return 1
  if ! printf '%s\n' "$version" > "$pending" || ! mv -fT -- "$pending" "$BS_MENU_UPDATE_CACHE"; then
    rm -f -- "$pending"
    return 1
  fi
}

available_menu_update() {
  local version
  menu_update_cache_is_fresh || return 1
  read -r version < "$BS_MENU_UPDATE_CACHE" || return 1
  menu_version_is_newer "$version" || return 1
  printf '%s\n' "$version"
}
