# alpine-chamilo

Unofficial container image for [Chamilo LMS](https://chamilo.org) 3.x on Alpine Linux, Nginx and PHP-FPM 8.3, built on [erseco/alpine-php-webserver](https://github.com/erseco/alpine-php-webserver). It runs as `nobody`, uses MariaDB and ships the official Chamilo release unchanged, verified by SHA-256.

**Documentation: https://erseco.github.io/alpine-chamilo/**

| | |
|---|---|
| Chamilo | 3.0.2 |
| Architectures | `linux/amd64`, `linux/arm64` |
| Images | `erseco/alpine-chamilo:3.0.2`, `ghcr.io/erseco/alpine-chamilo:3.0.2` |

Only exact version tags are published, with no `latest`. The image refuses to start on data created by a different Chamilo version until a tested upgrade procedure exists. Pin `3.0.2` (security rebuilds for the same Chamilo version) or a `3.0.2-rN` revision.

## Quick start

```sh
cp .env.example .env   # set passwords, CHAMILO_URL and the administrator
docker compose up -d --no-build
```

`CHAMILO_AUTO_INSTALL=true` installs Chamilo on first start (this accepts Chamilo's GPLv3 license). The container turns healthy once the installation has finished; then log in as `admin`. The official web installer is also supported. Afterwards, mount state and configuration read-only. See [installation](docs/installation.md).

Back up the four volumes together: see [operations](docs/operations.md). To add plugins, build a derived image: see [plugins](docs/plugins.md). For reverse proxies, set `CHAMILO_TRUSTED_PROXIES`: see [configuration](docs/configuration.md) and [security](docs/security.md).

## Tested

Real browser tests on every change cover the web installer, the unattended installer, administrator login, course creation, document upload and download, SCORM import and playback, persistence across recreation with read-only state, backup and restore, installer lockdown, database-failure health, trusted proxies and TLS, and a derived plugin image. Upgrades between Chamilo versions, Traefik and Cloudflare are not tested. See [development](docs/development.md).

Chamilo and this repository are GPL-3.0-or-later. Chamilo is a trademark of its owner; this is not an official image.
