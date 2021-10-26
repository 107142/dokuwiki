This repository contains source for the [Docker](https://www.docker.com/) image of the [DokuWiki](https://www.dokuwiki.org/).

**For production use `stable` tag or [version](https://gitlab.ics.muni.cz/monitoring/dokuwiki/container_registry/) specific tag.**

**You can also have a look at the [releases page](https://gitlab.ics.muni.cz/monitoring/dokuwiki/-/releases).**

Docker image: [registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable](registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable).

[[_TOC_]]

# DokuWiki Docker

## Image details

1.  Based on Debian Bullseye
2.  Key features:
    *  DokuWiki
    *  Apache2
    *  PHP-FPM
    *  Shibboleth
    *  Supervisor
    *  TLS support
    *  Custom CA support
3.  Without SSH. Use `docker exec` or `nsenter`

## Stability

This project is mainly designed for [Insitute of Computer Science](https://ics.muni.cz) of Masaryk university. It is tested and runs in a production environment. However since I lack sufficient resources to properly test every module and feature and prioritize those relevant to my needs it is possible some bugs may still be present.

## Development

This project is for the time being considered feature complete and I won't be implementing any additional features. I will however continue updating the image and fix any issues should they arise.

## Usage

This project assumes you have intermediate knowledge of Docker, networking, GNU/Linux and basic knowledge of DokuWiki. This documentation is by no means a step-by-step guide.

#### Quick start using docker run

Start of a new container on port 80 of the running host. 
```console
docker network create --ipv6 --driver=bridge --subnet=fd00:dead:beef::/48 wikinet
docker run -p 80:80 --net=wikinet -it registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable
```
Reachable at http://localhost/dokuwiki/ with credentials printed on screen during container start.

#### Docker-compose

Example configuration for [docker-compose](https://docs.docker.com/compose/) in `docker-compose.yml` file.  
```console
git clone --branch dokuwiki git@gitlab.ics.muni.cz:/monitoring/dokuwiki.git
docker-compose up
```
Reachable at http://localhost/dokuwiki/ with credentials printed on screen during container start.

#### Configuration

Configuration can be found in `/etc/dokuwiki`. Data is saved inside `/lib/share/dokuwiki`. For persistent configuration directories have to be mounted as volumes.

For IPv6 conenctivity you can either use Docker NAT with [ip6tables](https://docs.docker.com/engine/reference/commandline/dockerd/) or need to define correct subnet and use [NDP](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol).


# Podpora TLS

To enable TLS, mount directory containing the certificates to `/etc/apache2/ssl`. Certificates must have the following names:
 * `dokuwiki.crt`: Certificate chain (or single certificate) for Apache
 * `dokuwiki.key`: Private key

To set HTTPS redirection or HTTP/HTTPS dual-stack consult `APACHE2_HTTP` variable in [Reference](README.md#reference) section.


# Custom CA support

In case you want to use self-signed certificates or add other CA, add their respective certificate as `.crt` files in a directory mounted on `/usr/local/share/ca-certificates` inside the container.

Any CA's with `.crt` extension in this volume will be automatically added to the CA store at startup.


# PHP-FPM

PHP-FPM daemon is part of the container. It is used automatically.

## Saving PHP sessions

In case you want to save PHP sessions mount a volume `/var/lib/php/sessions/` inside the container. Session files are saved there.

Example:
```console
docker run [...] -v $PWD/dokuwiki-sessions:/var/lib/php/sessions/ registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable
```


# Shibboleth

To enable Shibboleth daemon set `APACHE2_SHIBBOLETH` environment variable to **1**.

Configuration is found in `/etc/shibboleth`.


# Reference

## Environment variables

| Variable | Default value | Description |
| ---------------------- | ------------- | ----------- |
| `APACHE2_HTTP` | `REDIRECT` | **Variable is used only if both certificates are present.** `BOTH`: Allow HTTP and HTTPS connections. `REDIRECT`: Rewrite HTTP requests to HTTPS |
| `APACHE2_CSP` | *unset* | Content security policy for DokuWiki |
| `APACHE2_SERVER_NAME` | *dokuwiki* | Sets `ServerName` for Apache2 |
| `APACHE2_SERVER_ALIAS` | *wiki* | Sets `ServerAlias` for Apache2 |
| `APACHE2_SERVER_ADMIN` | *webmaster@localhost* | Sets `ServerAdmin` for Apache2 |
| `APACHE2_SHIBBOLETH` | 0 | Enable Shibboleth |
| `TZ` | UTC | Set container timezone |
| `DOKUWIKI_ADMIN_USER` | admin | Superuser name |
| `DOKUWIKI_ADMIN_PASS` | *random* | Superuser password |
| `DOKUWIKI_LOCALES` | en_US.UTF-8 UTF-8 | List of locales to be generated. Docker-compose example:<br>DOKUWIKI_LOCALES:<br>  - cs_CZ.UTF-8 UTF-8<br />  - en_US.UTF-8 UTF-8 |
| `DOKUWIKI_DEFAULT_LOCALE` | en_US.UTF-8 | Default locale to use |
| `DOKUWIKI_LANG` | en_US.UTF-8 | Default language to use |
| `PHP_FPM_OPCACHE_ENABLE` | 1 | Use FPM opcache |
| `PHP_FPM_OPCACHE_ENABLE_CLI` | 0 | Allow CLI for FPM opcache |
| `PHP_FPM_OPCACHE_FAST_SHUTDOWN` | 1 | Allow "fast_shutdown" for FPM opcache |
| `PHP_FPM_OPCACHE_MEMORY_CONSUMPTION` | 256M | Memory for FPM opcache |
| `PHP_FPM_OPCACHE_STRINGS_BUFFER` | 16 | String buffer for FPM opcache |
| `PHP_FPM_OPCACHE_MAX_ACCELERATED` | 10000 | Maximum accelerated files for FPM opcache |
| `PHP_FPM_OPCACHE_REVALIDATE_FREQ:-60` | 60 | Revalidation frequency for FPM opcache |
| `PHP_FPM_MAX_POST` | 16M | Maximum POST size |
| `PHP_FPM_MAX_UPLOAD` | 16M | Maximum file size for upload |
| `PHP_FPM_MAX_EXECUTION_TIME` | 10800 | Maximum execution time for FPM |
| `PHP_FPM_MAX_INPUT_TIME` | 3600 | Maximum time to wait for input |
| `PHP_FPM_EXPOSE` | Off | Expose addtiona information about FPM to the world |
| `PHP_FPM_MEMORY_LIMIT` | 256M | Memory limit for FPM |
| `PHP_FPM_PM` | dynamic | Type of process spawning |
| `PHP_FPM_PM_MIN` | 2 | Minimum FPM processes |
| `TPHP_FPM_PM_MAX` | 6 | Maximum FPM processes |
| `PHP_FPM_PM_IDLE` | 30 | FPM process idle time limit |
| `PHP_FPM_PM_CHILDREN` | 6 | Maximum children for FPM processes |
| `PHP_FPM_PM_REQUESTS` | 100000 | Maximum requests for FPM process before the process is restarted |

## Volumes

| Volume | ro/rw | Description |
| ------ | ----- | ------------------- |
| /etc/apache2/ssl | **ro** | Mounted TLS certificates |
| /etc/dokuwiki | rw | Configuration |
| /etc/shibboleth | rw | Shibboleth configuration |
| /var/lib/dokuwiki | rw | Dokuwiki data |
| /var/lib/php/sessions/ | rw | PHP sessions |


# Credits

Created by Marek Jaroš at Institute of Computer Science of Masaryk Univerzity.


# Licence

[GPL](LICENSE)
