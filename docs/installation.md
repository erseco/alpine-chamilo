# Installation

Both methods need an empty MariaDB database. The example `compose.yaml` creates one (`db`, database and user `chamilo`). Use a new, dedicated database: neither method is meant to touch existing data, and the unattended one refuses to.

Either way, you accept Chamilo's GPLv3 license.

## Unattended installation

Set in `.env`:

```sh
CHAMILO_AUTO_INSTALL=true
CHAMILO_URL=https://chamilo.example.org      # public origin, no path
CHAMILO_ADMIN_PASSWORD=...                   # at least 12 characters
CHAMILO_ADMIN_EMAIL=admin@example.org
DB_PASSWORD=...
```

On first start the container waits for the database (up to two minutes), then replays the fresh-install branch of Chamilo's web installer using the release's own functions: schema, migration baseline, fixtures, administrator, JWT keys and configuration files. That takes about a minute. The healthcheck only turns healthy after the installation has finished, because PHP-FPM starts afterwards.

The state file (`.env`) is written last and atomically. If any step fails, no installation is recorded and the container exits. On the next start the installer finds the partially created tables, refuses to continue and asks you to restore the matching state volume. It never drops or reinitialises a database. Recover by removing the failed stack's database and state volumes, then starting again.

Once installed, `CHAMILO_AUTO_INSTALL` has no effect, and the administrator password in the environment is no longer used. Change it in Chamilo and remove it from `.env`.

Other variables: `CHAMILO_LANGUAGE` (default `en_US`), `CHAMILO_ADMIN_USERNAME` (`admin`), `CHAMILO_ADMIN_FIRSTNAME`, `CHAMILO_ADMIN_LASTNAME`, `CHAMILO_SITE_NAME`, `CHAMILO_INSTITUTION`, `CHAMILO_INSTITUTION_URL`, `CHAMILO_MAILER_DSN` (default `null://null`, no mail), `CHAMILO_MAILER_FROM_EMAIL`, `CHAMILO_MAILER_FROM_NAME`, and `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` for an external database. Self-registration is disabled.

## Web installer

The wizard is unauthenticated: keep the port reachable only by you while it is open.

1. Set `CHAMILO_AUTO_INSTALL=false` and `CHAMILO_INSTALLER_ENABLED=true` and start the stack.
2. Open `/main/install/index.php` and use database host `db`, port `3306`, database and user `chamilo`, and `DB_PASSWORD`.
3. As soon as Chamilo writes `APP_INSTALLED=1`, a supervised guard creates a persistent marker in the state volume, and the installer URLs return 403 from then on, whatever `CHAMILO_INSTALLER_ENABLED` says. An interrupted installation also sets the marker; restore from backup or investigate instead of reinstalling over it.
4. Set `CHAMILO_INSTALLER_ENABLED=false`.

## After installation

Set `CHAMILO_STATE_MODE=ro` and `CHAMILO_CONFIG_MODE=ro` and run `docker compose up -d` to recreate the container with `.env`, the JWT keys and the configuration mounted read-only, as Chamilo's installation guide recommends. Login, courses, uploads and SCORM have been tested in that mode. Switch them back to `rw` only for deliberate maintenance.
