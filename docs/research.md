# Chamilo 3.0.2 investigation

These historical research notes predate implementation and are kept for reference. The image later moved from PHP 8.4 to 8.3, the platform the release's `vendor/` was resolved for. See the other pages for the current behaviour.

## Upstream release

The official [v3.0.2 release](https://github.com/chamilo/chamilo-lms/releases/tag/v3.0.2) provides `chamilo-3.0.2.zip`. Its published SHA-256 is `c54055f1754b377287c8e73880d2b967128b6d6a86bf3b91262f56cb4df855cf`; a downloaded copy matched it. The annotated tag object is `1e52b6b341f3cc9e740f13540fb67f1a6c38b745`, resolving to commit `5b1eaae48912ebde61c56ee145455a6c4127a162`. The ZIP contains `vendor/autoload.php` and `public/build/manifest.json`. The upstream `version.php` declares 3.0.2 stable. The README's download example still refers to 2.0.3; use the release asset, not that example.

The release's `composer.json` requires PHP ^8.3 and lists bcmath, ctype, curl, dom, exif, fileinfo, gd, iconv, intl, json, ldap, libxml, mbstring, pdo, simplexml, soap, sodium, xml, xmlreader, zip and zlib. Its README identifies PHP 8.3, 8.4 and 8.5 as supported. PHP 8.4 is therefore a reasonable candidate, subject to image and integration tests.

## Installation and persistent state

The release's `public/documentation/installation_guide.html` describes the web installer, not an unattended installation. During installation, `.env`, `config/` and `var/` need to be writable. It recommends removing write access to `.env` and `config/` and removing the installer after installation. The installer contains a lock for an installed, up-to-date instance, and an upgrade requires explicit `UPGRADE_ENABLED` authorization. This lock still needs end-to-end security testing under container restarts, database failure and upgrade conditions.

The default Flysystem configuration stores assets in `var/upload/assets`, resources in `var/upload/resource`, themes in `var/themes`, and plugins in `var/upload/plugins`; its cache paths are separate. The installer writes `.env`. This is not yet an exhaustive persistence inventory: legacy code, generated keys, plugins, SCORM and upgrades must be checked before volumes are designed. Mounting the entire `config/` or application root risks masking new release code and needs particular care.

## Web server and proxy

The installation guide supplies a version-specific Nginx example with `public/` as document root, direct legacy PHP under `main/` and `plugin/`, Symfony front-controller routing, static directories, and denial of `check.php`, `legacy.php`, hidden files and other root PHP scripts. This example needs security and functional testing before use; installer and upload paths need special attention.

The inspected `alpine-php-webserver` source defaults to user `nobody`, runs Nginx and PHP-FPM under runit, exposes initialization hooks, and checks `/fpm-ping`. Its default Nginx template uses forwarded protocol and port headers without checking the connecting peer. A derived image must not inherit that behavior without enforcing a trusted proxy boundary; Symfony's `TRUSTED_PROXIES` alone does not repair values already rewritten by Nginx. Test both Symfony and legacy endpoints behind an explicitly trusted proxy and against spoofed direct requests.

## Outstanding validation

Build and inspect the pinned base image and release artifact; verify required extensions and runtime permissions. Design persistent configuration without hiding release updates, test the real browser installer and installer lockdown, then test uploads, authentication, restarts and upgrade/downgrade handling with MariaDB. Validate all workflows and multi-platform images before publishing. These initial notes predate implementation; see the README for current verification and limitations.

The base image `ghcr.io/erseco/alpine-php-webserver:3.24-php84` was pulled with manifest digest `sha256:a4fd132a1a2a8141c69eb4529935f51c1f293aeaa8789e8013e7ef9a05184018`. On the local arm64 engine, `php -v` reported PHP 8.4.27 and `id` reported `nobody` (UID/GID 65534). Its loaded modules did not include bcmath or ldap; the derived image must install and verify them. This check does not establish compatibility of either architecture with Chamilo.
