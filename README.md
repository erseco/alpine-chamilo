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

## Plugin development

Chamilo plugins can be mounted under `/var/www/html/public/plugin/`. The Nginx configuration forwards `PATH_INFO` for plugin PHP entry points, as required by the eXeLearning plugin. A development image may need Composer to regenerate Chamilo's autoloader and clear its cache after adding a plugin; this image does not install Composer or do that automatically. Plugin installation and upgrades have not yet been tested end to end with this image.

## Security limitations

During first installation, access must be restricted externally. The image blocks the installer by default; the local Compose example explicitly enables it for initial setup. The startup script permanently blocks installer URLs for that state volume after it detects an installed `.env` on a subsequent restart. Until then Chamilo's own installer gate applies; it can reopen when the database is unavailable. Immediately after installation restart the container, verify the installer returns 403, and remove `CHAMILO_INSTALLER_ENABLED` from the Compose file. This mechanism has been tested after recreating a completed installation; it does not close the installer immediately when installation completes. The healthcheck checks PHP-FPM and, after installation is detected at startup, the configured MariaDB connection. Reverse-proxy HTTPS and forwarded headers are not supported yet. The configuration directory is writable by the application during installation; hardening after installation is not yet implemented.

The upstream application is GPL-3.0-or-later; this repository's files are distributed under the same license. Chamilo is a trademark of its respective owner. This is not an official image.
