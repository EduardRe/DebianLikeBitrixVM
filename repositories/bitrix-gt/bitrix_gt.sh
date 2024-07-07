#!/usr/bin/env bash
#
# metadata_begin
# recipe: Bitrix GT
# tags: centos,debian11,debian12
# revision: 6
# description_ru: Рецепт установки Bitrix CMS
# description_en: Bitrix CMS installing recipe
# metadata_end
#

# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/bitrix-gt/master/bitrix_gt.sh)

cat > /root/run.sh <<\END

unset http_proxy
set -x
LOG_PIPE=/tmp/log.pipe
mkfifo ${LOG_PIPE}
LOG_FILE=/root/recipe.log
touch ${LOG_FILE}
chmod 600 ${LOG_FILE}
tee < ${LOG_PIPE} ${LOG_FILE} &
exec > ${LOG_PIPE}
exec 2> ${LOG_PIPE}

os=`set -o pipefail && { cat /etc/centos-release || { source /etc/os-release && echo $PRETTY_NAME; } ;}`
if echo $os|grep -E '^CentOS.* [7]{1}\.' >/dev/null
then
	mycnf='/etc/my.cnf.d/z9_bitrix.cnf'
	phpini='/etc/php.d/z9_bitrix.ini'
	phpfpmcnf='/etc/php-fpm.d/www.conf'
	croncnf='/etc/cron.d/bitrixagent'
fi

if echo $os|grep -E '^Debian' >/dev/null
then
	mycnf='/etc/mysql/conf.d/z9_bitrix.cnf'
	phpini='/etc/php/8.2/fpm/conf.d/z9_bitrix.ini'
	phpini2='/etc/php/8.2/cli/conf.d/z9_bitrix.ini'
	phpfpmcnf='/etc/php/8.2/fpm/pool.d/www.conf'
	croncnf='/etc/cron.d/bitrixagent'
fi

mypwd=$(echo $RANDOM|md5sum|head -c 15)
mypwddb=$(echo $RANDOM|md5sum|head -c 15)
cryptokey=$(echo $RANDOM|md5sum|cut -d' ' -f1)

dbconn() {
	cat <<-EOF
		<?
		define("DBPersistent", false);
		\$DBType = "mysql";
		\$DBHost = "localhost";
		\$DBLogin = 'bitrix';
		\$DBPassword = '${mypwddb}';
		\$DBName = "bitrix";
		\$DBDebug = false;
		\$DBDebugToFile = false;
		define("DELAY_DB_CONNECT", true);
		define("CACHED_b_file", 3600);
		define("CACHED_b_file_bucket_size", 10);
		define("CACHED_b_lang", 3600);
		define("CACHED_b_option", 3600);
		define("CACHED_b_lang_domain", 3600);
		define("CACHED_b_site_template", 3600);
		define("CACHED_b_event", 3600);
		define("CACHED_b_agent", 3660);
		define("CACHED_menu", 3600);
		define("BX_FILE_PERMISSIONS", 0644);
		define("BX_DIR_PERMISSIONS", 0755);
		@umask(~(BX_FILE_PERMISSIONS|BX_DIR_PERMISSIONS)&0777);
		define("MYSQL_TABLE_TYPE", "INNODB");
		define("SHORT_INSTALL", true);
		define("VM_INSTALL", true);
		define("BX_UTF", true);
		define("BX_CRONTAB_SUPPORT", true);
		define("BX_COMPRESSION_DISABLED", true);
		define("BX_DISABLE_INDEX_PAGE", true);
		define("BX_USE_MYSQLI", true);
		?>
	EOF
}

settings() {
	cat <<-EOF
		<?php
		return array (
		  'utf_mode' =>
		  array (
		    'value' => true,
		    'readonly' => true,
		  ),
		  'cache_flags' =>
		  array (
		    'value' =>
		    array (
		      'config_options' => 3600,
		      'site_domain' => 3600,
		    ),
		    'readonly' => false,
		  ),
		  'cookies' =>
		  array (
		    'value' =>
		    array (
		      'secure' => false,
		      'http_only' => true,
		    ),
		    'readonly' => false,
		  ),
		  'exception_handling' =>
		  array (
		    'value' =>
		    array (
		      'debug' => false,
		      'handled_errors_types' => 4437,
		      'exception_errors_types' => 4437,
		      'ignore_silence' => false,
		      'assertion_throws_exception' => true,
		      'assertion_error_type' => 256,
		      'log' => array (
			  'settings' =>
			  array (
			    'file' => '/var/log/php/exceptions.log',
			    'log_size' => 1000000,
			),
		      ),
		    ),
		    'readonly' => false,
		  ),
		  'crypto' => 
		  array (
		    'value' => 
		    array (
			'crypto_key' => "${cryptokey}",
		    ),
		    'readonly' => true,
		  ),
		  'connections' =>
		  array (
		    'value' =>
		    array (
		      'default' =>
		      array (
			'className' => '\\Bitrix\\Main\\DB\\MysqliConnection',
			'host' => 'localhost',
			'database' => 'bitrix',
			'login'    => 'bitrix',
			'password' => '${mypwddb}',
			'options' => 2,
		      ),
		    ),
		    'readonly' => true,
		  )
		);
	EOF
}

phpsetup(){
	grep -Rl 'opcache.max_accelerated_files' /etc/php*|xargs -I {} sed -i 's/opcache\.max_accelerated_files/;opcache.max_accelerated_files/' "{}" | :
	cat <<-\EOF
		;###Bitrix optimize
		date.timezone=Europe/Moscow
		short_open_tag = On
		max_input_vars=10000
		mbstring.func_overload=0
		mbstring.internal_encoding=utf-8
		upload_max_filesize=64M
		post_max_size=64M
		opcache.max_accelerated_files=100000
		realpath_cache_size=4096k
		memory_limit = 512M
		pcre.jit = 0
		opcache.revalidate_freq = 0
		max_execution_time=120
	EOF
}

mysqlcnf(){
	cat <<-EOF
		[mysqld]
		innodb_buffer_pool_size = 384M
		innodb_buffer_pool_instances = 1
		innodb_flush_log_at_trx_commit = 2
		innodb_flush_method = O_DIRECT
		innodb_strict_mode = OFF
		query_cache_type = 1
		query_cache_size=16M
		query_cache_limit=4M
		key_buffer_size=256M
		join_buffer_size=2M
		sort_buffer_size=4M
		tmp_table_size=128M
		max_heap_table_size=128M
		thread_cache_size = 4
		table_open_cache = 2048
		max_allowed_packet = 128M
		transaction-isolation = READ-COMMITTED
		performance_schema = OFF
		sql_mode = ""
		character-set-server=utf8
		collation-server=utf8_general_ci
		init-connect="SET NAMES utf8"
		explicit_defaults_for_timestamp = 1
	EOF
}

fpmsetup() {
		cat <<-EOF
			[www]
			user = $1
			group = $1
			listen = 127.0.0.1:9000
			listen.allowed_clients = 127.0.0.1
			pm = dynamic
			pm.max_children = 12
			pm.start_servers = 2
			pm.min_spare_servers = 2
			pm.max_spare_servers = 5
			slowlog = /var/log/php-fpm/www-slow.log
			php_flag[display_errors] = off
			php_admin_value[error_log] = /var/log/php-fpm/www-error.log
			php_admin_flag[log_errors] = on
			php_value[session.save_handler] = files
			php_value[session.save_path]    = /var/lib/php/session
			php_value[soap.wsdl_cache_dir]  = /var/lib/php/wsdlcache
		EOF
}

nfTabl(){
	cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority 0; policy drop;
		iif "lo" accept comment "Accept any localhost traffic"
		ct state invalid drop comment "Drop invalid connections"
		ip protocol icmp limit rate 4/second accept
		ip6 nexthdr ipv6-icmp limit rate 4/second accept
		ct state { established, related } accept comment "Accept traffic originated from us"
		tcp dport 22 accept comment "ssh"
		tcp dport { 80, 443 } accept comment "web"
	}
	chain forward {
		type filter hook forward priority 0;
	}
	chain output {
		type filter hook output priority 0;
	}
}
EOF
	systemctl restart nftables
	systemctl enable nftables.service
}

cronagent(){
	cat <<-EOF
		*/5 * * * * ${1} /usr/bin/php /var/www/html/bitrix/modules/main/tools/cron_events.php >/dev/null 2>&1
	EOF
}

mkdir -p /var/www/html

if echo $os|grep -E '^CentOS[a-zA-Z ]*[7]{1}\.' > /dev/null
then
	release=$(echo $os|grep -Eo '^CentOS[a-zA-Z ]*[7]'|awk '{print $NF}')
	yum install -y http://rpms.remirepo.net/enterprise/remi-release-${release}.rpm  yum-utils fail2ban
	yum-config-manager --enable remi-php82
	cat <<-\EOF >/etc/yum.repos.d/mariadb.repo
		[mariadb]
		name = MariaDB
		baseurl = https://mirror.docker.ru/mariadb/yum/10.11/centos/$releasever/$basearch
		module_hotfixes = 1
		gpgkey = https://mirror.docker.ru/mariadb/yum/RPM-GPG-KEY-MariaDB
		gpgcheck = 1
	EOF
	cat <<-\EOF >/etc/yum.repos.d/nginx.repo
		[nginx]
		name=nginx repo
		baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
		gpgcheck=0
		enabled=1
	EOF
	yum clean all
	yum install -y wget httpd nginx MariaDB-server MariaDB-client php php-fpm php-opcache php-curl php-mbstring php-xml php-json php-mysqli php-gd curl bzip2 catdoc
	ip=$(wget -qO- "https://ipinfo.io/ip")
	systemctl enable php-fpm nginx httpd mariadb
	mkdir /var/run/mariadb
	chown mysql /var/run/mariadb
	echo 'd /var/run/mariadb 0775 mysql -' > /etc/tmpfiles.d/mariadb.conf
	[ $release -eq 7 ] && (firewall-cmd --zone=public --add-port=80/tcp --add-port=443/tcp --add-port=21/tcp --permanent && firewall-cmd --reload) || (iptables -I INPUT 1 -p tcp -m multiport --dports 21,80,443 -j ACCEPT && iptables-save > /etc/sysconfig/iptables)
	cd /var/www/html
	# wget -qO- http://rep.fvds.ru/cms/bitrixstable.tgz|tar -zxp
	wget -qO- https://raw.githubusercontent.com/YogSottot/bitrix-gt/master/bitrixstable.tgz|tar -zxp
	mv -f ./nginx/* /etc/nginx/
	rm -rf /etc/httpd/{conf,conf.d,conf.modules.d}
	mv -f ./httpd/* /etc/httpd/
	rm -rf ./{httpd,nginx}
	mkdir -p bitrix/php_interface
	dbconn > bitrix/php_interface/dbconn.php
	settings > bitrix/.settings.php
	phpsetup >> ${phpini}
	fpmsetup 'apache' > ${phpfpmcnf}
	cronagent 'apache' > ${croncnf}
	mysqlcnf > ${mycnf}
	chown -R apache:apache /var/www/html
	chmod 771 /var/www/html
  systemctl start mysql
	mysql -e "create database bitrix;create user bitrix@localhost;grant all on bitrix.* to bitrix@localhost;set password for bitrix@localhost = PASSWORD('${mypwddb}')"

	envver=$(wget -qO- 'https://repos.1c-bitrix.ru/yum/SRPMS/' | grep -Eo 'bitrix-env-[0-9]\.[^src\.rpm]*'|sort -n|tail -n 1 | sed 's/bitrix-env-//;s/-/./')
  touch /etc/php-fpm.d/bx
  echo "env[BITRIX_VA_VER]=${envver}" > /etc/php-fpm.d/bx
  sed -i "/BITRIX_VA_VER/d;\$a SetEnv BITRIX_VA_VER ${envver}" /etc/httpd/bx/conf/00-environment.conf
  chmod 644 ${mycnf} ${phpini} ${phpfpmcnf} ${croncnf}

	systemctl restart mysql crond httpd nginx php-fpm
fi

apacheCnf() {
		cat <<-EOF
		Include bx/conf/*.conf
    Include bx/custom/*.conf
    Include bx/vhosts/*.conf
EOF
}

if echo $os|grep -Eo 'Debian' >/dev/null
then
	apt update
	apt-get install -y software-properties-common apt-transport-https debconf-utils curl lsb-release gnupg gnupg2 debian-archive-keyring
	type=$(lsb_release -is|tr '[A-Z]' '[a-z]')
	release=$(lsb_release -sc|tr '[A-Z]' '[a-z]')
	mkdir -p /etc/apt/keyrings
	curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
	echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.docker.ru/mariadb/repo/11.3/$type $release main" > /etc/apt/sources.list.d/mariadb.list
	wget -q -O - https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
	gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
	cat <<-EOF > /etc/apt/sources.list.d/nginx.list
		deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/${type}/ ${release} nginx
	EOF
	export DEBIAN_FRONTEND="noninteractive"
	debconf-set-selections <<< "mariadb-server mysql-server/root_password password ${mypwd}"
	debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password ${mypwd}"
	debconf-set-selections <<< 'exim4-config exim4/dc_eximconfig_configtype select internet site; mail is sent and received directly using SMTP'
	echo -e "[client]\npassword=${mypwd}" > /root/.my.cnf

	wget -qO /etc/apt/trusted.gpg.d/php.gpg https://ftp.mpi-inf.mpg.de/mirrors/linux/mirror/deb.sury.org/repositories/php/apt.gpg
	echo "deb https://ftp.mpi-inf.mpg.de/mirrors/linux/mirror/deb.sury.org/repositories/php ${release} main" > /etc/apt/sources.list.d/php8.2.list
	apt update
	apt install -y php8.2-opcache php8.2-mysqli php8.2-fpm php8.2-gd php8.2-curl php8.2-xml php8.2-mbstring mariadb-server mysql-common mariadb-client nginx catdoc exim4 exim4-config apache2 libapache2-mod-rpaf nftables
	sed -i "s/dc_eximconfig_configtype='local'/dc_eximconfig_configtype='internet'/" /etc/exim4/update-exim4.conf.conf && dpkg-reconfigure --frontend noninteractive exim4-config
	ip=$(wget -qO- "https://ipinfo.io/ip")
	mariadb -e "create database bitrix;create user bitrix@localhost;grant all on bitrix.* to bitrix@localhost;set password for bitrix@localhost = PASSWORD('${mypwddb}')"
	nfTabl

	cd /var/www/html || exit
	# wget -qO- http://rep.fvds.ru/cms/bitrixstable.tgz|tar -zxp
	wget -qO- https://raw.githubusercontent.com/YogSottot/bitrix-gt/master/bitrixstable.tgz|tar -zxp
	mkdir -p bitrix/php_interface
	dbconn > bitrix/php_interface/dbconn.php
	settings > bitrix/.settings.php

	mv -f ./httpd/bx /etc/apache2/bx
	a2dismod mpm_event
	a2enmod mpm_worker
	a2enmod remoteip
	a2enmod rewrite
	a2enmod proxy
	a2enmod proxy_fcgi
	ln -s /var/log/apache2 /etc/apache2/logs
	echo 'Listen 127.0.0.1:8888' > /etc/apache2/ports.conf
	apacheCnf >> /etc/apache2/apache2.conf
	rm /etc/apache2/bx/conf/bx_apache_site_name_port.conf

	mv -f ./nginx/* /etc/nginx/
	rm -rf ./{httpd,nginx}

	phpsetup >> ${phpini}
	phpsetup >> ${phpini2}
	fpmsetup 'www-data' > ${phpfpmcnf}
	cronagent 'www-data' > ${croncnf}
	mysqlcnf > ${mycnf}
	chown -R www-data:www-data /var/www/html
	ln -s /var/lib/php/sessions /var/lib/php/session

	envver=$(wget -qO- 'https://repos.1c-bitrix.ru/yum/SRPMS/' | grep -Eo 'bitrix-env-[0-9]\.[^src\.rpm]*'|sort -n|tail -n 1 | sed 's/bitrix-env-//;s/-/./')

	echo "env[BITRIX_VA_VER]=${envver}" >> ${phpfpmcnf}
	sed -i "/BITRIX_VA_VER/d;\$a SetEnv BITRIX_VA_VER ${envver}" /etc/apache2/bx/conf/00-environment.conf
	chmod 644 ${mycnf} ${phpini} ${phpfpmcnf} ${croncnf} ${phpini2}

	sed -i 's|user apache|user www-data|' /etc/nginx/nginx.conf
	rm /etc/apache2/sites-enabled/000-default.conf


	sed -i 's|collation-server=utf8_general_ci|collation-server=utf8mb4_general_ci|' /etc/mysql/conf.d/z9_bitrix.cnf
	chmod 644 ${mycnf} ${phpini} ${phpfpmcnf} ${croncnf} ${phpini2}

	systemctl restart cron mysql php8.2-fpm apache2 nginx php8.2-fpm
	systemctl enable cron mysql php8.2-fpm apache2 nginx php8.2-fpm
fi


ip=$(wget -qO- "https://ipinfo.io/ip")
echo 'gt smart' > /env
curl -s "http://${ip}/"|grep 'bitrixsetup' >/dev/null || exit 1

END

bash /root/run.sh
