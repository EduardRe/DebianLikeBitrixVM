#!/bin/bash
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$dir/config.sh"
source "$dir/utils.sh"

REQUIRED_PARAMS=('domain' 'mode')
REQUIRED_PARAMS_FULL_MODE=('db_name' 'db_user' 'db_password')
REQUIRED_PARAMS_LINK_MODE=('path_site_from_links')

parse_params "$@"

for param in "${REQUIRED_PARAMS[@]}"; do
    if [[ ! ${ARR_PARAMS[$param]} ]]; then
      echo "Parameter $param is required";
      exit 1
    fi
done

case "${ARR_PARAMS[mode]}" in
    'full')
      for param in "${REQUIRED_PARAMS_FULL_MODE[@]}"; do
          if [[ ! ${ARR_PARAMS[$param]} ]]; then
            echo "Parameter $param is required";
            exit 1
          fi
      done
      ;;
    'link')
      for param in "${REQUIRED_PARAMS_LINK_MODE[@]}"; do
          if [[ ! ${ARR_PARAMS[$param]} ]]; then
            echo "Parameter $param is required";
            exit 1
          fi
      done
      ;;
    *)
      echo "Incorrect mode"
      exit 1
      ;;
esac

email="${ARR_PARAMS[ssl_email]}"
if [ -z "$email" ]; then
    email="admin@${ARR_PARAMS[domain]}";
fi

pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_CREATE_SITE}")

pb_redirect_http_to_https=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_ENABLE_OR_DISABLE_REDIRECT_HTTP_TO_HTTPS}")

ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
  -e "domain=${ARR_PARAMS[domain]} \

  mode=${ARR_PARAMS[mode]} \

  db_name=${ARR_PARAMS[db_name]} \
  db_user=${ARR_PARAMS[db_user]} \
  db_password=${ARR_PARAMS[db_password]} \

  path_site_from_links=${ARR_PARAMS[path_site_from_links]} \
  ssl_lets_encrypt=${ARR_PARAMS[is_ssl]} \
  ssl_lets_encrypt_www=${ARR_PARAMS[is_ssl_www]} \
  ssl_lets_encrypt_email=${email} \
  redirect_to_https=${ARR_PARAMS[is_redirect_to_https]} \

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
