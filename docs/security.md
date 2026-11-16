# Security

## Image

- The Chamilo release archive is downloaded at build time and must match the SHA-256 published by upstream. It is used unchanged; only deployment files are added around it.
- The base image is pinned by its multi-architecture manifest digest.
- Nginx and PHP-FPM run as `nobody`. The application code, the startup scripts, the healthcheck and the installer are owned by root and are not writable at run time; `config/`, `var/` and `/data` are the writable volumes. The base image rewrites its Nginx and PHP configuration as `nobody` at every start, so those configuration directories remain writable by that user: after a suspected compromise, recreate the container (`docker compose up -d --force-recreate`) rather than restarting it.
- Nginx denies hidden files, `check.php`, `legacy.php`, PHP under static asset directories, and every root-level PHP script except `index.php`. It sends `X-Content-Type-Options: nosniff` and `X-Frame-Options: SAMEORIGIN`.
- Session cookies are HTTP-only, and they are `Secure` when the request arrives over HTTPS through a trusted proxy.
- No credentials are built in. The unattended installer requires an administrator password of at least 12 characters, and the example `.env` values must be replaced.
- Releases carry BuildKit provenance attestations.

## Installer

The web installer is unauthenticated. It is closed unless `CHAMILO_INSTALLER_ENABLED=true`. Once an installation is recorded, a persistent marker in the state volume blocks it permanently, even if the variable stays `true`, the database is down or the container is recreated. Keep the port private while the installer is open. The unattended installer never runs against a database that already contains tables.

After installation, mount state and configuration read-only (see [installation](installation.md#after-installation)).

## Reverse proxies

Forwarded headers are honoured only from the addresses in `CHAMILO_TRUSTED_PROXIES`. Nginx strips them for every other peer, and the same list is passed to Symfony. `tests/proxy.sh` checks forged headers, accepted proxy headers and invalid ranges. `tests/tls-proxy.sh` checks a real Nginx TLS proxy with certificate and hostname verification. Traefik and Cloudflare have not been tested.

## Vulnerability scanning

CI scans the Alpine packages of every build with Trivy (`--pkg-types os`, `/var/www/html` excluded). It reports all high and critical findings and fails on those with a fix available. The Chamilo release and its bundled PHP and JavaScript dependencies are deliberately outside this project's scanning and are not modified: report issues in them to [Chamilo](https://github.com/chamilo/chamilo-lms/security). For the same reason no SBOM of the application layer is attached.

## Reporting

Report vulnerabilities in this image's own files privately through [GitHub security advisories](https://github.com/erseco/alpine-chamilo/security/advisories/new).
