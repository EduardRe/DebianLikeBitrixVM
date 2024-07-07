#!/bin/sh
#
# metadata_begin
# recipe: Bitrix24 GT
# tags: centos7,debian11,debian12
# revision: 6
# description_ru: Рецепт установки Bitrix24
# description_en: Bitrix CMS installing recipe
# metadata_end
#

# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/bitrix-gt/master/bitrix24_gt.sh)

cat > /root/run.sh <<\END

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
	nginxcnf='/etc/nginx/conf.d/default.conf'
	mycnf='/etc/my.cnf.d/z9_bitrix.cnf'
	phpini='/etc/php.d/z9_bitrix.ini'
	phpfpmcnf='/etc/php-fpm.d/www.conf'
	croncnf='/etc/cron.d/bitrixagent'
	rediscnf='/etc/redis.conf'
fi

if echo $os|grep -E '^Debian' >/dev/null
then
	mycnf='/etc/mysql/conf.d/z9_bitrix.cnf'
	phpini='/etc/php/8.2/fpm/conf.d/z9_bitrix.ini'
	phpini2='/etc/php/8.2/cli/conf.d/z9_bitrix.ini'
	phpfpmcnf='/etc/php/8.2/fpm/pool.d/www.conf'
	croncnf='/etc/cron.d/bitrixagent'
	rediscnf='/etc/redis/redis.conf'
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

dplRedis(){
		rediscnf > ${rediscnf}
		echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
		sysctl vm.overcommit_memory=1
	  usermod -g www-data redis
    chown redis:redis /etc/redis/ /var/log/redis/
    [[ ! -d /etc/systemd/system/redis.service.d ]] && mkdir /etc/systemd/system/redis.service.d
    echo -e '[Service]\nGroup=www-data\nPIDFile=/run/redis/redis-server.pid' > /etc/systemd/system/redis.service.d/custom.conf
    systemctl daemon-reload
    systemctl stop redis
    systemctl enable --now redis || systemctl enable --now redis-server
    systemctl start redis
}

fastDownload() {
	cat <<-\EOF > ./fast.php
		<?php
		$_SERVER['DOCUMENT_ROOT'] = '/var/www/html';
		$DOCUMENT_ROOT = $_SERVER['DOCUMENT_ROOT'];
		define('NO_KEEP_STATISTIC', true);
		define('NOT_CHECK_PERMISSIONS',true);
		define('BX_CRONTAB', true);
		define('BX_WITH_ON_AFTER_EPILOG', true);
		define('BX_NO_ACCELERATOR_RESET', true);

		require($_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_before.php');

		@set_time_limit(0);
		@ignore_user_abort(true);

		COption::SetOptionString('main','bx_fast_download','Y');
		?>
	EOF
php ./fast.php
rm ./fast.php
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
		  ),
		'pull_s1' => 'BEGIN GENERATED PUSH SETTINGS. DON\'T DELETE COMMENT!!!!',
		  'pull' => Array(
		    'value' =>  array(
			'path_to_listener' => "http://#DOMAIN#/bitrix/sub/",
			'path_to_listener_secure' => "https://#DOMAIN#/bitrix/sub/",
			'path_to_modern_listener' => "http://#DOMAIN#/bitrix/sub/",
			'path_to_modern_listener_secure' => "https://#DOMAIN#/bitrix/sub/",
			'path_to_mobile_listener' => "http://#DOMAIN#:8893/bitrix/sub/",
			'path_to_mobile_listener_secure' => "https://#DOMAIN#:8894/bitrix/sub/",
			'path_to_websocket' => "ws://#DOMAIN#/bitrix/subws/",
			'path_to_websocket_secure' => "wss://#DOMAIN#/bitrix/subws/",
			'path_to_publish' => 'http://127.0.0.1:8895/bitrix/pub/',
			'nginx_version' => '4',
			'nginx_command_per_hit' => '100',
			'nginx' => 'Y',
			'nginx_headers' => 'N',
			'push' => 'Y',
			'websocket' => 'Y',
			'signature_key' => '${cryptokey}',
			'signature_algo' => 'sha1',
			'guest' => 'N',
		    ),
		  ),
		'pull_e1' => 'END GENERATED PUSH SETTINGS. DON\'T DELETE COMMENT!!!!',
		);
	EOF
}

phpsetup(){
	grep -Rl 'opcache.max_accelerated_files' /etc/php*|xargs -I {} sed -i 's/opcache\.max_accelerated_files/;opcache.max_accelerated_files/' "{}" | :
	cat <<-\EOF
		;###Bitrix optimize
		date.timezone=Europe/Moscow
		short_open_tag = 1
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
		env[BITRIX_ENV_TYPE]=crm
	EOF
}

rediscnf() {
	cat <<-EOF
		pidfile /var/run/redis_6379.pid
		logfile /var/log/redis/redis.log
		dir /var/lib/redis
		bind 127.0.0.1
		protected-mode yes
		port 6379
		tcp-backlog 511
		unixsocketperm 777
		timeout 0
		tcp-keepalive 300
		daemonize yes
		supervised no
		loglevel notice
		databases 16
		save 86400 1
		save 7200 10
		save 3600 10000
		stop-writes-on-bgsave-error no
		rdbcompression yes
		rdbchecksum yes
		dbfilename dump.rdb
		slave-serve-stale-data yes
		slave-read-only yes
		repl-diskless-sync no
		repl-diskless-sync-delay 5
		repl-disable-tcp-nodelay no
		slave-priority 100
		appendonly no
		appendfilename "appendonly.aof"
		appendfsync everysec
		no-appendfsync-on-rewrite no
		auto-aof-rewrite-percentage 100
		auto-aof-rewrite-min-size 64mb
		aof-load-truncated yes
		lua-time-limit 5000
		slowlog-log-slower-than 10000
		slowlog-max-len 128
		latency-monitor-threshold 0
		notify-keyspace-events ""
		hash-max-ziplist-entries 512
		hash-max-ziplist-value 64
		list-max-ziplist-size -2
		list-compress-depth 0
		set-max-intset-entries 512
		zset-max-ziplist-entries 128
		zset-max-ziplist-value 64
		hll-sparse-max-bytes 3000
		activerehashing yes
		client-output-buffer-limit normal 0 0 0
		client-output-buffer-limit slave 256mb 64mb 60
		client-output-buffer-limit pubsub 32mb 8mb 60
		hz 10
		aof-rewrite-incremental-fsync yes
		maxmemory 459mb
		maxmemory-policy allkeys-lru
	EOF
	if echo $os|grep -E '^CentOS[a-zA-Z ]*[7]{1}\.' > /dev/null
  then
		echo unixsocket /tmp/redis.sock
	else
		echo unixsocket /var/run/redis/redis.sock
	fi

}

cronagent(){
	local user=${1}
	cat <<-EOF
		*/5 * * * * ${user} /usr/bin/php /var/www/html/bitrix/modules/main/tools/cron_events.php >/dev/null 2>&1
		0 * * * * root envver=\$(wget -qO- 'https://repos.1c-bitrix.ru/yum/SRPMS/' | grep -Eo 'bitrix-env-[0-9]\.[^src\.rpm]*'|sort -n|tail -n 1 | sed 's/bitrix-env-//;s/-/./') && touch /etc/php-fpm.d/bx && echo "env[BITRIX_VA_VER]=\${envver}" > /etc/php-fpm.d/bx && systemctl reload php-fpm && sed -i "/BITRIX_VA_VER/d;\\\$a SetEnv BITRIX_VA_VER \${envver}" /etc/httpd/bx/conf/00-environment.conf && systemctl reload httpd
	EOF
}

dplPush(){
	cd /opt
	wget -q https://repo.bitrix.info/vm/push-server-0.3.0.tgz
	npm install --production ./push-server-0.3.0.tgz
	rm ./push-server-0.3.0.tgz
	ln -sf /opt/node_modules/push-server/etc/push-server /etc/push-server

	cd /opt/node_modules/push-server
	cp etc/init.d/push-server-multi /usr/local/bin/push-server-multi
	mkdir /etc/sysconfig
	cp etc/sysconfig/push-server-multi  /etc/sysconfig/push-server-multi
	cp etc/push-server/push-server.service  /etc/systemd/system/
	ln -sf /opt/node_modules/push-server /opt/push-server
	useradd -g www-data bitrix

	cat <<EOF >> /etc/sysconfig/push-server-multi
GROUP=www-data
SECURITY_KEY="${cryptokey}"
RUN_DIR=/tmp/push-server
REDIS_SOCK=/var/run/redis/redis.sock
WS_HOST=127.0.0.1
EOF
	/usr/local/bin/push-server-multi configs pub
	/usr/local/bin/push-server-multi configs sub
	echo 'd /tmp/push-server 0770 bitrix www-data -' > /etc/tmpfiles.d/push-server.conf
	systemd-tmpfiles --remove --create
	[[ ! -d /var/log/push-server ]] && mkdir /var/log/push-server
	chown bitrix:www-data /var/log/push-server

	sed -i 's|User=.*|User=bitrix|;s|Group=.*|Group=www-data|;s|ExecStart=.*|ExecStart=/usr/local/bin/push-server-multi systemd_start|;s|ExecStop=.*|ExecStop=/usr/local/bin/push-server-multi stop|' /etc/systemd/system/push-server.service
	systemctl daemon-reload
	systemctl stop push-server
	systemctl --now enable push-server
	systemctl start push-server
}

apacheCnf() {
		cat <<-EOF
		Include bx/conf/*.conf
    Include bx/custom/*.conf
    Include bx/vhosts/*.conf
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

disableTHP(){
	cat <<EOF > /etc/systemd/system/disable-thp.service
	[Unit]
  Description=Disable Transparent Huge Pages

  [Service]
  Type=simple
  ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"

  [Install]
  WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start disable-thp
systemctl enable disable-thp
}


mkdir -p /var/www/html

if echo $os|grep -E '^CentOS[a-zA-Z ]*[7]{1}\.' > /dev/null
then

	release=7
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
	cat <<-\EOF >/etc/yum.repos.d/bitrix.repo
	[bitrix]
		name=$OS $releasever - $basearch
		failovermethod=priority
		baseurl=http://repos.1c-bitrix.ru/yum/el/$releasever/$basearch
		enabled=1
		gpgcheck=1
		gpgkey=http://repos.1c-bitrix.ru/yum/RPM-GPG-KEY-BitrixEnv
	EOF
	yum clean all
	yum install -y wget https://rpm.nodesource.com/pub_16.x/nodistro/repo/nodesource-release-nodistro-1.noarch.rpm
	yum install -y nodejs --setopt=nodesource-nodejs.module_hotfixes=1

	yum install -y httpd nginx MariaDB-server MariaDB-client php php-fpm php-opcache php-curl php-mbstring php-xml php-json php-mysqli php-gd php-zip php-ldap curl bzip2 catdoc bx-push-server redis sysfsutils
	unset http_proxy
	echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
	echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf
	sysctl vm.overcommit_memory=1
	sysctl -w net.core.somaxconn=65535
	disableTHP

	envver=$(wget -qO- 'https://repos.1c-bitrix.ru/yum/SRPMS/' | grep -Eo 'bitrix-env-[0-9]\.[^src\.rpm]*'|sort -n|tail -n 1 | sed 's/bitrix-env-//;s/-/./')
	ip=$(wget -qO- "https://ipinfo.io/ip")
	echo "WS_HOST=127.0.0.1" >> /etc/sysconfig/push-server-multi
	/etc/init.d/push-server-multi reset
	echo -e '[Service]\nGroup=apache' > /etc/systemd/system/redis.service.d/custom.conf
	cryptokey=$(grep 'SECURITY_KEY' /etc/sysconfig/push-server-multi |cut -d= -f2)
	systemctl daemon-reload
	usermod -g apache redis

	mkdir /var/run/mariadb
	chown mysql /var/run/mariadb
	echo 'd /var/run/mariadb 0775 mysql -' > /etc/tmpfiles.d/mariadb.conf
	[ $release -eq 7 ] && (firewall-cmd --zone=public --add-port=80/tcp --add-port=443/tcp --add-port=21/tcp --add-port=8893/tcp --permanent && firewall-cmd --reload) || (iptables -I INPUT 1 -p tcp -m multiport --dports 21,80,443 -j ACCEPT && iptables-save > /etc/sysconfig/iptables)
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
	rediscnf > ${rediscnf}
	sed -i 's/general/crm/' /etc/httpd/bx/conf/00-environment.conf
	echo "env[BITRIX_VA_VER]=${envver}" > /etc/php-fpm.d/bx
	phpsetup >> ${phpini}
	fpmsetup 'apache' > ${phpfpmcnf}
	cronagent 'apache' > ${croncnf}
	mysqlcnf > ${mycnf}
	ln -s /etc/nginx/bx/site_avaliable/push.conf /etc/nginx/bx/site_enabled/
	chown -R apache:apache /var/www/html
	chmod 771 /var/www/html


	echo "env[BITRIX_VA_VER]=${envver}" >> ${phpfpmcnf}
	sed -i "/BITRIX_VA_VER/d;\$a SetEnv BITRIX_VA_VER ${envver}" /etc/httpd/bx/conf/00-environment.conf
	chmod 644 ${mycnf} ${phpini} ${phpfpmcnf} ${croncnf} ${nginxcnf} ${rediscnf}

	systemctl enable redis php-fpm nginx httpd push-server mariadb
	systemctl restart redis crond httpd nginx php-fpm mysql push-server
	mysql -e "create database bitrix;create user bitrix@localhost;grant all on bitrix.* to bitrix@localhost;set password for bitrix@localhost = PASSWORD('${mypwddb}')"
fi


if echo $os|grep -Eo 'Debian' >/dev/null
then
	apt update
	apt-get install -y software-properties-common apt-transport-https debconf-utils lsb-release gnupg gnupg2 debian-archive-keyring pwgen make build-essential wget curl
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
	apt install -y php8.2-opcache php8.2-mysqli php8.2-fpm php8.2-gd php8.2-curl php8.2-xml php8.2-mbstring \
		mariadb-server mysql-common mariadb-client \
		nginx catdoc exim4 exim4-config apache2 libapache2-mod-rpaf \
		nodejs npm redis sysfsutils nftables
	echo 'kernel/mm/transparent_hugepage/enabled = madvise' >> /etc/sysfs.conf
	systemctl restart sysfsconf
	sed -i "s/dc_eximconfig_configtype='local'/dc_eximconfig_configtype='internet'/" /etc/exim4/update-exim4.conf.conf && dpkg-reconfigure --frontend noninteractive exim4-config
	ip=$(wget -qO- "https://ipinfo.io/ip")
	mariadb -e "create database bitrix;create user bitrix@localhost;grant all on bitrix.* to bitrix@localhost;set password for bitrix@localhost = PASSWORD('${mypwddb}')"
	nfTabl
	dplRedis
	dplPush

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
	ln -s /etc/nginx/bx/site_avaliable/push.conf /etc/nginx/bx/site_enabled/

	envver=$(wget -qO- 'https://repos.1c-bitrix.ru/yum/SRPMS/' | grep -Eo 'bitrix-env-[0-9]\.[^src\.rpm]*'|sort -n|tail -n 1 | sed 's/bitrix-env-//;s/-/./')

	echo "env[BITRIX_VA_VER]=${envver}" >> ${phpfpmcnf}
	sed -i 's/general/crm/' /etc/apache2/bx/conf/00-environment.conf
	sed -i "/BITRIX_VA_VER/d;\$a SetEnv BITRIX_VA_VER ${envver}" /etc/apache2/bx/conf/00-environment.conf
	chmod 644 ${mycnf} ${phpini} ${phpfpmcnf} ${croncnf} ${phpini2}

	sed -i 's|user apache|user www-data|' /etc/nginx/nginx.conf
	rm /etc/apache2/sites-enabled/000-default.conf


	sed -i 's|collation-server=utf8_general_ci|collation-server=utf8mb4_general_ci|' /etc/mysql/conf.d/z9_bitrix.cnf
	chmod 644 ${mycnf} ${phpini} ${phpfpmcnf} ${croncnf} ${phpini2}

	systemctl restart cron mysql php8.2-fpm apache2 nginx php8.2-fpm redis-server push-server
	systemctl enable cron mysql php8.2-fpm apache2 nginx php8.2-fpm push-server sysfsconf.service
fi

ip=$(wget -qO- "https://ipinfo.io/ip")
echo 'gt smart' > /env
curl -s "http://${ip}/"|grep 'bitrixsetup' >/dev/null || exit 1

END

bash /root/run.sh
