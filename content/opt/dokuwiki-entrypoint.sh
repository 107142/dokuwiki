#! /bin/bash

set -eo pipefail

PHP_FPM_VERSION=7.4
PHP_FPM_CONFIG_PATH=/etc/php/${PHP_FPM_VERSION}/fpm/conf.d/
PHP_FPM_CONFIG=${PHP_FPM_CONFIG_PATH}/docker.ini
PHP_FPM_CONFIG_POOL_PATH=/etc/php/${PHP_FPM_VERSION}/fpm/pool.d/
PHP_FPM_CONFIG_POOL=${PHP_FPM_CONFIG_POOL_PATH}/www.conf

ISSET_DOKUWIKI_ADMIN_PASS=${DOKUWIKI_ADMIN_PASS:+<set via env variable>}
export DOKUWIKI_ADMIN_USER=${DOKUWIKI_ADMIN_USER:-"admin"}
export DOKUWIKI_ADMIN_PASS=${DOKUWIKI_ADMIN_PASS:-"$(openssl rand -base64 12)"}
export DOKUWIKI_ADMIN_PASS_HASH=$(htpasswd -nbBC 10 "${DOKUWIKI_ADMIN_USER}" "${DOKUWIKI_ADMIN_PASS}")

export DOKUWIKI_DEFAULT_LOCALE=${DEFAULT_LOCALE:-en_US.UTF-8}
export DOKUWIKI_LOCALES=${DOKUWIKI_LOCALES:-en_US.UTF-8 UTF-8}
export DOKUWIKI_LANG=${DOKUWIKI_LANG:-en_US.UTF-8}
export APACHE2_SHIBBOLETH=${APACHE2_SHIBBOLETH:-0}
export APACHE2_SERVER_NAME=${APACHE2_SERVER_NAME:-dokuwiki}
export APACHE2_SERVER_ALIAS=${APACHE2_SERVER_ALIAS:-wiki}
export APACHE2_SERVER_ADMIN=${APACHE2_SERVER_ADMIN:-webmaster@localhost}

echo -e "INITIALIZING DOKUWIKI CONTAINER\n"

update-ca-certificates --fresh >/dev/null 2>&1
echo -e "Certificates: Updated CA\n"

if [ ! -z "${TZ}" ]; then
	TZFILE="/usr/share/zoneinfo/${TZ}"
	if [ ! -f "${TZFILE}" ]; then
		echo "Timezone: ${TZ} not available, using default timezone"
	else
		ln -sf "${TZFILE}" /etc/localtime
		dpkg-reconfigure -f noninteractive tzdata
	fi
fi

echo "Apache2: Preparing"
grep -q ServerName /etc/apache2/apache2.conf || echo ServerName ${APACHE2_SERVER_NAME} >> /etc/apache2/apache2.conf

cat > /etc/apache2/conf-available/fqdn.conf <<-END
ServerName ${APACHE2_SERVER_NAME}
ServerAlias ${APACHE2_SERVER_ALIAS}
ServerAdmin ${APACHE2_SERVER_ADMIN}
END

# Enable TLS support if certificates are mounted
if [ -f /etc/apache2/ssl/dokuwiki.crt ] && [ -f /etc/apache2/ssl/dokuwiki.key ]; then
	echo "Apache2: Enabling TLS"
	# If there is no chain needed, we have to generate an empty
	# file with a single line to interpret it correctly as "no chain"
		if [ ! -f /etc/apache2/ssl/dokuwiki.chain ]; then
		echo > /etc/apache2/ssl/dokuwiki.chain
	fi
	a2enmod -q ssl >/dev/null 2>&1
	a2ensite -q dokuwiki-ssl >/dev/null 2>&1
	chown www-data:www-data /etc/apache2/ssl/dokuwiki.{crt,key} || true

	if [ -n "${APACHE2_CSP:-}" ]; then
		cat > /etc/apache2/conf-available/dokuwiki_csp.conf <<-END
		Header set Content-Security-Policy ${APACHE2_CSP}
		END
		echo -e "Apache2: CSP enabled\n"
	fi

	case "${APACHE2_HTTP}" in
		BOTH)
			a2ensite -q 000-default >/dev/null 2>&1
			a2dissite -q dokuwiki-ssl-redirect >/dev/null 2>&1
			;;
		REDIRECT)
			a2dissite -q 000-default >/dev/null 2>&1
			a2ensite -q dokuwiki-ssl-redirect >/dev/null 2>&1
			;;
	esac

else
	echo -e "Apache2: Running plain HTTP\n"
	a2ensite -q 000-default >/dev/null 2>&1
	a2dissite -q dokuwiki-ssl >/dev/null 2>&1
	a2dissite -q dokuwiki-ssl-redirect >/dev/null 2>&1
fi

if [ "x${APACHE2_SHIBBOLETH}" = "x1" ]; then
	a2enmod -q shib >/dev/null 2>&1
	a2enconf -q shib >/dev/null 2>&1

	if [ ! "$(ls -A /etc/shibboleth)" ]; then
		echo "Apache2: Copying fresh config-files for /etc/shibboleth"
		cp -Ra /etc/shibboleth.dist/* /etc/shibboleth/
	else
		[ -e /etc/shibboleth ] && rm -rf /etc/shibboleth.dist
	fi
	echo -e "Apache2: Enabled Shibboleth\n"
else
	a2dismod -q shib >/dev/null 2>&1
	a2disconf -q shib >/dev/null 2>&1
fi

a2enmod -q remoteip >/dev/null 2>&1

echo "PHP-FPM: Preparing"

a2enconf -q php${PHP_FPM_VERSION}-fpm >/dev/null 2>&1

ini_set ${PHP_FPM_CONFIG} opcache opcache.enable ${PHP_FPM_OPCACHE_ENABLE:-1}
ini_set ${PHP_FPM_CONFIG} opcache opcache.enable_cli ${PHP_FPM_OPCACHE_ENABLE_CLI:-0}
ini_set ${PHP_FPM_CONFIG} opcache opcache.fast_shutdown ${PHP_FPM_OPCACHE_FAST_SHUTDOWN:-1}
ini_set ${PHP_FPM_CONFIG} opcache opcache.memory_consumption ${PHP_FPM_OPCACHE_MEMORY_CONSUMPTION:-256M}
ini_set ${PHP_FPM_CONFIG} opcache opcache.interned_strings_buffer ${PHP_FPM_OPCACHE_STRINGS_BUFFER:-16}
ini_set ${PHP_FPM_CONFIG} opcache opcache.max_accelerated_files ${PHP_FPM_OPCACHE_MAX_ACCELERATED:-10000}
ini_set ${PHP_FPM_CONFIG} opcache opcache.revalidate_freq ${PHP_FPM_OPCACHE_REVALIDATE_FREQ:-60}
ini_set ${PHP_FPM_CONFIG} Session session.use_strict_mode 1
ini_set ${PHP_FPM_CONFIG} www post_max_size ${PHP_FPM_MAX_POST:-16M}
ini_set ${PHP_FPM_CONFIG} www upload_max_filesize ${PHP_FPM_MAX_UPLOAD:-16M}
ini_set ${PHP_FPM_CONFIG} www max_execution_time ${PHP_FPM_MAX_EXECUTION_TIME:-10800}
ini_set ${PHP_FPM_CONFIG} www max_input_time ${PHP_FPM_MAX_INPUT_TIME:-3600}
ini_set ${PHP_FPM_CONFIG} www expose_php ${PHP_FPM_EXPOSE:-Off}
ini_set ${PHP_FPM_CONFIG} www memory_limit ${PHP_FPM_MEMORY_LIMIT:-256M}

ini_set ${PHP_FPM_CONFIG_POOL} www access.log /dev/stdout
ini_set ${PHP_FPM_CONFIG_POOL} www clear_env no
ini_set ${PHP_FPM_CONFIG_POOL} www user ""
ini_set ${PHP_FPM_CONFIG_POOL} www group ""
ini_set ${PHP_FPM_CONFIG_POOL} www catch_workers_output yes
ini_set ${PHP_FPM_CONFIG_POOL} www decorate_workers_output no
ini_set ${PHP_FPM_CONFIG_POOL} www listen /run/php/php${PHP_FPM_VERSION}-fpm.sock
ini_set ${PHP_FPM_CONFIG_POOL} www pm ${PHP_FPM_PM:-dynamic}
ini_set ${PHP_FPM_CONFIG_POOL} www pm.min_spare_servers ${PHP_FPM_PM_MIN:-2}
ini_set ${PHP_FPM_CONFIG_POOL} www pm.max_spare_servers ${PHP_FPM_PM_MAX:-6}
ini_set ${PHP_FPM_CONFIG_POOL} www pm.process_idle_timeout ${PHP_FPM_PM_IDLE:-30}
ini_set ${PHP_FPM_CONFIG_POOL} www pm.max_children ${PHP_FPM_PM_CHILDREN:-6}
ini_set ${PHP_FPM_CONFIG_POOL} www pm.max_requests ${PHP_FPM_PM_REQUESTS:-100000}
echo -e "PHP-FPM configured\n"

echo "DokuWiki: Setting up locales"
while read -r line
do
if [ ! -z "$line" ]; then
	sed -i -E "s/^# ? ?$line/$line/gi" /etc/locale.gen
fi
done <<<"${DOKUWIKI_LOCALES}"
echo "LANG=${DOKUWIKI_LANG}" > /etc/default/locale
locale-gen
export LC_ALL=${DOKUWIKI_DEFAULT_LOCALE}
export LANGUAGE=${DOKUWIKI_LANG}
export LANG=${DOKUWIKI_LANG}

echo "DokuWiki: Configuring"
if [ ! "$(ls -A /etc/dokuwiki)" ]; then
	echo "DokuWiki: Copying fresh config-files for /etc/dokuwiki"

	cp -Ra /etc/dokuwiki.dist/* /etc/dokuwiki/
	cp -Ra /var/lib/dokuwiki.dist/* /var/lib/dokuwiki
	chown www-data /etc/dokuwiki /etc/dokuwiki/local.php /etc/dokuwiki/plugins.local.php || true
	chown -R www-data /var/lib/dokuwiki/lib/plugins /var/lib/dokuwiki/lib/tpl || true
	chown www-data /etc/dokuwiki/local.php /etc/dokuwiki/plugins.local.php || true
	sed -i "s/Allow from localhost 127.0.0.1 ::1/Allow from all/g" /etc/dokuwiki/apache.conf
	sed -i "s/smd5/bcrypt/g" /etc/dokuwiki/dokuwiki.php

else
	[ -e /etc/dokuwiki ] && rm -rf /etc/dokuwiki.dist
	[ -e /var/lib/dokuwiki ] && rm -rf /var/lib/dokuwiki.dist
fi

echo "DokuWiki: Setting default admin user."
sed -i "/DokuWiki Administrator/c\\${DOKUWIKI_ADMIN_PASS_HASH}:DokuWiki Administrator:${APACHE2_SERVER_ADMIN}:admin,user" "/etc/dokuwiki/users.auth.php"

echo -e "DokuWiki: Launching indexer\n"
su -s /bin/sh www-data -c "php /usr/share/dokuwiki/bin/indexer.php -c"

cat <<-END
===================================================================

Running DokuWiki on $(hostname)

DokuWIki (/dokuwiki) default credentials: ${DOKUWIKI_ADMIN_USER}:${ISSET_DOKUWIKI_ADMIN_PASS:-$DOKUWIKI_ADMIN_PASS}

===================================================================
END

exec "$@"
