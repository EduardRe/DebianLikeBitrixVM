#!/bin/bash
dir="$(dirname "$(readlink -f "$0")")"
dir_helpers="$dir/helpers"

source "$dir/bash_scripts/config.sh"
source "$dir/bash_scripts/updates.sh"
BS_BRANCH_UPDATE_MENU=$(menu_update_branch "$BS_VERSION_MENU") || BS_BRANCH_UPDATE_MENU=
BS_REPOSITORY_URL_FILE_VERSION="https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/$BS_BRANCH_UPDATE_MENU/vm_menu/bash_scripts/config.sh"
BS_URL_SCRIPT_UPDATE_MENU="https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/$BS_BRANCH_UPDATE_MENU/update_menu.sh"
BS_MENU_UPDATE_CACHE="/root/.cache/debian-like-bitrixvm/$BS_BRANCH_UPDATE_MENU"
source "$dir/bash_scripts/functions.sh"

main_menu;














