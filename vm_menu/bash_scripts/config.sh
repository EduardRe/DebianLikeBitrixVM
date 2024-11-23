#!/bin/bash
# shellcheck disable=SC2034

# General configs
BS_VERSION_MENU="1.2.0"
BS_PATH_SITES="/var/www/html"
BS_DEFAULT_SITE_NAME="bx-site"
BS_PATH_DEFAULT_SITE="$BS_PATH_SITES/$BS_DEFAULT_SITE_NAME"
BS_USER_SERVER_SITES="www-data"
BS_GROUP_USER_SERVER_SITES="www-data"
BS_PERMISSIONS_SITES_DIRS="0755"
BS_PERMISSIONS_SITES_FILES="0644"
BS_EXCLUDED_DIRS_SITES=("temp" "tmp" "test" ".ssh")
BS_SITE_LINKS_RESOURCES=("local" "bitrix" "upload" "images")
BS_DOWNLOAD_BITRIX_INSTALL_FILES_NEW_SITE=(
  "https://www.1c-bitrix.ru/download/scripts/bitrixsetup.php"
  "https://www.1c-bitrix.ru/download/scripts/restore.php"
)
BS_TIMEOUT_DOWNLOAD_BITRIX_INSTALL_FILES_NEW_SITE=30
BS_SHOW_IP_CURRENT_SERVER_IN_MENU=true

# Bitrix agents configs
BS_BX_CRON_AGENTS_PATH_FILE_AFTER_DOCUMENT_ROOT="/bitrix/modules/main/tools/cron_events.php"
BS_BX_CRON_LOGS_PATH_DIR="/var/log/bitrix_cron_agents"
BS_BX_CRON_LOGS_PATH_FILE="agents_cron.log"

# PHP configs (VER#0.0 - it will be automatically replaced when the version is selected)
BS_PHP_INSTALL_TEMPLATE=(
  "phpVER#0.0"
  "phpVER#0.0-cli"
  "phpVER#0.0-common"
  "phpVER#0.0-gd"
  "phpVER#0.0-ldap"
  "phpVER#0.0-mbstring"
  "phpVER#0.0-mysql"
  "phpVER#0.0-opcache"
  "phpVER#0.0-curl"
  "php-pear"
  "phpVER#0.0-apcu"
  "php-geoip"
  "phpVER#0.0-mcrypt"
  "phpVER#0.0-memcache"
  "phpVER#0.0-zip"
  "phpVER#0.0-pspell"
  "phpVER#0.0-xml"
  "php-redis"
)

BS_DOWNLOAD_BITRIX_CONFIGS="https://dev.1c-bitrix.ru/docs/chm_files/debian.zip"

# Ansible configs
BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS="-i localhost, -c local"
BS_PATH_ANSIBLE_PLAYBOOKS="../ansible/playbooks"

# Ansible playbooks names
BS_ANSIBLE_PB_CREATE_SITE="create_site.yaml"
BS_ANSIBLE_PB_GET_LETS_ENCRYPT_CERTIFICATE="get_lets_encrypt_certificate.yaml"
BS_ANSIBLE_PB_ENABLE_OR_DISABLE_REDIRECT_HTTP_TO_HTTPS="enable_or_disable_redirect_http_to_https.yaml"
BS_ANSIBLE_PB_INSTALL_NEW_FULL_ENVIRONMENT="install_new_full_environment.yaml"
BS_ANSIBLE_PB_SETTINGS_SMTP_SITES="settings_smtp_sites.yaml"
BS_ANSIBLE_PB_INSTALL_OR_DELETE_NETDATA="install_or_delete_netdata.yaml"
BS_ANSIBLE_PB_INSTALL_OR_DELETE_SPHINX="install_or_delete_sphinx.yaml"
BS_ANSIBLE_PB_INSTALL_OR_DELETE_FILE_CONVERSION_SERVER="install_or_delete_file_conversion_server.yaml"
BS_ANSIBLE_PB_DELETE_SITE="delete_site.yaml"

# Data Base
BS_MAX_CHAR_DB_NAME=20
BS_MAX_CHAR_DB_USER=20
BS_CHAR_DB_PASSWORD=24
BS_DB_CHARACTER_SET_SERVER="utf8mb4"
BS_DB_COLLATION="utf8mb4_general_ci"

# NGINX configs
BS_SERVICE_NGINX_NAME="nginx"
BS_PATH_NGINX="/etc/${BS_SERVICE_NGINX_NAME}"
BS_PATH_NGINX_SITES_CONF="$BS_PATH_NGINX/sites-available"
BS_PATH_NGINX_SITES_ENABLED="$BS_PATH_NGINX/sites-enabled"

# Apache configs
BS_SERVICE_APACHE_NAME="apache2"
BS_PATH_APACHE="/etc/${BS_SERVICE_APACHE_NAME}"
BS_PATH_APACHE_SITES_CONF="$BS_PATH_APACHE/sites-available"
BS_PATH_APACHE_SITES_ENABLED="$BS_PATH_APACHE/sites-enabled"

# Emulation Bitrix VM configs
BS_VAR_NAME_BVM="BITRIX_VA_VER"
BS_VAR_VALUE_BVM="99.99.99"
BS_VAR_PATH_FILE_BVM="/etc/apache2/envvars"

# SMTP configs
BS_SMTP_FILE_SITES_CONFIG="${BS_PATH_SITES}/.msmtprc"
BS_SMTP_FILE_USER_CONFIG="${BS_USER_SERVER_SITES}"
BS_SMTP_FILE_GROUP_USER_CONFIG="${BS_GROUP_USER_SERVER_SITES}"
BS_SMTP_FILE_PERMISSIONS_CONFIG="0600"
BS_SMTP_FILE_USER_LOG="${BS_USER_SERVER_SITES}"
BS_SMTP_FILE_GROUP_USER_LOG="${BS_GROUP_USER_SERVER_SITES}"
BS_SMTP_PATH_WRAPP_SCRIPT_SH="/usr/local/bin/msmtp_wrapper.sh"

# Check new version menu
BS_BRANCH_UPDATE_MENU="master"
BS_REPOSITORY_URL_FILE_VERSION="https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/${BS_BRANCH_UPDATE_MENU}/vm_menu/bash_scripts/config.sh"
BS_URL_SCRIPT_UPDATE_MENU="https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/${BS_BRANCH_UPDATE_MENU}/update_menu.sh"
BS_REPOSITORY_URL="https://github.com/EduardRe/DebianLikeBitrixVM/"
BS_CHECK_UPDATE_MENU_MINUTES=10

# Mysql binary name
BS_MYSQL_CMD="mysql"

# Push-server configs
BS_PUSH_SERVER_CONFIG=/etc/sysconfig/push-server-multi
