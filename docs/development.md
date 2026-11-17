# Development and testing

The Dockerfile pins the `alpine-php-webserver` 3.24/PHP 8.3 manifest and the Chamilo release with its SHA-256. PHP 8.3 matches the release itself: its `composer.json` sets `config.platform.php` to 8.3, and upstream's browser CI runs on 8.3.

## Checks

```sh
hadolint Dockerfile
shellcheck rootfs/docker-entrypoint-init.d/*.sh rootfs/usr/local/bin/* rootfs/etc/service/*/run tests/*.sh
actionlint
python3 -m unittest discover -s tests -p 'test_*.py'
DB_PASSWORD=x DB_ROOT_PASSWORD=x docker compose config -q
docker build -t alpine-chamilo:test .
tests/smoke.sh          # contents, permissions, routing, PATH_INFO, installer and version guards
tests/proxy.sh          # trusted-proxy header filtering
npm ci --prefix tests/e2e
tests/e2e/node_modules/.bin/playwright install chromium
tests/install.sh        # web installer, courses, read-only state, DB failure, TLS proxy, backup/restore
tests/auto-install.sh   # unattended install in a derived plugin image, recreation, refusal to reuse a database
```

Every script creates and removes its own Compose project and volumes, and ignores any `.env` in the working copy. On macOS you can use the installed Chrome: `PLAYWRIGHT_EXECUTABLE_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'`. The browser tests accept Chamilo's GPLv3 license on disposable databases.

`tests/e2e/install.cjs` drives Chamilo's real UI: installer steps, login, course creation (`main/admin/course_add.php`), document upload (Uppy), SCORM import (`/resources/lp/<node>/import`) and the SCORM player, where the fixture package in `tests/fixtures/scorm` reports whether it found the SCORM API.

## Workflows

- **CI** runs all of the above on amd64 for pushes and pull requests, and is reused by the release.
- **Release** runs on `vX.Y.Z` tags, and manually on `main` to rebuild the current version. It checks that the version matches `CHAMILO_VERSION`, computes the aliases with `scripts/release-tags.sh` (`X.Y`, `X` and `latest` only for the newest release in their range), runs CI, builds `linux/amd64` and `linux/arm64` with provenance, pushes to GHCR, smoke-tests the pushed digest, copies the same manifest to Docker Hub, and verifies that every tag on both registries points to that digest. Docker Hub needs the `DOCKER_USERNAME` and `DOCKER_PASSWORD` repository secrets.
- **Documentation** builds this site with Zensical and deploys it to GitHub Pages from `main`.
- **Check upstream releases** runs daily, like alpine-moodle's tag sync. When a newer stable Chamilo 3.x release with a published SHA-256 appears (major versions above 3 are never picked), it commits the new version and digest to `main`, tags `vX.Y.Z` in the same atomic push and starts the **Release** workflow on that tag. Nothing is published unless the full CI passes on the new version; a failure leaves the commit and tag in place and the run red for review. It can also be started by hand with a specific version. The new image only serves new installations: existing volumes keep refusing a Chamilo version change until an upgrade procedure exists, so stay on the previous `X.Y.Z` tag with them.

## Releasing

1. Merge to `main` with CI green.
2. New Chamilo version: `git tag vX.Y.Z` and push the tag. Same Chamilo version with a new base image or packages: run the **Release** workflow manually on `main` (`gh workflow run release.yml --ref main`); it republishes `X.Y.Z` and its aliases.
3. Check the release run's summary for the published digest.
