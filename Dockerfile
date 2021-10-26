# Build on Debian 11
FROM --platform=${TARGETPLATFORM:-linux/amd64} debian:bullseye-slim

RUN printf "Running on ${BUILDPLATFORM:-linux/amd64}, building for ${TARGETPLATFORM:-linux/amd64}\n$(uname -a).\n"

# Basic info
ARG NAME
ARG BUILD_DATE
ARG VERSION=20180422.a-2.1
ARG VCS_REF
ARG VCS_URL

LABEL maintainer="Marek Jaroš <jaros@ics.muni.cz>" \
	org.label-schema.build-date=$BUILD_DATE \
	org.label-schema.name=${NAME} \
	org.label-schema.description="DokuWiki" \
	org.label-schema.version=${VERSION} \
	org.label-schema.url="https://gitlab.ics.muni.cz/monitoring/dokuwiki" \
	org.label-schema.vcs-ref=${VCS_REF} \
	org.label-schema.vcs-url=${VCS_URL} \
	org.label-schema.vendor="UVT-MUNI" \
	org.label-schema.schema-version="1.0"

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en

# Install DokuWiki
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get upgrade -y -f --no-install-recommends -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" -o DPkg::options::="--force-confmiss" -o DPkg::options::="--force-unsafe-io" \
	&& apt-get install -y --no-install-recommends -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" -o DPkg::options::="--force-confmiss" -o DPkg::options::="--force-unsafe-io" \
		iputils-ping \
		locales \
		ca-certificates \
		curl \
		apache2 \
		libapache2-mod-php \
		php-fpm \
		dokuwiki \
		php-ldap \
		php-mbstring \
		tzdata \
		supervisor \
		shibboleth-sp-common \
		libapache2-mod-shib \
		python3-minimal \
	# Apache2 output
	&& sed -ri \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /dev/stdout!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /dev/stderr!g' \
		"/etc/apache2/apache2.conf" \
		"/etc/apache2/conf-available/other-vhosts-access-log.conf" \
		"/etc/apache2/sites-available/000-default.conf" \
	# FPM
	&& sed -ri \
		-e 's/error_log.*/error_log = \/dev\/stdout/g' \
		"/etc/php/7.4/fpm/php-fpm.conf" \
	# Locales
	&& sed -i -E 's/^#?\ ?en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure locales \
	# Configuration touch-up
	&& a2enmod http2 \
	&& a2dismod php7.4 \
	&& a2dismod mpm_prefork \
	&& a2enmod ssl \
	&& a2enmod mpm_event \
	&& a2enmod proxy_fcgi \
	&& a2enmod setenvif \
	&& usermod -aG tty www-data \
	&& chmod o+w /dev/std* \
	&& mv -n /etc/dokuwiki /etc/dokuwiki.dist \
	&& mv /etc/shibboleth /etc/shibboleth.dist \
	&& mv /var/lib/dokuwiki /var/lib/dokuwiki.dist \
	&& mkdir -p /run/shibboleth && chown _shibd /run/shibboleth \
	&& mkdir -p /run/php/ && chown www-data /run/php \
	# Cleanup
	&& apt-get -f -y autoremove \
	&& apt-get -y clean \
	&& rm -rf /var/lib/apt/lists/* /var/cache/*

COPY content/ /

EXPOSE 80 443

VOLUME [ "/var/lib/dokuwiki/", "/etc/dokuwiki", "/etc/shibboleth", "/var/lib/php/sessions", "/etc/apache2/ssl" ]

ENTRYPOINT [ "/opt/dokuwiki-entrypoint.sh" ]

HEALTHCHECK --interval=60s --timeout=10s --start-period=10s --retries=2 \
	CMD curl --fail http://127.0.0.1:80/dokuwiki/doku.php || exit 1

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n" ]
