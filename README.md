# alpine-chamilo (experimental)

This repository is developing an unofficial Chamilo LMS image based on Alpine, Nginx and PHP-FPM. **It is not ready for production or publication.** The only candidate release is Chamilo 3.0.2 with PHP 8.4; installation, upgrades, persistence and security still require end-to-end validation.

## Local development

Copy `.env.example` to `.env` and replace both passwords with distinct random values. Then run:

```sh
docker compose build
docker compose up -d
```

The development listener binds to `127.0.0.1:8080`. The web installer uses database host `db`, port `3306`, database and user `chamilo`, and the password selected in `.env`. The database port is not exposed. Do not expose the installer to an untrusted network. The installer is not automated.

`chamilo-state` holds `.env` and JWT keys, `chamilo-var` holds application data, and `chamilo-db` holds MariaDB data. Back up all three together while the application and database are quiescent. Image version changes currently fail closed; upgrades and downgrades are unsupported. Do not delete volumes when recreating containers.

To test the candidate image, run `tests/smoke.sh`. This creates and removes its own disposable Compose project. It does not perform an installation or validate production readiness. See [research](docs/research.md) for verified upstream details and outstanding work.

## Security limitations

During first installation, access must be restricted externally. The image blocks the installer by default; the local Compose example explicitly enables it for initial setup. The startup script permanently blocks installer URLs for that state volume after it detects an installed `.env` on a subsequent restart. Until then Chamilo's own installer gate applies; it can reopen when the database is unavailable. Immediately after installation restart the container, verify the installer returns 403, and remove `CHAMILO_INSTALLER_ENABLED` from the Compose file. This mechanism has not yet been tested with a completed installation. The inherited healthcheck checks PHP-FPM, not application or database readiness. Reverse-proxy HTTPS and forwarded headers are not supported yet. The configuration directory is writable by the application during installation; hardening after installation is not yet implemented.

The upstream application is GPL-3.0-or-later; this repository's files are distributed under the same license. Chamilo is a trademark of its respective owner. This is not an official image.
