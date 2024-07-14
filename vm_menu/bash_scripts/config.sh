#!/bin/bash
# shellcheck disable=SC2034

# General configs
BS_VERSION_MENU="1.0.1"
BS_PATH_SITES="/var/www/html"
BS_DEFAULT_SITE_NAME="bx-site"
BS_PATH_DEFAULT_SITE="$BS_PATH_SITES/$BS_DEFAULT_SITE_NAME"
BS_USER_SERVER_SITES="www-data"
BS_GROUP_USER_SERVER_SITES="www-data"
BS_PERMISSIONS_SITES_DIRS="0755"
BS_PERMISSIONS_SITES_FILES="0644"
BS_SITE_LINKS_RESOURCES=("local" "bitrix" "upload" "images")
BS_DOWNLOAD_BITRIX_INSTALL_FILES_NEW_SITE=(
  "https://www.1c-bitrix.ru/download/scripts/bitrixsetup.php"
  "https://www.1c-bitrix.ru/download/scripts/restore.php"
)
BS_TIMEOUT_DOWNLOAD_BITRIX_INSTALL_FILES_NEW_SITE=30
BS_SHOW_IP_CURRENT_SERVER_IN_MENU=true

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
)

# Ansible configs
BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS="-i localhost, -c local"
BS_PATH_ANSIBLE_PLAYBOOKS="../ansible/playbooks"

# Ansible playbooks names
BS_ANSIBLE_PB_CREATE_SITE="create_site.yaml"
BS_ANSIBLE_PB_GET_LETS_ENCRYPT_CERTIFICATE="get_lets_encrypt_certificate.yaml"
BS_ANSIBLE_PB_ENABLE_OR_DISABLE_REDIRECT_HTTP_TO_HTTPS="enable_or_disable_redirect_http_to_https.yaml"

# Data Base
BS_MAX_CHAR_DB_NAME=10
BS_MAX_CHAR_DB_USER=10
BS_CHAR_DB_PASSWORD=24

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

# Check new version menu
BS_BRANCH_UPDATE_MENU="master"
BS_REPOSITORY_URL_FILE_VERSION="https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/${BS_BRANCH_UPDATE_MENU}/vm_menu/bash_scripts/config.sh"
BS_URL_SCRIPT_UPDATE_MENU="https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/${BS_BRANCH_UPDATE_MENU}/update_menu.sh"
BS_REPOSITORY_URL="https://github.com/EduardRe/DebianLikeBitrixVM/"
BS_CHECK_UPDATE_MENU_MINUTES=10

