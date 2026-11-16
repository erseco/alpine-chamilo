# Alpine Chamilo

An **unofficial** container image for [Chamilo LMS](https://chamilo.org) 3.x on Alpine Linux, Nginx and PHP-FPM 8.3, built on [erseco/alpine-php-webserver](https://github.com/erseco/alpine-php-webserver). It runs as `nobody`, uses MariaDB, and ships the official Chamilo release archive unchanged, verified by SHA-256.

| | |
|---|---|
| Chamilo | 3.0.2 |
| PHP | 8.3 |
| Architectures | `linux/amd64`, `linux/arm64` |
| Registries | [Docker Hub `erseco/alpine-chamilo`](https://hub.docker.com/r/erseco/alpine-chamilo), [GHCR `ghcr.io/erseco/alpine-chamilo`](https://github.com/erseco/alpine-chamilo/pkgs/container/alpine-chamilo) |
| Tags | exact versions only: `3.0.2`, and `3.0.2-rN` for image revisions of the same Chamilo version |

There is deliberately no `latest`, `3` or `3.0` tag: the image refuses to start on a volume created by another Chamilo version (see [operations](operations.md#versions-and-upgrades)), so a floating tag would stop your site after an upstream release.

## Quick start

```sh
git clone https://github.com/erseco/alpine-chamilo.git
cd alpine-chamilo
cp .env.example .env   # set distinct random passwords, the URL and the administrator
docker compose up -d --no-build
```

With `CHAMILO_AUTO_INSTALL=true` the container installs Chamilo on first start and becomes healthy when it is ready; log in at `CHAMILO_URL` as `admin` with `CHAMILO_ADMIN_PASSWORD`. Alternatively use Chamilo's own [web installer](installation.md#web-installer).

The example stack binds HTTP to `127.0.0.1:8080` and does not publish MariaDB. Put a TLS-terminating reverse proxy in front for real use and set [`CHAMILO_TRUSTED_PROXIES`](configuration.md).

## What has been tested

On every change, CI (amd64) and local runs (arm64) cover: image contents and routing, the real web installer in a browser, the unattended installer, administrator login, course creation, document upload and download, SCORM 1.2 import and playback (including the SCORM API), restart and container recreation with read-only state, cold backup and restore into a new stack, installer lockdown, database-failure healthcheck, trusted-proxy header filtering, a real Nginx TLS proxy, and a derived image that adds a plugin. The eXeLearning plugin was also exercised end to end on a derived image.

Not tested: upgrades between Chamilo versions (blocked on purpose), Traefik or Cloudflare, Redis, scheduled tasks, LDAP, mail delivery, PostgreSQL.

## More

- [Installation](installation.md)
- [Configuration](configuration.md)
- [Operations: volumes, backup, versions](operations.md)
- [Plugins](plugins.md)
- [Security](security.md)
- [Development and testing](development.md)
- [Historical research notes](research.md)

Chamilo is GPL-3.0-or-later, and so is this repository. Chamilo is a trademark of its owner; this image is not official.
