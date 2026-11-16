# alpine-chamilo (experimental)

This repository is developing an unofficial Chamilo LMS image based on Alpine, Nginx and PHP-FPM. **It is not ready for production or publication.** The only candidate release is Chamilo 3.0.2 with PHP 8.4; the web installation, login and basic persistence have been exercised locally. Upgrades and production security still require further validation.

## Local development

Copy `.env.example` to `.env` and replace both passwords with distinct random values. Then run:

```sh
docker compose build
docker compose up -d
```

The development listener binds to `127.0.0.1:8080`. The web installer uses database host `db`, port `3306`, database and user `chamilo`, and the password selected in `.env`. The database port is not exposed. Do not expose the installer to an untrusted network. The installer is not automated.

`chamilo-state` holds `.env` and JWT keys, `chamilo-var` holds application data, and `chamilo-db` holds MariaDB data. Back up all three together while the application and database are quiescent. Image version changes currently fail closed; upgrades and downgrades are unsupported. Do not delete volumes when recreating containers.

To test the candidate image, run `tests/smoke.sh`. This creates and removes its own disposable Compose project. For the browser installation and login test, run `npm ci --prefix tests/e2e`, install Playwright Chromium with `tests/e2e/node_modules/.bin/playwright install chromium`, and run `tests/install.sh`. These tests use disposable databases and volumes; they do not establish production readiness. See [research](docs/research.md) for upstream details and outstanding work.

## Upstream release monitoring

The scheduled release monitor checks paginated official GitHub release metadata for newer stable 3.x releases with an uploaded ZIP and SHA-256 digest. It resolves the tag to a commit and opens a reviewable compatibility PR; it never publishes or enables a new major version. The workflow can also be dispatched manually with a specific newer 3.x version. A candidate is not supported until its CI and manual compatibility review pass.

In repository Actions settings, allow GitHub Actions to create pull requests. The workflow uses `GITHUB_TOKEN`; bot-created PR workflows may require approval. It also explicitly dispatches the CI workflow on the candidate branch, because a token-created push does not trigger ordinary push workflows. A GitHub App token can be used if automatic PR-event runs are required without that approval.

## Security scanning

CI reports high and critical vulnerabilities in Alpine packages and fails on findings with an available fix. Findings without a fix remain visible in the report and require review. The scan explicitly excludes `/var/www/html` and does not scan or modify the Chamilo release or its bundled dependencies.

## Reverse proxy configuration

`CHAMILO_TRUSTED_PROXIES` is an optional comma-separated list of explicit proxy addresses or CIDR ranges, for example `172.20.0.2` or `172.20.0.0/24`. Leave it empty for direct access. Do not trust broad ranges that include untrusted clients. The proxy must replace or validate incoming `X-Forwarded-*` headers, and network policy must prevent clients from reaching the container through an address treated as trusted. Only root-path deployments have been considered; forwarded prefixes are discarded. See [security](docs/security.md) for current limitations.

## Plugin development

Chamilo plugins can be mounted under `/var/www/html/public/plugin/`. The Nginx configuration forwards `PATH_INFO` for plugin PHP entry points, as required by the eXeLearning plugin. A development image may need Composer to regenerate Chamilo's autoloader and clear its cache after adding a plugin; this image does not install Composer or do that automatically. Plugin installation and upgrades have not yet been tested end to end with this image.

## Security limitations

During first installation, access must be restricted externally. The image blocks the installer by default; the local Compose example explicitly enables it for initial setup. A supervised guard checks the persistent `.env` every second and permanently blocks installer URLs for that state volume once it sees `APP_INSTALLED=1`; the guard is also applied at startup. Keep the installer restricted to a trusted network throughout installation, verify that it returns 403 afterwards, and remove `CHAMILO_INSTALLER_ENABLED` from the Compose file. The marker may also be created during an interrupted installation; recover from a backup or investigate the incomplete installation before attempting recovery. The healthcheck checks PHP-FPM and, after installation is detected, the configured MariaDB connection. Set `CHAMILO_TRUSTED_PROXIES` to the exact proxy IPs or CIDR ranges visible to the container before enabling a reverse proxy. Forwarded headers from other peers are stripped. Simulated HTTPS and secure session cookies have been tested; a real TLS-terminating proxy has not yet been verified. The configuration directory is writable by the application during installation; hardening after installation is not yet implemented.

The upstream application is GPL-3.0-or-later; this repository's files are distributed under the same license. Chamilo is a trademark of its respective owner. This is not an official image.
