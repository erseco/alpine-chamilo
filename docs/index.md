# Alpine Chamilo

This is an **experimental, unofficial** Chamilo LMS image using Alpine Linux, Nginx and PHP-FPM. It is not ready for production or publication. Chamilo 3.0.2 on PHP 8.4 is the only candidate currently tested; earlier major releases are excluded. No registry image or stable release is available yet.

## Local evaluation

Clone the repository, copy `.env.example` to `.env`, set distinct random database passwords, and run:

```sh
docker compose build
docker compose up -d
```

Open `http://127.0.0.1:8080/` and complete the official web installer. Use `db` as database host, port `3306`, `chamilo` as database and username, and the database password from `.env`. Choose your own administrator credentials. The installer can replace tables in its selected database; use a new, dedicated database. Restrict access to the installer to trusted users.

A guard closes installer endpoints once Chamilo writes `APP_INSTALLED=1`. Check that `/main/install/index.php` returns 403 after installation then set `CHAMILO_INSTALLER_ENABLED=false`, `CHAMILO_STATE_MODE=ro`, and `CHAMILO_CONFIG_MODE=ro` in `.env` and run `docker compose up -d` to recreate the container with configuration and state mounted read-only. An interrupted installation can also create the guard marker; investigate before attempting recovery.

The Compose stack binds HTTP to localhost and does not publish MariaDB. A trusted proxy can be configured with `CHAMILO_TRUSTED_PROXIES`, but actual TLS termination has not yet been verified. Redis, automatic installation, automatic upgrades and scheduled tasks are not implemented.

## Persistence and upgrades

The `chamilo-state` volume stores `.env` and JWT keys, `chamilo-config` stores release-specific configuration, `chamilo-var` stores application data including uploaded assets and plugins, and `chamilo-db` stores the database. Back up all four consistently while the application and database are quiescent. Restore all four together with the same image version. Practice restore before relying on any backup.

The image refuses to start if the stored image version differs from its own. Upgrades, downgrades, rollback across versions and custom-plugin upgrades are not yet supported or tested. Never remove named volumes as part of an ordinary container restart.

See [development and testing](development.md), [security limitations](security.md), and the [historical investigation](research.md). The [repository](https://github.com/erseco/alpine-chamilo) contains the Compose example and current code.
