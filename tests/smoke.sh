#!/bin/sh
set -eu

export DB_PASSWORD='test-password-only' DB_ROOT_PASSWORD='test-root-password-only' CHAMILO_PORT=0 CHAMILO_INSTALLER_ENABLED=true CHAMILO_STATE_MODE=rw CHAMILO_CONFIG_MODE=rw
export CHAMILO_IMAGE="${CHAMILO_IMAGE:-alpine-chamilo:test}"
project="chamilo-test-$$"
compose() { docker compose --env-file /dev/null -p "$project" -f compose.yaml "$@"; }
cleanup() { compose down -v --remove-orphans >/dev/null; }
trap cleanup EXIT HUP INT TERM
compose up -d --no-build
container=$(compose ps -q chamilo)
attempt=0
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$container")" = healthy ]; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 60 ]; then
        compose logs chamilo db
        exit 1
    fi
    sleep 2
done
# The quoted command is evaluated inside the container.
# shellcheck disable=SC2016
compose exec -T chamilo sh -c 'test "$(id -u)" = 65534 && php -r '\''foreach (["bcmath", "ldap", "pdo_mysql", "intl", "gd", "zip", "xml", "soap"] as $e) { if (!extension_loaded($e)) exit(1); } if (ini_get("session.cookie_httponly") != 1) exit(1); $v = require "version.php"; exit($v["new_version"] === trim(file_get_contents("/etc/chamilo-version")) ? 0 : 1);'\'' && nginx -t'
# Code, startup scripts and the installer must not be writable by the runtime user.
# shellcheck disable=SC2016
compose exec -T chamilo sh -c 'for path in /var/www/html /var/www/html/vendor /var/www/html/public /docker-entrypoint-init.d/10-chamilo.sh /usr/local/lib/chamilo-auto-install.php /usr/local/bin/chamilo-healthcheck; do [ ! -w "$path" ] || exit 1; done'
compose exec -T chamilo grep -Fx "APP_ENV='prod'" .env.dist
compose exec -T chamilo grep -Fx "APP_DEBUG='0'" .env.dist
port=$(compose port chamilo 8080 | sed 's/.*://')
url="http://127.0.0.1:$port"
status() { curl -sS -o /dev/null -w '%{http_code}' "$url$1"; }
[ "$(status /check.php)" = 404 ]
[ "$(status /legacy.php)" = 404 ]
[ "$(status /.env)" = 403 ]
[ "$(status /build/manifest.json)" = 200 ]
[ "$(status /main/install/index.php)" = 200 ]
# A plugin can serve private package paths through its PHP entry point.
docker exec -i -u 0 "$container" sh -c 'cat > /var/www/html/public/plugin/path-info-test.php' <<'PHP'
<?php header("X-Content-Type-Options: nosniff"); echo $_SERVER["SCRIPT_NAME"], "|", $_SERVER["PATH_INFO"], "|", $_SERVER["HTTP_AUTHORIZATION"] ?? "";
PHP
[ "$(curl -fsS -H "Authorization: Bearer test-token" "$url/plugin/path-info-test.php/example/file")" = '/plugin/path-info-test.php|/example/file|Bearer test-token' ]
[ "$(status /plugin/does-not-exist.php/example/file)" = 404 ]
# A PHP response that sets nosniff itself still carries exactly one header.
[ "$(curl -fsS -D - -o /dev/null "$url/plugin/path-info-test.php/example/file" | grep -ci '^x-content-type-options:')" = 1 ]
[ "$(curl -fsS -D - -o /dev/null "$url/build/manifest.json" | grep -ci '^x-content-type-options:')" = 1 ]
compose exec -T chamilo sh -c 'printf persistence > /var/www/html/var/persistence-check'
compose restart chamilo >/dev/null
[ "$(compose exec -T chamilo cat /var/www/html/var/persistence-check)" = persistence ]
compose exec -T chamilo sh -c "printf 'APP_INSTALLED=1\\n' > /data/.env"
compose restart chamilo >/dev/null
port=$(compose port chamilo 8080 | sed 's/.*://')
url="http://127.0.0.1:$port"
attempt=0
until [ "$(curl -sS -o /dev/null -w '%{http_code}' "$url/main/install/index.php" 2>/dev/null || true)" = 403 ]; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 30 ] || { compose logs chamilo; exit 1; }
    sleep 1
done
compose exec -T chamilo grep -q APP_INSTALLED=1 /data/.env
compose exec -T chamilo sh -c 'printf 9.0.0 > /data/image-version'
compose restart chamilo >/dev/null
attempt=0
while [ "$(docker inspect -f '{{.State.Running}}' "$container")" = true ]; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 30 ] || { compose logs chamilo; exit 1; }
    sleep 1
done
docker logs "$container" 2>&1 | grep -q 'upgrades and downgrades are not yet supported'
printf '%s\n' 'Smoke checks passed (web installation is not covered).'
