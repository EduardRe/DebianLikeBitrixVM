#!/bin/bash
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


action_create_site(){
  pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_CREATE_SITE}")

  pb_redirect_http_to_https=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_ENABLE_OR_DISABLE_REDIRECT_HTTP_TO_HTTPS}")

  ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
  -e "domain=${domain} \

  mode=${mode} \

  db_name=${db_name} \
  db_user=${db_user} \
  db_password=${db_password} \

  path_site_from_links=${path_site_from_links} \
  ssl_lets_encrypt=${ssl_lets_encrypt} \
  ssl_lets_encrypt_email=${ssl_lets_encrypt_email} \
  redirect_to_https=${redirect_to_https} \

  path_sites=${BS_PATH_SITES} \

  default_full_path_site=${BS_PATH_SITES}/${BS_DEFAULT_SITE_NAME} \

  site_links_resources=$(IFS=,; echo "${BS_SITE_LINKS_RESOURCES[*]}") \
  download_bitrix_install_files_new_site=$(IFS=,; echo "${BS_DOWNLOAD_BITRIX_INSTALL_FILES_NEW_SITE[*]}") \
  timeout_download_bitrix_install_files_new_site=${BS_TIMEOUT_DOWNLOAD_BITRIX_INSTALL_FILES_NEW_SITE} \

  user_server_sites=${BS_USER_SERVER_SITES} \
  group_user_server_sites=${BS_GROUP_USER_SERVER_SITES} \

  permissions_sites_dirs=${BS_PERMISSIONS_SITES_DIRS} \
  permissions_sites_files=${BS_PERMISSIONS_SITES_FILES} \

  service_nginx_name=${BS_SERVICE_NGINX_NAME} \
  path_nginx=${BS_PATH_NGINX} \
  path_nginx_sites_conf=${BS_PATH_NGINX_SITES_CONF} \
  path_nginx_sites_enabled=${BS_PATH_NGINX_SITES_ENABLED} \

  service_apache_name=${BS_SERVICE_APACHE_NAME} \
  path_apache=${BS_PATH_APACHE} \
  path_apache_sites_conf=${BS_PATH_APACHE_SITES_CONF} \
  path_apache_sites_enabled=${BS_PATH_APACHE_SITES_ENABLED} \

  push_key=\${PUSH_KEY} \

  pb_redirect_http_to_https=${pb_redirect_http_to_https} \
  ansible_run_playbooks_params=${BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS}"

  press_any_key_to_return_menu;
}

action_get_lets_encrypt_certificate(){
  pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_GET_LETS_ENCRYPT_CERTIFICATE}")

  ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
  -e "domain=${domain} \
  path_site=${path_site} \
  email=${email} \

  default_full_path_site=${BS_PATH_SITES}/${BS_DEFAULT_SITE_NAME} \
  path_nginx_sites_conf=${BS_PATH_NGINX_SITES_CONF} \
  service_nginx_name=${BS_SERVICE_NGINX_NAME} \

  user_server_sites=${BS_USER_SERVER_SITES} \
  group_user_server_sites=${BS_GROUP_USER_SERVER_SITES} \

  permissions_sites_files=${BS_PERMISSIONS_SITES_FILES} \

  redirect_to_https=${redirect_to_https}"

  press_any_key_to_return_menu;
}

action_enable_or_disable_redirect_http_to_https(){
  pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_ENABLE_OR_DISABLE_REDIRECT_HTTP_TO_HTTPS}")

  ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
  -e "path_site=${path_site} \

  user_server_sites=${BS_USER_SERVER_SITES} \
  group_user_server_sites=${BS_GROUP_USER_SERVER_SITES} \

  permissions_sites_files=${BS_PERMISSIONS_SITES_FILES} \

  domain=${site} \
  action=${action}"

  press_any_key_to_return_menu;
}

action_emulate_bitrix_vm(){
  clear;

  local action="enable"
  if [[ ! -z "${!BS_VAR_NAME_BVM}" ]]; then
      action="disable"
      echo "   Disabled emulate Bitrix VM";
      sed -i "/export ${BS_VAR_NAME_BVM}/d" $BS_VAR_PATH_FILE_BVM
  else
      echo "export ${BS_VAR_NAME_BVM}=\"${BS_VAR_VALUE_BVM}\"" | tee -a $BS_VAR_PATH_FILE_BVM > /dev/null
      echo "   Enabled emulate Bitrix VM";
  fi

  systemctl restart $BS_SERVICE_APACHE_NAME
  press_any_key_to_return_menu;
}

action_check_new_version_menu(){
  local file_temp_config="/tmp/configs.tmp"
  local file_new_version="/tmp/new_version_menu.tmp"

  if [[ -z ${BS_REPOSITORY_URL_FILE_VERSION} ]] || [[ -z ${BS_REPOSITORY_URL} ]] || [[ -z ${BS_CHECK_UPDATE_MENU_MINUTES} ]]; then
      rm -f "${file_new_version}"
      return;
  fi

  if [ -f "${file_temp_config}" ]; then
    current_time=$(date +%s)
    file_time=$(stat -c %Y "${file_temp_config}")
    diff=$((current_time - file_time))
    if [ ! $diff -lt $(($BS_CHECK_UPDATE_MENU_MINUTES * 60)) ]; then
      curl -m 5 -o "${file_temp_config}" -s ${BS_REPOSITORY_URL_FILE_VERSION} 2>/dev/null
    fi
    else
      curl -m 5 -o "${file_temp_config}" -s ${BS_REPOSITORY_URL_FILE_VERSION} 2>/dev/null
  fi

  if [ ! -f ${file_temp_config} ]; then
    rm -f "${file_new_version}"
    return;
  fi

  new_version=$(grep 'BS_VERSION_MENU' ${file_temp_config} | awk -F'=' '{ print $2 }' | tr -d '"')

  if [[ -z ${new_version} ]]; then
    rm -f "${file_new_version}"
    return;
  fi

  if [[ ${new_version} == ${BS_VERSION_MENU} ]]; then
    rm -f "${file_new_version}"
    return;
  fi

  echo "${new_version}" > $file_new_version
}

function action_update_menu() {
    bash <(curl -sL ${BS_URL_SCRIPT_UPDATE_MENU})
    rm -f "/tmp/new_version_menu.tmp"
    exit;
}

function action_update_server() {
    apt update -y
    apt upgrade -y

    press_any_key_to_return_menu;
}

function action_change_php_version() {
    install_php="${BS_PHP_INSTALL_TEMPLATE[@]}"
    install_php=$(echo "$install_php" | sed "s/VER#0.0/$new_version_php/g")
    apt install -y $install_php

    # disable all php_modules
    for module in $(ls "${BS_PATH_APACHE}/mods-enabled" | grep php | sed 's/_module\.load//'); do
      a2dismod $module
    done

    a2enmod "php${new_version_php}"

    systemctl restart "${BS_SERVICE_APACHE_NAME}"
    systemctl restart "${BS_SERVICE_NGINX_NAME}"

    press_any_key_to_return_menu;
}
