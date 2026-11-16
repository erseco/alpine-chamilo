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
- **Release** runs on `vX.Y.Z` and `vX.Y.Z-rN` tags. It checks that the tag matches `CHAMILO_VERSION`, runs CI, builds `linux/amd64` and `linux/arm64` with provenance, pushes to GHCR, smoke-tests the pushed digest, copies the same manifest to Docker Hub, and verifies that every tag on both registries points to that digest. Docker Hub needs the `DOCKER_USERNAME` and `DOCKER_PASSWORD` repository secrets.
- **Documentation** builds this site with Zensical and deploys it to GitHub Pages from `main`.
- **Check upstream releases** runs daily. When a newer stable Chamilo 3.x release with a published SHA-256 appears, it opens a pull request that updates the version and digest and dispatches CI on it. It never publishes. Merging such a pull request is not enough: version changes stay blocked at run time until an upgrade procedure exists, so a new Chamilo version needs that work first. The repository must allow GitHub Actions to create pull requests.

## Releasing

1. Merge to `main` with CI green.
2. Tag: `git tag v3.0.2` for a new Chamilo version, or `git tag v3.0.2-r1` for an image-only revision (base image or package updates), and push the tag.
3. Check the release run's summary for the published digest.
