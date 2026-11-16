# Configuration

## Container environment

| Variable | Default | Meaning |
|---|---|---|
| `CHAMILO_AUTO_INSTALL` | `false` | `true` installs Chamilo on first start; see [installation](installation.md#unattended-installation). |
| `CHAMILO_INSTALLER_ENABLED` | `false` | `true` opens the web installer until an installation is recorded. |
| `CHAMILO_TRUSTED_PROXIES` | empty | Comma-separated IPs or CIDR ranges of reverse proxies whose `X-Forwarded-*` headers are trusted. Headers from any other peer are discarded. `0.0.0.0/0` and `/0` ranges are rejected. |
| `upload_max_filesize`, `post_max_size`, `client_max_body_size` | `256M` | PHP and Nginx upload limits, from the base image. Raise all three together. |
| `memory_limit` | `512M` | PHP memory limit. |
| `max_execution_time` | base image default | PHP time limit. |

The base image's other variables (`opcache_enable`, PHP-FPM process settings and so on) also apply; see [alpine-php-webserver](https://github.com/erseco/alpine-php-webserver).

## Compose example variables

`compose.yaml` additionally reads `CHAMILO_IMAGE`, `CHAMILO_PORT` (published on `127.0.0.1` only), `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `CHAMILO_STATE_MODE` and `CHAMILO_CONFIG_MODE` (`rw` or `ro`). It passes the unattended-installation variables from [installation](installation.md#unattended-installation) to the container.

The example database is MariaDB 12.3 LTS with `MARIADB_AUTO_UPGRADE=1`. A data directory from an older MariaDB is upgraded on start; an 11.4 volume with a full installation was upgraded this way and kept its courses, documents and SCORM tracking. Back up before changing the database version, because a data directory cannot go back to an older MariaDB.

## Reverse proxy

Terminate TLS in the proxy and forward to port 8080. Set `CHAMILO_TRUSTED_PROXIES` to the address the container sees for the proxy (with Compose, usually its address on the shared network). The proxy must overwrite, not append to, `X-Forwarded-For`, `-Host`, `-Port` and `-Proto`, and nothing else may reach the container from a trusted address. Chamilo must be served at the root of its host: forwarded path prefixes are ignored.

A minimal Nginx proxy, as exercised by `tests/tls-proxy.sh`:

```nginx
location / {
    proxy_pass http://chamilo:8080;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-Port 443;
    proxy_set_header X-Forwarded-Proto https;
    client_max_body_size 256m;
}
```
