#!/usr/bin/env bash
set +x
set -euo pipefail
# Install full environment
# MASTER branch

# use curl
# bash <(curl -sL https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/master/install_full_environment.sh)

# use wget
# bash <(wget -qO- https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/master/install_full_environment.sh)

cat > /root/temp_install_full_environment.sh <<\END
#!/usr/bin/env bash
set +x
set -euo pipefail

generate_password() {
    local length=$1
    local specials='!@#$%^&*()-_=+[]|;:,.<>?/~'
    local all_chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789${specials}"

    local password=""
    for i in $(seq 1 $length); do
        local char=${all_chars:RANDOM % ${#all_chars}:1}
        password+=$char
    done

    echo $password
}

BRANCH="master"
SETUP_BITRIX_DEBIAN_URL="https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/$BRANCH/repositories/bitrix-gt/custom_from_install_full_environment_bitrix_setup_vanilla.sh"
REPO_URL="https://github.com/EduardRe/DebianLikeBitrixVM.git"

DB_NAME="bitrix"
DB_USER="bitrix"

DIR_NAME_MENU="vm_menu"
DEST_DIR_MENU="/root"

FULL_PATH_MENU_FILE="$DEST_DIR_MENU/$DIR_NAME_MENU/menu.sh"

apt update -y
apt upgrade -y
apt install -y perl wget curl ansible git ssl-cert cron locales poppler-utils catdoc libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static

# Set locales
locale-gen en_US.UTF-8

bash -c 'echo "LANG=en_US.UTF-8" > /etc/default/locale'
bash -c 'echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale'

bash -c 'echo "LC_ALL=\"en_US.UTF-8\"" >> /etc/environment'

source /etc/default/locale
export LC_ALL="en_US.UTF-8"

bash -c "$(curl -sL $SETUP_BITRIX_DEBIAN_URL)"

source /root/run.sh

set +x
set -euo pipefail

# set mysql root password
root_pass=$(generate_password 24)
site_user_password=$(generate_password 24)

mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${root_pass}');FLUSH PRIVILEGES;"

cat > /root/.my.cnf <<CONFIG_MYSQL_ROOT_MY_CNF
[client]
user=root
password="${root_pass}"
# socket=/var/lib/mysqld/mysqld.sock

CONFIG_MYSQL_ROOT_MY_CNF

# Clone directory vm_menu with repositories
git clone --depth 1 --filter=blob:none --sparse $REPO_URL "$DEST_DIR_MENU/DebianLikeBitrixVM"
cd "$DEST_DIR_MENU/DebianLikeBitrixVM"
git sparse-checkout set $DIR_NAME_MENU

# Move vm_menu in /root and clean
rm -rf $DEST_DIR_MENU/$DIR_NAME_MENU
mv -f $DIR_NAME_MENU $DEST_DIR_MENU
rm -rf "$DEST_DIR_MENU/DebianLikeBitrixVM"

cd $DEST_DIR_MENU

chmod -R +x $DEST_DIR_MENU/$DIR_NAME_MENU

# Check script in .profile and add to .profile if not exist
if ! grep -qF "$FULL_PATH_MENU_FILE" /root/.profile; then
  cat << INSTALL_MENU >> /root/.profile

if [ -n "\$SSH_CONNECTION" ]; then
  $FULL_PATH_MENU_FILE
fi

INSTALL_MENU
fi

# Enable mod_remoteip
a2enmod remoteip

cat > /etc/apache2/mods-enabled/remoteip.conf <<CONFIG_APACHE2_REMOTEIP
<IfModule remoteip_module>
 RemoteIPHeader X-Forwarded-For
 RemoteIPInternalProxy 127.0.0.1
</IfModule>
CONFIG_APACHE2_REMOTEIP

# set PHP 8.2
update-alternatives --set php /usr/bin/php8.2
update-alternatives --set phar /usr/bin/phar8.2
update-alternatives --set phar.phar /usr/bin/phar.phar8.2


ln -s $FULL_PATH_MENU_FILE "$DEST_DIR_MENU/menu.sh"

# Final actions

source $DEST_DIR_MENU/$DIR_NAME_MENU/bash_scripts/config.sh

DOCUMENT_ROOT="${BS_PATH_SITES}/bx-site"

DELETE_FILES=(
  "$BS_PATH_APACHE_SITES_CONF/000-default.conf"
  "$BS_PATH_APACHE_SITES_ENABLED/000-default.conf"
)

ansible-playbook "$DEST_DIR_MENU/$DIR_NAME_MENU/ansible/playbooks/${BS_ANSIBLE_PB_SETTINGS_SMTP_SITES}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
  -e "is_new_install_env=Y \
  account_name='' \
  smtp_file_sites_config=${BS_SMTP_FILE_SITES_CONFIG} \
  smtp_file_user_config=${BS_SMTP_FILE_USER_CONFIG} \
  smtp_file_group_user_config=${BS_SMTP_FILE_GROUP_USER_CONFIG} \
  smtp_file_permissions_config=${BS_SMTP_FILE_PERMISSIONS_CONFIG} \
  smtp_file_user_log=${BS_SMTP_FILE_USER_LOG} \
  smtp_file_group_user_log=${BS_SMTP_FILE_GROUP_USER_LOG} \
  smtp_path_wrapp_script_sh=${BS_SMTP_PATH_WRAPP_SCRIPT_SH}"

ansible-playbook "$DEST_DIR_MENU/$DIR_NAME_MENU/ansible/playbooks/${BS_ANSIBLE_PB_INSTALL_NEW_FULL_ENVIRONMENT}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
  -e "domain=default \

  db_name=${DB_NAME} \
  db_user=${DB_USER} \
  db_password=${DBPASS} \

  site_user_password=${site_user_password} \

  path_sites=${BS_PATH_SITES} \
  document_root=${DOCUMENT_ROOT} \

  delete_files=$(IFS=,; echo "${DELETE_FILES[*]}") \

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

  push_key=${PUSH_KEY}"

echo -e "\n\n";
echo "Full environment installed";
echo -e "\n";
echo "Password for the user ${BS_USER_SERVER_SITES}:";
echo "${site_user_password}";
echo -e "\n";

END

bash /root/temp_install_full_environment.sh

rm /root/temp_install_full_environment.sh
rm /root/run.sh
