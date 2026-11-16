# Development and testing

The image uses a pinned `alpine-php-webserver` manifest and verifies the upstream 3.0.2 release archive by SHA-256 at build time. The application runs as `nobody`; its web root is `/var/www/html/public`. Changing a runtime environment variable cannot replace the code baked into the image.

Run the short checks with:

```sh
shellcheck rootfs/docker-entrypoint-init.d/*.sh rootfs/usr/local/bin/* rootfs/etc/service/*/run tests/*.sh
actionlint
python3 -m unittest discover -s tests -p 'test_*.py'
docker compose config -q
docker compose build
tests/smoke.sh
tests/proxy.sh
```

Compose configuration requires `DB_PASSWORD` and `DB_ROOT_PASSWORD` in `.env` or the environment. The smoke test creates its own disposable Compose project and volumes. It checks PHP, Nginx, routing, installer blocking, `PATH_INFO`, authorization forwarding and conservative version-change rejection.

For the full browser installation test, install Node.js and then run:

```sh
npm ci --prefix tests/e2e
tests/e2e/node_modules/.bin/playwright install chromium
tests/install.sh
```

This test uses a new disposable database, accepts the Chamilo GPLv3 license, installs with test credentials, logs in, recreates the container with state and configuration read-only and checks persistence, installer blocking database failure detection, a simulated trusted HTTPS proxy and a real local Nginx TLS proxy with a disposable test CA. It destroys only its own test project and volumes.

A plugin can be mounted under `/var/www/html/public/plugin/`. The image does not include Composer or automatically regenerate the application classmap; plugin deployment and upgrades require additional work. The eXeLearning plugin uses `PATH_INFO`, which the smoke test covers. Full plugin integration has not yet been verified with this image.

The release monitor considers stable 3.x GitHub release metadata, resolves tags and opens a compatibility PR when a newer release is found. Repository Actions settings must permit creating PRs. Bot-created PR workflows may require approval; the monitor separately dispatches CI on the candidate branch. A PR is not proof of compatibility or permission to publish.
