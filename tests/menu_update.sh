#!/usr/bin/env bash
set -euo pipefail

project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
source "$project/vm_menu/bash_scripts/updates.sh"

fail_test() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

printf 'ID=debian\nVERSION_ID=12\n' > "$fixture/debian12"
printf 'ID=debian\nVERSION_ID=13\n' > "$fixture/debian13"
printf 'ID=ubuntu\nVERSION_ID=12\n' > "$fixture/ubuntu"
[[ $(menu_update_branch 1.2.0 "$fixture/debian12") == 12.x ]]
[[ $(menu_update_branch 13.0.0 "$fixture/debian13") == 13.x ]]
if menu_update_branch 12.0.0 "$fixture/debian13" || menu_update_branch 12.0.0 "$fixture/ubuntu"; then
  fail_test 'an incompatible system has an update branch'
fi
printf 'PASS update branches\n'

(
  BS_BRANCH_UPDATE_MENU=12.x
  BS_VERSION_MENU=12.0.9
  BS_CHECK_UPDATE_MENU_MINUTES=10
  BS_REPOSITORY_URL_FILE_VERSION=https://example.invalid/12.x/config.sh
  curl() {
    [[ "${!#}" == "$BS_REPOSITORY_URL_FILE_VERSION" ]] || return 1
    printf '%s\n' "$reply"
    return "$curl_status"
  }
  notification() {
    BS_MENU_UPDATE_CACHE="$fixture/cache/$1"
    local reply=$2 curl_status=${3:-0}
    action_check_new_version_menu
    available_menu_update
  }
  [[ $(notification newer 'BS_VERSION_MENU="12.0.10"') == 12.0.10 ]]
  if notification older 'BS_VERSION_MENU="12.0.8"' ||
    notification same 'BS_VERSION_MENU="12.0.9"' ||
    notification wrong_branch 'BS_VERSION_MENU="13.0.1"' ||
    notification invalid '<html>Not Found</html>' ||
    notification network_failure 'BS_VERSION_MENU="12.0.10"' 22; then
    fail_test 'unexpected update notification'
  fi
)
printf 'PASS update notifications\n'

# Temporary release repository with a default branch independent of the two channels.
origin="$fixture/origin"
git init --quiet --initial-branch=master "$origin"
git -C "$origin" config user.name 'DLBV test'
git -C "$origin" config user.email 'test@example.invalid'
git -C "$origin" config uploadpack.allowFilter true
cp -a "$project/vm_menu" "$origin/vm_menu"
chmod a-x "$origin/vm_menu/menu.sh" "$origin/vm_menu/helpers/perl/translate.pl"
git -C "$origin" add vm_menu
git -C "$origin" commit --quiet -m 'Transition fixture'
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.file://$origin.insteadOf"
export GIT_CONFIG_VALUE_0='https://github.com/EduardRe/DebianLikeBitrixVM.git'

prepare_installation() {
  local dest=$1 version=$2
  mkdir -p "$dest/vm_menu/bash_scripts"
  printf 'BS_VERSION_MENU="%s"\n' "$version" > "$dest/vm_menu/bash_scripts/config.sh"
  printf '#!/bin/bash\nexit 0\n' > "$dest/vm_menu/menu.sh"
  chmod +x "$dest/vm_menu/menu.sh"
  ln -s "$dest/vm_menu/menu.sh" "$dest/menu.sh"
}

run_update() {
  bash -c 'source "$1"; update_menu "${@:2}"' bash "$project/update_menu.sh" "$@"
}

publish_fixture() {
  local branch=$1 version=$2
  git -C "$origin" switch --quiet -c "$branch" master
  sed -i "s/^BS_VERSION_MENU=.*/BS_VERSION_MENU=\"$version\"/" "$origin/vm_menu/bash_scripts/config.sh"
  git -C "$origin" add vm_menu/bash_scripts/config.sh
  git -C "$origin" commit --quiet -m "Release $version fixture"
}

root12="$fixture/root12"
prepare_installation "$root12" 1.2.0
if run_update "$root12" "$fixture/debian12" > "$fixture/missing-branch.log" 2>&1; then
  fail_test 'the updater succeeded with a missing branch'
fi
grep -Fx 'BS_VERSION_MENU="1.2.0"' "$root12/vm_menu/bash_scripts/config.sh" > /dev/null
[[ -x "$root12/menu.sh" && ! -e "$root12/backup_vm_menu" ]]
grep -F 'Could not download 12.x' "$fixture/missing-branch.log" > /dev/null
printf 'PASS missing branch preserves installed menu\n'

publish_fixture 12.x 12.0.10
publish_fixture 13.x 13.0.1
run_update "$root12" "$fixture/debian12"
grep -Fx 'BS_VERSION_MENU="12.0.10"' "$root12/vm_menu/bash_scripts/config.sh" > /dev/null
shopt -s nullglob
backup_configs=("$root12"/backup_vm_menu/*/vm_menu/bash_scripts/config.sh)
[[ ${#backup_configs[@]} -eq 1 && -x "$root12/menu.sh" && -x "$root12/vm_menu/helpers/perl/translate.pl" ]]
grep -Fx 'BS_VERSION_MENU="1.2.0"' "${backup_configs[0]}" > /dev/null
run_update "$root12" "$fixture/debian12" 12.x
backup_configs=("$root12"/backup_vm_menu/*/vm_menu/bash_scripts/config.sh)
[[ ${#backup_configs[@]} -eq 1 ]]
if run_update "$root12" "$fixture/debian12" 13.x > "$fixture/wrong-branch.log" 2>&1; then
  fail_test 'an explicit branch overrode the Debian version'
fi
printf 'PASS legacy upgrade, backup and repeated update\n'

root_rollback="$fixture/root-rollback"
prepare_installation "$root_rollback" 1.2.0
mkdir "$fixture/fail-replacement"
cat > "$fixture/fail-replacement/mv" <<'SH'
#!/usr/bin/env bash
if [[ $3 == */repo/vm_menu ]]; then
  exit 1
fi
exec /usr/bin/mv "$@"
SH
chmod +x "$fixture/fail-replacement/mv"
if PATH="$fixture/fail-replacement:$PATH" \
  run_update "$root_rollback" "$fixture/debian12" > "$fixture/replacement.log" 2>&1; then
  fail_test 'the updater succeeded when replacement failed'
fi
grep -Fx 'BS_VERSION_MENU="1.2.0"' "$root_rollback/vm_menu/bash_scripts/config.sh" > /dev/null
[[ -x "$root_rollback/menu.sh" ]]
printf 'PASS replacement failure restores the previous menu\n'

root13="$fixture/root13"
prepare_installation "$root13" 13.0.0
run_update "$root13" "$fixture/debian13" 13.x
grep -Fx 'BS_VERSION_MENU="13.0.1"' "$root13/vm_menu/bash_scripts/config.sh" > /dev/null
printf 'PASS Debian 13 selects its release branch\n'
