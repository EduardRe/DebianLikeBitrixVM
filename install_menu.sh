#!/bin/bash
set +x

# Install menu
# MASTER branch

# use curl
# bash <(curl -sL https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/master/install_menu.sh)

# use wget
# bash <(wget -qO- https://raw.githubusercontent.com/EduardRe/DebianLikeBitrixVM/master/install_menu.sh)

cat > /root/temp_install_menu.sh <<\END
#!/bin/bash

REPO_URL="https://github.com/EduardRe/DebianLikeBitrixVM.git"

DIR_NAME_MENU="vm_menu"
DEST_DIR_MENU="/root"

FULL_PATH_MENU_FILE="$DEST_DIR_MENU/$DIR_NAME_MENU/menu.sh"

apt update -y
apt upgrade -y
apt install -y wget curl ansible git

# set mysql root password
root_pass=$(pwgen 24 1)

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

chmod -R +x $DEST_DIR_MENU/$DIR_NAME_MENU

# Check script in .profile and add to .profile if not exist
if ! grep -qF "$FULL_PATH_MENU_FILE" /root/.profile; then
  cat << INSTALL_MENU >> /root/.profile

if [ -n "\$SSH_CONNECTION" ]; then
  $FULL_PATH_MENU_FILE
fi

INSTALL_MENU
fi

ln -s $FULL_PATH_MENU_FILE "$DEST_DIR_MENU/menu.sh"

echo -e "\n\n";
echo "Menu installed";
echo -e "\n";

END

bash /root/temp_install_menu.sh

rm /root/temp_install_menu.sh

