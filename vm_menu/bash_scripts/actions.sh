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
  ssl_lets_encrypt_www=${ssl_lets_encrypt_www} \
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

  smtp_path_wrapp_script_sh=${BS_SMTP_PATH_WRAPP_SCRIPT_SH} \

  bx_cron_agents_path_file_after_document_root=${BS_BX_CRON_AGENTS_PATH_FILE_AFTER_DOCUMENT_ROOT} \
  bx_cron_logs_path_dir=${BS_BX_CRON_LOGS_PATH_DIR} \
  bx_cron_logs_path_file=${BS_BX_CRON_LOGS_PATH_FILE} \

  push_server_config=${BS_PUSH_SERVER_CONFIG} \

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
  is_www=${is_www} \

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

    wget -q "${BS_DOWNLOAD_BITRIX_CONFIGS}"
    unzip -o debian.zip && rm debian.zip
    rsync -a --force ./debian/php.d/ "/etc/php/${new_version_php}/mods-available/"
    rm -rf ./debian

    ln -sf "/etc/php/${new_version_php}/mods-available/zbx-bitrix.ini"  "/etc/php/${new_version_php}/apache2/conf.d/99-bitrix.ini"
    ln -sf "/etc/php/${new_version_php}/mods-available/zbx-bitrix.ini"  "/etc/php/${new_version_php}/cli/conf.d/99-bitrix.ini"

    # disable all php_modules
    for module in $(ls "${BS_PATH_APACHE}/mods-enabled" | grep php | sed 's/_module\.load//'); do
      a2dismod $module
    done

    a2enmod "php${new_version_php}"

    update-alternatives --set php "/usr/bin/php${new_version_php}"
    update-alternatives --set phar "/usr/bin/phar${new_version_php}"
    update-alternatives --set phar.phar "/usr/bin/phar.phar${new_version_php}"

    systemctl restart "${BS_SERVICE_APACHE_NAME}"
    systemctl restart "${BS_SERVICE_NGINX_NAME}"

    press_any_key_to_return_menu;
}

function action_settings_smtp_sites() {

    pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_SETTINGS_SMTP_SITES}")
    ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
      -e "is_actions_account=Y \
      account_name=${site} \
      email_from=${email_from} \
      smtp_host=${host} \
      smtp_port=${port} \
      is_auth=${is_auth} \
      login=${login} \
      password=${password} \
      authentication_method=${authentication_method} \
      enable_TLS=${enable_TLS} \

      smtp_file_sites_config=${BS_SMTP_FILE_SITES_CONFIG} \
      smtp_file_user_config=${BS_SMTP_FILE_USER_CONFIG} \
      smtp_file_group_user_config=${BS_SMTP_FILE_GROUP_USER_CONFIG} \
      smtp_file_permissions_config=${BS_SMTP_FILE_PERMISSIONS_CONFIG} \
      smtp_file_user_log=${BS_SMTP_FILE_USER_LOG} \
      smtp_file_group_user_log=${BS_SMTP_FILE_GROUP_USER_LOG} \
      smtp_path_wrapp_script_sh=${BS_SMTP_PATH_WRAPP_SCRIPT_SH}"

    press_any_key_to_return_menu;
}

function action_install_or_delete_netdata() {

    if [ $action = "INSTALL" ]; then
      login=$(pwgen 20 1)
      password=$(generate_password 30)
      hash_pass=$(htpasswd -nb $login $password)
      echo "$hash_pass" > "/etc/${BS_SERVICE_NGINX_NAME}/netdata_passwds"
    fi

    pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_INSTALL_OR_DELETE_NETDATA}")
    ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
      -e "netdata_action=${action} \
      service_nginx_name=${BS_SERVICE_NGINX_NAME}"

    if [ $action = "INSTALL" ]; then
      echo -e "
      Netdata is installed and configured.
      please follow the link \e[33mhttp://IP or domain/netdata/\e[0m or \e[33mhttps://IP or domain/netdata/\e[0m
      \e[33mLogin: ${login}\e[0m
      \e[33mPassword: ${password}\e[0m"
    fi

    press_any_key_to_return_menu;
}

function action_install_or_delete_sphinx() {
    pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_INSTALL_OR_DELETE_SPHINX}")
    ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
      -e "sphinx_action=${action}"

    press_any_key_to_return_menu;
}

function action_install_or_delete_file_conversion_server() {

    if [ $action = "INSTALL" ]; then
      echo "Install community.rabbitmq collection";
      ansible-galaxy collection install community.rabbitmq;
    fi

    pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_INSTALL_OR_DELETE_FILE_CONVERSION_SERVER}")
    ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
      -e "file_conversion_server_action=${action} \
      domain=${domain} \
      full_path_site=${full_path_site} \
      user_server_sites=${BS_USER_SERVER_SITES} \
      group_user_server_sites=${BS_GROUP_USER_SERVER_SITES} \
      service_apache_name=${BS_SERVICE_APACHE_NAME}"
    press_any_key_to_return_menu;
}

function action_delete_site() {
    pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_DELETE_SITE}")
    ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
      -e "site=${site} \
      full_path_site=${full_path_site} \
      db_name=${db_name} \
      db_user=${db_user} \
      type=${type} \

      user_server_sites=${BS_USER_SERVER_SITES} \

      service_nginx_name=${BS_SERVICE_NGINX_NAME} \
      path_nginx_sites_conf=${BS_PATH_NGINX_SITES_CONF} \

      service_apache_name=${BS_SERVICE_APACHE_NAME} \
      path_apache_sites_conf=${BS_PATH_APACHE_SITES_CONF}"

    press_any_key_to_return_menu
}
