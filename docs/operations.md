# Operations

## Volumes

| Volume | Mount | Contents | Mode after installation |
|---|---|---|---|
| `chamilo-state` | `/data` | `.env` (database credentials, secrets), JWT keys, installation marker, image version | `ro` |
| `chamilo-config` | `/var/www/html/config` | release configuration plus files the installer adds | `ro` |
| `chamilo-var` | `/var/www/html/var` | uploaded documents, SCORM packages, themes, plugin storage, logs | `rw` |
| `chamilo-db` | MariaDB data | the database | `rw` |

The code under `/var/www/html` comes from the image and is not a volume. The compiled Symfony cache in `var/cache` is emptied at every start, so a new image (for example one with an added plugin) never runs on another image's cache. The first request after a start rebuilds it, which takes a few seconds.

Protect all four volumes and their backups: they contain credentials and personal data.

## Backup and restore

Back up the four volumes together while the stack is stopped. This is the procedure that `tests/backup-restore.sh` runs on every change:

```sh
docker compose stop
for v in chamilo-state chamilo-config chamilo-var chamilo-db; do
  docker run --rm -v "alpine-chamilo_$v:/source:ro" -v "$PWD/backup:/backup" \
    alpine tar -C /source -czf "/backup/$v.tar.gz" .
done
docker compose start
```

Replace `alpine-chamilo_` with your Compose project name. To restore, create empty volumes for a new project, extract each archive into its volume, and start that project with **the same image tag**. Then check that `/main/install/index.php` answers 403 and that a course's documents open. Try a restore before you rely on a backup.

`mariadb-dump` of the database alone is not enough: `.env`, the JWT keys and the uploaded files must match it.

## Versions and upgrades

The first start records the image's Chamilo version in the state volume. If a later start finds a different version, the container prints

```
Chamilo version changed from 3.0.2 to 3.0.3; upgrades and downgrades are not yet supported.
```

and exits without touching anything. Go back to the previous tag and your site works as before. This is deliberate. A Chamilo upgrade runs database migrations and can change the configuration files kept in `chamilo-config`. That has no tested, reversible procedure in this image yet, and an image swap must not run it silently.

### Tags

- `3.0.2`: Chamilo 3.0.2. It is rebuilt in place when only the base image or Alpine packages change, never with another Chamilo version.
- `3.0`, `3` and `latest`: the newest Chamilo release in that range.

**Use `3.0.2` in production.** On `3.0`, `3` or `latest`, the next Chamilo release changes the version under your volumes, and the container stops with the message above until an upgrade procedure exists. Your data is untouched; pin `3.0.2` again to start. For fully reproducible deployments, pin the digest shown in the release summary. Each release copies the same multi-architecture manifest to both registries, and the release workflow checks that the digests match.

## Health and logs

The healthcheck pings PHP-FPM and, once Chamilo is installed, opens a MariaDB connection with the installed credentials. It is not a full application check. Nginx and PHP log to the container output (`docker compose logs chamilo`), and Chamilo writes its own log to `var/log`.

## Not provided

Scheduled tasks (Chamilo cron), Redis sessions, outgoing mail configuration beyond `CHAMILO_MAILER_DSN`, and PostgreSQL support are not provided.
