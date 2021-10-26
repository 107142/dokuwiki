Tento repositář obsahuje zdroj pro [Docker](https://www.docker.com/) obraz [DokuWiki](https://www.dokuwiki.org/).

**Pro produkci použijte tag `stable` nebo konkrétní [verzi](https://gitlab.ics.muni.cz/monitoring/dokuwiki/container_registry/).**

**Můžete se také podívat na stránku [vydaných verzí](https://gitlab.ics.muni.cz/monitoring/dokuwiki/-/releases).**

Docker image: [registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable](registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable).

[[_TOC_]]

# DokuWiki Docker

## Vlastnosti obrazu

1.  Postaven nad Debian Bullseye
2.  Klíčové vlastnosti:
    *  dokuwiki
    *  php-fpm
    *  Shibboleth
    *  Supervisor
    *  TLS podpora
    *  Podpora vlastních CA
3.  Bez SSH. Použijte `docker exec` nebo `nsenter`
4.  Pokud nejsou nastavena hesla budou náhodně vygenerována a ukázána na standardním výstupu

## Stabilita

Tento projekt je primárně vyvíjen pro potřeby [Ústavu výpočení techniky](https://ics.muni.cz) Masarykovy univerzity. Je testován a beží v produkčním prostředí. Nicméně z důvodu limitovaných zdrojů nutných pro otestování každého modulu a funkce a prioritizace funkčností relevantních pro mě je možné že nějaké chyby jsou přitomny.

## Vývoj

Tento projekt je prozatím považován za funkčně kompletní a nebudu implementovat žádné nové funkce. Nicméně budu aktualizovat obraz a opravovat chyby pokud nastanou.

## Použití

Tento projekt předpokládá že máte pokročilé znalosti Dockeru, siťování, GNU/Linux a základní znalosti DokuWiki. Tato dokumentace rozhodně neslouží jako kompletní návod bod-po-bodu.

#### Rychlý start pomocí docker run

Nastartování nového kontejneru na portu 80 hosta:  
```console
docker network create --ipv6 --driver=bridge --subnet=fd00:dead:beef::/48 wikinet
docker run -p 80:80 --net=wikinet -it registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable
```
Dosažitelné na http://localhost/dokuwiki/ s přihlašovacími údaji zobrazenými při startu kontejneru.

#### Docker-compose

Vzorová konfigurace pro [docker-compose](https://docs.docker.com/compose/) v `docker-compose.yml` souboru.  
```console
git clone --branch dokuwiki git@gitlab.ics.muni.cz:/monitoring/dokuwiki.git
docker-compose up
```
Dosažitelné na http://localhost/dokuwiki/ s přihlašovacími údaji zobrazenými při startu kontejneru.

#### Konfigurace

Konfigurace se nachází v `/etc/dokuwiki`. Data se ukládají do `/lib/share/dokuwiki`. Pro persistentní konfiguraci je dobré mít adresáře namontované jako svazky.

Pro IPv6 je možné použít Docker NAT s nastavením [ip6tables](https://docs.docker.com/engine/reference/commandline/dockerd/) nebo mít nadefinován správný subnet a použít [NDP](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol).


# Podpora TLS

Pro zapnutí TLS, namontujte svazek `/etc/apache2/ssl` obsahujíci tyto soubory:
*  `dokuwiki.crt`: Certifikát pro Apache
*  `dokuwiki.key`: Korespondující privátní klíč
*  `dokuwiki.chain` (volitelné): Certifikační řetězec

Pro HTTPS redirekci nebo HTTP/HTTPS dual-stack konsultujte `APACHE2_HTTP` proměnnou prostředí.


# Podpora vlastní CA

V případě potřeby použití vlastní či jiné certifikační authority, přidejte certifikáty jako `.crt` soubory do svazku namontovaném na `/usr/local/share/ca-certificates` .

Jakékoliv certifikační authority s příponou `.crt` v tomto svazku budou automaticky přidány do CA úložiště.


# PHP-FPM

Součástí kontejneru je php-fpm daemon. Jeho použití je automatické.

## Ukládání PHP relací

Pokud je třeba uložit PHP relace stačí namontovat svazek `/var/lib/php/sessions/` do kontejneru. Relační soubory budou uložneny v něm.

Příklad:  
```console
docker run [...] -v $PWD/dokuwiki-sessions:/var/lib/php/sessions/ registry.gitlab.ics.muni.cz:443/monitoring/dokuwiki:stable


# Shibboleth

Pro zapnutí Shibbolethu nastavte proměnnou `APACHE2_SHIBBOLETH` na hodnotu **1**.  
Konfigurace se nachází v `/etc/shibboleth`.


# Reference

## Seznam proměnných prostředí

| Proměnná prostředí | Výchozí hodnota | Popis |
| ---------------------- | ------------- | ----------- |
| `APACHE2_HTTP` | `REDIRECT` | **Proměnná je aktivní pouze pokud oba certifikáty jsou přitomny.** `BOTH`: Povol HTTP a HTTPS spojení.  REDIRECT`: Přepiš HTTP-požadavky na HTTPS |
| `APACHE2_CSP` | *nenastaveno* | Content security policy pro DokuWiki |
| `APACHE2_SERVER_NAME` | *dokuwiki* | Globálně nastaví `ServerName` pro Apache2 na danou hodnotu |
| `APACHE2_SERVER_ALIAS` | *wiki* | Globálně nastaví `ServerAlias` pro Apache2 na danou hodnotu |
| `APACHE2_SERVER_ADMIN` | *webmaster@localhost* | Globálně nastaví `ServerAdmin` pro Apache2 na danou hodnotu |
| `APACHE2_SHIBBOLETH` | 0 | Zapni Shibboleth |
| `TZ` | UTC | Nastav časové pásmo které má kontejner použít |
| `DOKUWIKI_ADMIN_USER` | admin | Jméno superuživatele |
| `DOKUWIKI_ADMIN_PASS` | *náhodně generováno* | Heslo superuživatele |
| `DOKUWIKI_LOCALES` | en_US.UTF-8 UTF-8 | List lokalit které mají být vygenerovány. Například v docker-compose:<br />DOKUWIKI_LOCALES:<br />  - cs_CZ.UTF-8 UTF-8<br />  - en_US.UTF-8 UTF-8 |
| `DOKUWIKI_DEFAULT_LOCALE` | en_US.UTF-8 | Výchozí lokalita co bude použita |
| `DOKUWIKI_LANG` | en_US.UTF-8 | Výchozí nastavení jazyka |
| `PHP_FPM_OPCACHE_ENABLE` | 1 | Použij FPM opcache |
| `PHP_FPM_OPCACHE_ENABLE_CLI` | 0 | Povol CLI pro FPM opcache |
| `PHP_FPM_OPCACHE_FAST_SHUTDOWN` | 1 | Povol "fast_shutdown" pro FPM opcache |
| `PHP_FPM_OPCACHE_MEMORY_CONSUMPTION` | 256M | Spotřeba paměti pro FPM opcache |
| `PHP_FPM_OPCACHE_STRINGS_BUFFER` | 16 | Mezipamět pro řtězce FPM opcache |
| `PHP_FPM_OPCACHE_MAX_ACCELERATED` | 10000 | Množství urychlených souborů pro FPM opcache |
| `PHP_FPM_OPCACHE_REVALIDATE_FREQ:-60` | 60 | Frekvence revalica FPM opcache |
| `PHP_FPM_MAX_POST` | 16M | Maximální velikost POST |
| `PHP_FPM_MAX_UPLOAD` | 16M | Maximální veikost pro nahrání souboru |
| `PHP_FPM_MAX_EXECUTION_TIME` | 10800 | Maximální délka trvání činnosti FPM |
| `PHP_FPM_MAX_INPUT_TIME` | 3600 | Maximání čas pro vstup |
| `PHP_FPM_EXPOSE` | Off | Zobraz další informace o PHP verzi světu |
| `PHP_FPM_MEMORY_LIMIT` | 256M | Limit paměti pro FPM |
| `PHP_FPM_PM` | dynamic | Typ vytváření nových procesů FPM |
| `PHP_FPM_PM_MIN` | 2 | Minimum spuštených procesů FPM |
| `TPHP_FPM_PM_MAX` | 6 | Maximum spuštěných procesů FPM |
| `PHP_FPM_PM_IDLE` | 30 | Limit pro nečinnost procesu |
| `PHP_FPM_PM_CHILDREN` | 6 | Maximální počet dětí FPM |
| `PHP_FPM_PM_REQUESTS` | 50000 | Maximum požadavků na proces před jeho restartem |

## Reference ke svazkům

| Svazek | ro/rw | Popis & použití |
| ------ | ----- | ------------------- |
| /etc/apache2/ssl | **ro** | Namontování TLS certifikátů (viz. Podpora TLS) |
| /etc/dokuwiki | rw | Konfigurace dokuwiki |
| /etc/shibboleth | rw | Shibboleth konfigurace |
| /var/lib/dokuwiki | rw | Data Dokuwiki |
| /var/lib/php/sessions/ | rw | PHP relační soubory |


# Credits

Vytvořil Marek Jaroš pro Ústav výpočetní techniky Masarykovy univerzity.


# Licence

[GPL](LICENSE)
