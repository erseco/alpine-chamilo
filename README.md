# alpine-chamilo

[![CI](https://github.com/erseco/alpine-chamilo/actions/workflows/ci.yml/badge.svg)](https://github.com/erseco/alpine-chamilo/actions/workflows/ci.yml)
[![Release](https://github.com/erseco/alpine-chamilo/actions/workflows/release.yml/badge.svg)](https://github.com/erseco/alpine-chamilo/actions/workflows/release.yml)
[![Docker Hub version](https://img.shields.io/docker/v/erseco/alpine-chamilo?sort=semver&label=Docker%20Hub)](https://hub.docker.com/r/erseco/alpine-chamilo)
[![Docker pulls](https://img.shields.io/docker/pulls/erseco/alpine-chamilo)](https://hub.docker.com/r/erseco/alpine-chamilo)
[![Image size](https://img.shields.io/docker/image-size/erseco/alpine-chamilo/3.0.2?label=size)](https://hub.docker.com/r/erseco/alpine-chamilo/tags)
[![GHCR](https://img.shields.io/badge/ghcr.io-erseco%2Falpine--chamilo-blue?logo=github)](https://github.com/erseco/alpine-chamilo/pkgs/container/alpine-chamilo)
[![Docs](https://img.shields.io/badge/docs-erseco.github.io-blue)](https://erseco.github.io/alpine-chamilo/)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-green)](https://github.com/erseco/alpine-chamilo/blob/main/LICENSE)

Unofficial container image for [Chamilo LMS](https://chamilo.org) 3.x on Alpine Linux, Nginx and PHP-FPM 8.3, built on [erseco/alpine-php-webserver](https://github.com/erseco/alpine-php-webserver). It runs as `nobody`, uses MariaDB and ships the official Chamilo release unchanged, verified by SHA-256.

| Where | Link |
|---|---|
| Source and issues | [github.com/erseco/alpine-chamilo](https://github.com/erseco/alpine-chamilo) |
| Docker Hub | [hub.docker.com/r/erseco/alpine-chamilo](https://hub.docker.com/r/erseco/alpine-chamilo) |
| GitHub Container Registry | [ghcr.io/erseco/alpine-chamilo](https://github.com/erseco/alpine-chamilo/pkgs/container/alpine-chamilo) |
| Documentation | [erseco.github.io/alpine-chamilo](https://erseco.github.io/alpine-chamilo/) |

| | |
|---|---|
| Chamilo | 3.0.2 |
| Architectures | `linux/amd64`, `linux/arm64` |
| Images | [`erseco/alpine-chamilo:3.0.2`](https://hub.docker.com/r/erseco/alpine-chamilo/tags), [`ghcr.io/erseco/alpine-chamilo:3.0.2`](https://github.com/erseco/alpine-chamilo/pkgs/container/alpine-chamilo) |

Tags: `3.0.2`, `3.0`, `3` and `latest`. `3.0.2` is rebuilt in place for base-image and Alpine updates and never changes Chamilo version. **Use `3.0.2` in production:** the image refuses to start on data created by a different Chamilo version until a tested upgrade procedure exists, so `3.0`, `3` and `latest` will stop at the next Chamilo release.

## Quick start

```sh
cp .env.example .env   # set passwords, CHAMILO_URL and the administrator
docker compose up -d --no-build
```

`CHAMILO_AUTO_INSTALL=true` installs Chamilo on first start (this accepts Chamilo's GPLv3 license). The container turns healthy once the installation has finished; then log in as `admin`. The official web installer is also supported. Afterwards, mount state and configuration read-only. See [installation](docs/installation.md).

Back up the four volumes together: see [operations](docs/operations.md). To add plugins, build a derived image: see [plugins](docs/plugins.md). For reverse proxies, set `CHAMILO_TRUSTED_PROXIES`: see [configuration](docs/configuration.md) and [security](docs/security.md).

## Configuration

With the example `compose.yaml`, set the `CHAMILO_*` and `DB_PASSWORD` variables in `.env`; add the PHP limits to the service's `environment`. Full reference: [configuration](docs/configuration.md) and [installation](docs/installation.md).

| Variable | Default | Description |
|---|---|---|
| `CHAMILO_AUTO_INSTALL` | `false` | `true` installs Chamilo on first start (accepts the GPLv3 license). Needs the four variables below. |
| `CHAMILO_URL` | | Public origin, for example `https://chamilo.example.org`. Required for the unattended installation. |
| `CHAMILO_ADMIN_PASSWORD` | | Administrator password, at least 12 characters. Only read during the installation. |
| `CHAMILO_ADMIN_EMAIL` | | Administrator email, also the default sender. |
| `DB_PASSWORD` | | Database password. In `compose.yaml` it also creates the MariaDB user. |
| `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` | `db` / `3306` / `chamilo` / `chamilo` | Database connection for the unattended installation. |
| `CHAMILO_LANGUAGE` | `en_US` | Platform and administrator language. |
| `CHAMILO_ADMIN_USERNAME` | `admin` | Administrator login. |
| `CHAMILO_ADMIN_FIRSTNAME` / `CHAMILO_ADMIN_LASTNAME` | `Chamilo` / `Administrator` | Administrator name. |
| `CHAMILO_SITE_NAME` | `Chamilo` | Site name. |
| `CHAMILO_INSTITUTION` / `CHAMILO_INSTITUTION_URL` | `Chamilo` / `CHAMILO_URL` | Organisation shown in the header. |
| `CHAMILO_MAILER_DSN` | `null://null` | Symfony Mailer DSN, for example `smtp://user:pass@smtp.example.org:587`. The default sends no mail. |
| `CHAMILO_MAILER_FROM_EMAIL` / `CHAMILO_MAILER_FROM_NAME` | admin email / `Chamilo` | Sender of outgoing mail. |
| `CHAMILO_INSTALLER_ENABLED` | `false` | `true` opens the web installer until an installation is recorded. |
| `CHAMILO_TRUSTED_PROXIES` | | Comma-separated IPs or CIDR ranges of reverse proxies whose `X-Forwarded-*` headers are trusted. |
| `upload_max_filesize` / `post_max_size` / `client_max_body_size` | `256M` | PHP and Nginx upload limits; raise all three together. |
| `memory_limit` | `512M` | PHP memory limit. |

`compose.yaml` also reads `CHAMILO_IMAGE`, `CHAMILO_PORT` (published on `127.0.0.1`), `DB_ROOT_PASSWORD`, and `CHAMILO_STATE_MODE` / `CHAMILO_CONFIG_MODE` (`rw`, or `ro` after installation). The example database is MariaDB 12.3 LTS with `MARIADB_AUTO_UPGRADE=1`, so a data directory from an older MariaDB is upgraded on start. Back up before changing the database version.

## Tested

Real browser tests on every change cover the web installer, the unattended installer, administrator login, course creation, document upload and download, SCORM import and playback, persistence across recreation with read-only state, backup and restore, installer lockdown, database-failure health, trusted proxies and TLS, and a derived plugin image. Upgrades between Chamilo versions, Traefik and Cloudflare are not tested. See [development](docs/development.md).

Chamilo and this repository are GPL-3.0-or-later. Chamilo is a trademark of its owner; this is not an official image.
