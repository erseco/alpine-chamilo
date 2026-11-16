# Security and current limitations

Do not deploy this experimental image in production. The first-install web wizard is unauthenticated and must be reachable only by trusted administrators. The image disables the wizard by default; the local Compose example enables it for installation and binds the port to localhost. A persistent marker blocks installer routes when an installation starts writing its configuration, including if MariaDB is unavailable or the container is recreated. An interrupted installation can require manual recovery.

The installer requires write access to `.env`, `config/` and `var/`. The image does not yet implement a verified transition that makes application configuration immutable after installation. Restrict access to all volumes and protect backups: configuration and keys contain secrets. PHP session cookies are configured as HTTP-only. The healthcheck checks PHP-FPM and, once installation is detected, the configured MariaDB connection; it is not a full application or user-experience check.

The base-image scan is limited to Alpine OS packages; it excludes `/var/www/html` and does not scan or change the Chamilo release or its bundled dependencies. CI reports high and critical OS findings, including those without fixes, and fails for high or critical OS findings with a known fix. Review findings and update the base or packages as appropriate.

Trusted reverse proxies, forwarded headers and external HTTPS termination have not been verified. Do not expose this image through a proxy until those boundaries have been implemented and tested. Administrative credentials are chosen during the installer; none are built into the image. The example passwords in `.env.example` must be replaced.
