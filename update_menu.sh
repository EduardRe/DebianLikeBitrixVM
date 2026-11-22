#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'Menu update failed: %s\n' "$*" >&2
  exit 1
}

read_menu_version() {
  sed -nE 's/^BS_VERSION_MENU="([^"]*)"[[:space:]]*$/\1/p' "$1"
}

update_menu() {
  local root=$1 os_release=$2 expected_branch=${3:-}
  local menu="$root/vm_menu" link="$root/menu.sh"
  local installed candidate_version branch work backup= candidate file
  local ID= VERSION_ID=

  [[ -r "$os_release" ]] || fail "Cannot read $os_release."
  source "$os_release"
  case "$ID:$VERSION_ID" in
    debian:12|debian:13) branch="$VERSION_ID.x" ;;
    *) fail "Unsupported system: $ID $VERSION_ID." ;;
  esac
  [[ -z "$expected_branch" || "$expected_branch" == "$branch" ]] ||
    fail "Requested branch $expected_branch does not match Debian $VERSION_ID."

  exec 9>"$root/.dlbv-menu-update.lock"
  flock -n 9 || fail "Another menu update is already running."
  [[ -d "$menu" && ! -L "$menu" && -r "$menu/bash_scripts/config.sh" ]] ||
    fail "Cannot find the installed menu at $menu."
  installed=$(read_menu_version "$menu/bash_scripts/config.sh")
  local version_pattern="^${VERSION_ID}\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"
  if [[ "$installed" != 1.2.0 && "$installed" != 1.2.1 && ! "$installed" =~ $version_pattern ]]; then
    fail "Installed version does not belong to $branch. A change of Debian release requires a separate migration."
  fi
  if [[ -L "$link" ]]; then
    [[ "$(readlink -f -- "$link")" == "$menu/menu.sh" ]] || fail "Unexpected menu link: $link."
  elif [[ -e "$link" ]]; then
    fail "Cannot create the menu link: $link already exists."
  fi

  work=$(mktemp -d -- "$root/.dlbv-menu-update.XXXXXXXX")
  # Keep the cleanup trap inside the staging and replacement step.
  (
    cleanup() {
      local result=$?
      if [[ -n "$backup" && -d "$backup/vm_menu" && ! -e "$menu" ]]; then
        if ! mv -T -- "$backup/vm_menu" "$menu"; then
          printf 'Restore the previous menu from %s/vm_menu\n' "$backup" >&2
          result=1
        fi
      fi
      rm -rf -- "$work"
      exit "$result"
    }
    trap cleanup EXIT
    trap 'exit 1' HUP INT TERM
    git clone --quiet --depth 1 --single-branch --branch "$branch" --sparse --filter=blob:none \
      https://github.com/EduardRe/DebianLikeBitrixVM.git "$work/repo" ||
      fail "Could not download $branch. The installed menu is still available."
    git -C "$work/repo" sparse-checkout set vm_menu || fail "Could not read the menu from $branch."
    candidate="$work/repo/vm_menu"
    for file in menu.sh bash_scripts/{config,functions,actions,updates,utils}.sh \
      helpers/perl/translate.pl helpers/php/get_database_data.php ansible/playbooks/create_site.yaml; do
      [[ -s "$candidate/$file" ]] || fail "Missing file in $branch: $file."
    done
    candidate_version=$(read_menu_version "$candidate/bash_scripts/config.sh")
    [[ "$candidate_version" =~ $version_pattern ]] || fail "Invalid menu version in $branch."
    if ! dpkg --compare-versions "$candidate_version" gt "$installed"; then
      printf 'Menu is up to date. Installed %s, available %s in %s.\n' "$installed" "$candidate_version" "$branch"
      exit 0
    fi
    while IFS= read -r -d '' file; do
      bash -n "$file" || fail "Invalid Bash script in $branch: ${file#"$candidate/"}."
    done < <(find "$candidate" -type f -name '*.sh' -print0)
    chmod a+x "$candidate/menu.sh" "$candidate/helpers/perl/translate.pl"
    [[ -L "$link" ]] || ln -s -- "$menu/menu.sh" "$link"

    install -d -m 0700 -- "$root/backup_vm_menu"
    backup=$(mktemp -d -- "$root/backup_vm_menu/$(date '+%d.%m.%Y %H:%M:%S').XXXXXXXX")
    mv -T -- "$menu" "$backup/vm_menu"
    mv -T -- "$candidate" "$menu"
    printf 'Menu updated from %s to %s (%s). Backup directory: %s\n' \
      "$installed" "$candidate_version" "$branch" "$backup"
  )
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  [[ $EUID -eq 0 ]] || fail "Run this script as root."
  [[ $# -le 1 ]] || fail "Expected at most one update branch."
  update_menu /root /etc/os-release "${1:-}"
fi
