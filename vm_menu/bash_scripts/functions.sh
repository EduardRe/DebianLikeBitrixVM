#!/bin/bash
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$dir/utils.sh"
source "$dir/actions.sh"

function do_load_menu() {
  action_check_new_version_menu &
  load_bitrix_vm_version
  if [ $BS_SHOW_IP_CURRENT_SERVER_IN_MENU = true ]; then
    get_ip_current_server
  fi
}

main_menu(){
    comand=;
    until [[ "$comand" == "0" ]]; do
    clear;

    do_load_menu;

    local mesg_menu_emulate_bitrix_vm="Enable Bitrix VM emulating"
    if [[ ! -z "${!BS_VAR_NAME_BVM}" ]]; then
      mesg_menu_emulate_bitrix_vm="Disable Bitrix VM emulating (version: ${!BS_VAR_NAME_BVM})"
    fi

    local msg_new_version_menu="";
    local update_menu_action="";
    if [ -f "/tmp/new_version_menu.tmp" ]; then
      local nv=$(cat /tmp/new_version_menu.tmp)
      msg_new_version_menu="\e[33m          New version of Debian Like BitrixVM
          (your version ${BS_VERSION_MENU} -> new version ${nv}) please follow the link
          \e]8;;${BS_REPOSITORY_URL}\a${BS_REPOSITORY_URL}\e]8;;\a or enter \"update_menu\" to update your menu\n\e[0m"
      update_menu_action="Enter \"update_menu\" to update your menu";
    fi

    echo -e "          Welcome to the menu \"Debian Like BitrixVM\" version ${BS_VERSION_MENU}         \n\n";
    if [ $BS_SHOW_IP_CURRENT_SERVER_IN_MENU = true ]; then
      echo -e "          ${CURRENT_SERVER_IP}\n";
    fi
    echo -e "${msg_new_version_menu}";
    echo "          1) List of sites dirs";
    echo "          2) Add site";
    echo "          3) Configure Let\`s Encrypt certificate";
    echo "          4) Enable or Disable redirect HTTP to HTTPS";
    echo "          5) ${mesg_menu_emulate_bitrix_vm}";
    echo "          6) Change PHP version";
    echo "          7) Settings SMTP sites";
    echo "          8) Installing Extensions";
    echo "          9) Update server";
    echo "          R) Restart the server";
    echo "          P) Turn off the server";
    echo "          DELETE_SITE) Delete a site";
    if [ -n "${update_menu_action}" ]; then
      echo -e "\e[33m             ${update_menu_action}\e[0m";
    fi
    echo "          0) Exit";
    echo -e "\n\n";
    echo -n "Enter command: "
    read comand

    case $comand in

     "1") show_sites_dirs ;;
     "2") add_site ;;
     "3") get_lets_encrypt_certificate ;;
     "4") enable_or_disable_redirect_http_to_https ;;
     "5") action_emulate_bitrix_vm ;;
     "6") change_php_version ;;
     "7") settings_smtp_sites ;;
     "8") menu_install_extensions ;;
     "9") update_server ;;
     "R") reboot_server ;;
     "P") power_off_server ;;
     "DELETE_SITE") delete_site ;;
     "update_menu") update_menu;;

    0|z)  exit
    ;;
     *)
     echo "Error unknown command"
     ;;

    esac
    done
}

menu_install_extensions(){
    comand=;
    until [[ "$comand" == "0" ]]; do
    clear;

    echo -e "\n          Menu -> Installing Extensions:\n";
    echo "          1) Install/Delete netdata";
    echo "          0) Return to main menu";
    echo -e "\n\n";
    echo -n "Enter command: "
    read comand

    case $comand in

     "1") install_netdata ;;

    0|z)  main_menu
    ;;
     *)
     echo "Error unknown command"
     ;;

    esac
    done
}

add_site(){
    clear;
    list_sites;

    domain=''
    mode=''
    db_name=''
    db_user=''
    db_password=$(generate_password $BS_CHAR_DB_PASSWORD)
    path_site_from_links=$BS_PATH_DEFAULT_SITE

    ssl_lets_encrypt="N";
    ssl_lets_encrypt_www="Y";
    ssl_lets_encrypt_email='';
    redirect_to_https="N";

    echo -e "\n   Menu -> Add a site:\n";
    while [[ -z "$domain" ]]; do
       read_by_def "   Enter site domain (example: example.com): " domain $domain;
       if [ -z "$domain" ]; then
        echo "   Incorrect site domain! Please enter site domain";
       elif [[ " ${ARR_ALL_DIR_SITES[*]} " =~ " $domain " ]]; then
        domain='';
        echo "   Domain already exists! Please enter another site domain";
       fi
    done

    db_name=$(cut -c-$BS_MAX_CHAR_DB_NAME <<< $(echo "db_$domain" | sed 's/-//g' | sed 's/\./_/g' | "${dir_helpers}/perl/translate.pl"))
    db_name=${db_name%_}

    db_user=$(cut -c-$BS_MAX_CHAR_DB_USER <<< $(echo "usr_$domain" | sed 's/-//g' | sed 's/\./_/g' | "${dir_helpers}/perl/translate.pl"))
    db_user=${db_user%_}

    ssl_lets_encrypt_email=$(echo "admin@$domain" | "${dir_helpers}/perl/translate.pl")

    while true; do
        read -r -p "   Enter site mode link or full: " mode
        case $mode in
            link ) break;;
            full ) break;;
            * ) echo "   Incorrect site mode";;
        esac
    done

    case $mode in
      link )
        read_by_def "   Enter path to links site (default: $path_site_from_links): " path_site_from_links $path_site_from_links;
      ;;
      full )
        read_by_def "   Enter database name: (default: $db_name): " db_name $db_name;
        read_by_def "   Enter database user: (default: $db_user): " db_user $db_user;
        read_by_def "   Enter database password: (default: $db_password): " db_password $db_password;
      ;;
    esac

    read_by_def "   Enter Y or N for setting SSL Let\`s Encrypt site (default: $ssl_lets_encrypt): " ssl_lets_encrypt $ssl_lets_encrypt;
    ssl_lets_encrypt="${ssl_lets_encrypt^^}"

    if [ $ssl_lets_encrypt == "Y" ]; then
        read_by_def "   Enter Y or N to get a certificate for WWW (default: $ssl_lets_encrypt_www): " ssl_lets_encrypt_www $ssl_lets_encrypt_www;
        read_by_def "   Enter email for SSL Let\`s Encrypt (default: $ssl_lets_encrypt_email): " ssl_lets_encrypt_email $ssl_lets_encrypt_email;
        read_by_def "   Enter Y or N for redirect HTTP to HTTPS (default: $redirect_to_https): " redirect_to_https $redirect_to_https;
        redirect_to_https="${redirect_to_https^^}"
        ssl_lets_encrypt_www="${ssl_lets_encrypt_www^^}"
    fi


    echo -e "\n   Entered data:\n"
    echo "   Domain: $domain";
    echo "   Mode: $mode";

    case $mode in
      link )
        echo "   Path to links site: $path_site_from_links";
      ;;
      full )
        echo "   Database name: $db_name";
        echo "   Database user: $db_user";
        echo "   Database password: $db_password";
      ;;
    esac

    echo "   SSL Let\`s Encrypt: $ssl_lets_encrypt";

    if [ $ssl_lets_encrypt == "Y" ]; then
        echo "   Get a certificate for WWW: $ssl_lets_encrypt_www"
        echo "   SSL Let\`s Encrypt email: $ssl_lets_encrypt_email"
        echo "   Redirect HTTP to HTTPS: $redirect_to_https"
    fi

    echo -e "\n\n"

    while true; do
        read -r -p "   Do you really want to create a website? (Y/N): " answer
        case $answer in
            [Yy]* ) action_create_site; break;;
            [Nn]* ) break;;
            * ) echo "   Please enter Y or N.";;
        esac
    done
}

show_sites_dirs(){
  clear;
  list_sites;

  press_any_key_to_return_menu;
}

get_lets_encrypt_certificate(){
  clear;
  list_sites;

    domain=''
    email='';

    path_site="${BS_PATH_SITES}/${BS_DEFAULT_SITE_NAME}"
    redirect_to_https="N";
    is_www="Y";

    echo -e "\n   Menu -> Configure Let\`s Encrypt certificate:\n";
    while [[ -z "$domain" ]]; do
       read_by_def "   Enter site domain (example: example.com): " domain $domain;
       if [ -z "$domain" ]; then
        echo "   Incorrect site domain! Please enter another site domain";
       fi
    done

    email=$(echo "admin@$domain" | "${dir_helpers}/perl/translate.pl")

    read_by_def "   Enter full path to site (default: $path_site): " path_site $path_site;
    read_by_def "   Enter Y or N to get a certificate for WWW (default: $is_www): " is_www $is_www;
    read_by_def "   Enter email (default: $email): " email $email;
    read_by_def "   Enter Y or N for redirecting HTTP to HTTPS (default: $redirect_to_https): " redirect_to_https $redirect_to_https;
    redirect_to_https="${redirect_to_https^^}"
    is_www="${is_www^^}"

    echo -e "\n   Entered data:\n"
    echo "   Domain: $domain";
    echo "   Full path to site: $path_site";
    echo "   Get a certificate for WWW: $is_www"
    echo "   Email: $email"
    echo "   Redirecting HTTP to HTTPS: $redirect_to_https"

    echo -e "\n\n"

    while true; do
        read -r -p "   Do you really want to create a SSL Let\`s Encrypt certificate? (Y/N): " answer
        case $answer in
            [Yy]* ) action_get_lets_encrypt_certificate; break;;
            [Nn]* ) break;;
            * ) echo "   Please enter Y or N.";;
        esac
    done
}

enable_or_disable_redirect_http_to_https(){
  clear;
  list_sites;

  site=$BS_DEFAULT_SITE_NAME;

  echo -e "\n   Enable or Disable redirecting HTTP to HTTPS:\n";

  read_by_def "   Enter site dir (default: $site): " site $site;

  while [[ -z "$site" ]] || ! [[ " ${ARR_ALL_DIR_SITES[*]} " =~ " $site " ]]; do

       if [ -z "$site" ]; then
        echo "   Incorrect site dir! Please enter site dir";
        read_by_def "   Enter site dir: " site $site;
       elif ! [[ " ${ARR_ALL_DIR_SITES[*]} " =~ " $site " ]]; then
        site='';
        echo "   Domain does not exist! You can use exists domain";
        read_by_def "   Enter site dir: " site $site;
       fi
  done

  current_state='disabled';
  action='enable';

  local index=0
  while [[ -n "${ARR_ALL_DIR_SITES_DATA["${index}_dir"]}" ]]; do
    if [[ "${ARR_ALL_DIR_SITES_DATA["${index}_dir"]}" == "$site" ]]; then
      if [[ "${ARR_ALL_DIR_SITES_DATA[$index,is_https]}" == "Y" ]]; then
        current_state='enabled';
        action='disable';
      fi
      break;
    fi
    ((index++))
  done

   echo "   Your site $site redirecting HTTP to HTTPS status: $current_state";

   path_site="$BS_PATH_SITES/$site"

  while true; do
    read -r -p "   Do you really want to $action redirect HTTP to HTTPS? (Y/N): " answer
    case $answer in
      [Yy]* ) action_enable_or_disable_redirect_http_to_https; break;;
      [Nn]* ) break;;
      * ) echo "   Please enter Y or N.";;
    esac
  done
}

function update_menu(){
    clear;

    if [ -z "${BS_URL_SCRIPT_UPDATE_MENU}" ]; then
      echo -e "Variable BS_URL_SCRIPT_UPDATE_MENU is not defined\n";
      press_any_key_to_return_menu;
      return 0;
    fi

    while true; do
    read -r -p "   Do you really want to update menu? (Y/N): " answer
    case $answer in
      [Yy]* ) action_update_menu; break;;
      [Nn]* ) break;;
      * ) echo "   Please enter Y or N.";;
    esac
  done
}

function update_server(){
    clear;

    while true; do
    read -r -p "   Do you really want to update server? (Y/N): " answer
    case $answer in
      [Yy]* ) action_update_server; break;;
      [Nn]* ) break;;
      * ) echo "   Please enter Y or N.";;
    esac
  done
}

function change_php_version() {
    clear;
    get_current_version_php
    get_available_version_php

    new_version_php=''
    while [[ -z "$new_version_php" ]]; do
       read_by_def "   Enter PHP version: (example: 8.2 or php8.2): " new_version_php $new_version_php;
       if [ -z "$new_version_php" ]; then
        echo "   Incorrect PHP version! Please enter PHP version";
       fi
    done

    new_version_php="${new_version_php^^}"
    new_version_php=$(echo "$new_version_php" | sed -e 's/PHP//')

    echo -e "\n   Selected PHP version: $new_version_php\n"

    while true; do
      read -r -p "   Do you really want to change PHP version? (Y/N): " answer
      case $answer in
        [Yy]* ) action_change_php_version; break;;
        [Nn]* ) break;;
        * ) echo "   Please enter Y or N.";;
      esac
    done
}

function settings_smtp_sites() {
    clear;
    list_sites;

    site=$BS_DEFAULT_SITE_NAME;
    email_from="";
    host="";
    port="465";
    is_auth="Y";
    login="";
    password="";
    authentication_method="auto";
    enable_TLS="Y";

    echo -e "\n   Menu -> Settings SMTP sites:\n";

    read_by_def "   Enter site dir (default: $site): " site $site;

    while [[ -z "$site" ]] || ! [[ " ${ARR_ALL_DIR_SITES[*]} " =~ " $site " ]]; do
       if [ -z "$site" ]; then
        echo "   Incorrect site dir! Please enter site dir";
        read_by_def "   Enter site dir: " site $site;
       elif ! [[ " ${ARR_ALL_DIR_SITES[*]} " =~ " $site " ]]; then
        site='';
        echo "   Site dir does not exist! You can use exists site dir";
        read_by_def "   Enter site dir: " site $site;
       fi
    done

    if [[ $site == "$BS_DEFAULT_SITE_NAME" ]]; then
      site="default"
    fi

    pb=$(realpath "$dir/${BS_PATH_ANSIBLE_PLAYBOOKS}/${BS_ANSIBLE_PB_SETTINGS_SMTP_SITES}")
    res=$(ansible-playbook "${pb}" $BS_ANSIBLE_RUN_PLAYBOOKS_PARAMS \
      -e "print_account=Y \
      account_name=${site} \
      smtp_file_sites_config=${BS_SMTP_FILE_SITES_CONFIG} \
      smtp_file_user_config=${BS_SMTP_FILE_USER_CONFIG} \
      smtp_file_group_user_config=${BS_SMTP_FILE_GROUP_USER_CONFIG} \
      smtp_file_permissions_config=${BS_SMTP_FILE_PERMISSIONS_CONFIG} \
      smtp_file_user_log=${BS_SMTP_FILE_USER_LOG} \
      smtp_file_group_user_log=${BS_SMTP_FILE_GROUP_USER_LOG} \
      smtp_path_wrapp_script_sh=${BS_SMTP_PATH_WRAPP_SCRIPT_SH}")

    res=$(echo "$res" | grep -oP '(?<=start_parse).*?(?=end_parse)' | sed 's/\\n/\n/g')

    trim_for_test="${res//[[:space:]]}"

    action="create"
    if [ -z "$trim_for_test" ]; then
      echo -e "\e[1;34m\n   The ${site} account was not found. Creating a new account:\n\e[0m"
      else
      action="update"
      echo -e "\e[33m\n   The ${site} account has been found. Here are his settings:\n\e[0m"
      echo -e "     $res\n"
    fi

    read_by_def "   Enter From email address (example: test@example.com): " email_from $email_from;
    read_by_def "   Enter server address or DNS (127.0.0.1): " host $host;
    read_by_def "   Enter server port (default: ${port}): " port $port;

    read_by_def "   Enter Y or N for to use SMTP authentication on ${host}:${port} (default: $is_auth): " is_auth $is_auth;
    is_auth="${is_auth^^}"

    if [[ $is_auth == "Y" ]]; then
      login="${email_from}"
      read_by_def "   Enter login (default: $login): " login $login;
      read_by_def "   Enter password: " password $password;
      echo -e "\e[1;34m\n   Available methods are plain,scram-sha-1,cram-md5,gssapi,external,digest-md5,login,ntlm\n\e[0m"
      read_by_def "   Enter SMTP authentication method (default: $authentication_method): " authentication_method $authentication_method;
    fi

    read_by_def "   Enter Y or N to enable TLS for ${host}:${port} (default: $enable_TLS): " enable_TLS $enable_TLS;
    enable_TLS="${enable_TLS^^}"

    echo -e "\n   Entered data:\n"
    echo "   Site dir (account): $site";
    echo "   From email address: $email_from";
    echo "   Server address or DNS: $host"
    echo "   Server port: $port"
    echo "   Use SMTP authentication: $is_auth"

    if [[ $is_auth == "Y" ]]; then
      echo "   Login: $login"
      echo "   Password: $password"
      echo "   SMTP authentication method: $authentication_method"
    fi

    echo "   Enable TLS: $enable_TLS"

    echo -e "\n\n"

    while true; do
        read -r -p "   Do you really want to ${action} a SMTP account? (Y/N): " answer
        case $answer in
            [Yy]* ) action_settings_smtp_sites; break;;
            [Nn]* ) break;;
            * ) echo "   Please enter Y or N.";;
        esac
    done
}

function reboot_server() {
  clear
  while true; do
    read -r -p $'   Do you really want to\e[33m RESTART \e[0mserver? (Y/N): ' answer
    case $answer in
        [Yy]* ) reboot; break;;
        [Nn]* ) break;;
        * ) echo "   Please enter Y or N.";;
    esac
  done
}
function power_off_server() {
  clear
  while true; do
    read -r -p $'   Do you really want to\e[33m SHUT DOWN \e[0mserver? (Y/N): ' answer
    case $answer in
        [Yy]* ) poweroff; break;;
        [Nn]* ) break;;
        * ) echo "   Please enter Y or N.";;
    esac
  done
}

function install_netdata() {
  clear

  is_install_netdata=$(which netdata);
  action="INSTALL"
  if [ ! -z "$is_install_netdata" ]; then
      action="DELETE"
  fi

  action_color="\e[33m ${action} \e[0m"

  while true; do
    read -r -p "   Do you really want to$(echo -e "${action_color}")Netdata? (Y/N): " answer
    case $answer in
      [Yy]* ) action_install_or_delete_netdata; break;;
      [Nn]* ) break;;
      * ) echo "   Please enter Y or N.";;
    esac
  done
}

function delete_site() {
    clear;
    list_sites;
    echo -e "\n   Menu ->\e[33m Delete site:\e[0m\n";

    site=''
    db_name=''
    db_user=''

    read_by_def "   Enter site dir: " site $site;
    while [[ -z "$site" ]] || ! [[ " ${ARR_ALL_DIR_SITES[*]} " =~ " $site " ]]; do
            echo "   Incorrect site dir! Please enter site dir";
            read_by_def "   Enter site dir: " site $site;
    done

    full_path_site="${BS_PATH_SITES}/${site}"
    bx_path_site="${full_path_site}/bitrix"

    type="full";
    if [ -L "$bx_path_site" ]; then
      type="link";
    fi

    echo -e "\n  \e[33m You entered ${type^^} site:\e[0m";

    if [[ "$type" == "full" ]]; then

        output=$(php "$dir_helpers/php/get_database_data.php" "$bx_path_site")

        IFS=$'\n' read -r -d '' -a results <<< "$output"

        db_name="${results[0]}"
        db_user="${results[1]}"

        echo -e "\n  \e[33m The site directory (${full_path_site}) will be permanently deleted!!!\e[0m";
        echo -e "\n  \e[33m The database (${db_name}) and the user database (${db_user}) will be permanently deleted!!!\e[0m";
        echo -e "\n  \e[33m Nginx and Apache configs will be renamed!!!\e[0m";
    else

        echo -e "\n  \e[33m The site directory (${full_path_site}) will be permanently deleted!!!\e[0m";
        echo -e "\n  \e[33m Nginx and Apache configs will be renamed!!!\e[0m";
    fi

    echo -e "\n";

    action_color="\e[33m PERMANENTLY DELETE THE SITE ${site}\e[0m"
    while true; do
      local code_rand=$((100000 + RANDOM % 899999))
      read -r -p "  If you really want to$(echo -e "${action_color}"), enter the code: ${code_rand} or enter 0 to exit " answer
      case $answer in
        $code_rand ) break;;
        0 ) return 0 ;;
      esac
    done

    echo -e "\n";

    if [[ "$site" == "$BS_DEFAULT_SITE_NAME" ]]; then
        site="default";
    fi

    while true; do
      read -r -p "   Do you really want to delete site? (Y/N): " answer
      case $answer in
        [Yy]* ) action_delete_site; break;;
        [Nn]* ) break;;
        * ) echo "   Please enter Y or N.";;
      esac
    done
}
