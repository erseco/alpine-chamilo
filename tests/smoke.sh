#!/bin/sh
set -eu

export DB_PASSWORD='test-password-only' DB_ROOT_PASSWORD='test-root-password-only' CHAMILO_PORT=0
export CHAMILO_IMAGE="${CHAMILO_IMAGE:-alpine-chamilo:test}"
project="chamilo-test-$$"
compose() { docker compose -p "$project" -f compose.yaml "$@"; }
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
compose exec -T chamilo sh -c 'test "$(id -u)" = 65534 && php -r '\''foreach (["bcmath", "ldap", "pdo_mysql", "intl", "gd", "zip", "xml", "soap"] as $e) { if (!extension_loaded($e)) exit(1); } $v = require "version.php"; exit($v["new_version"] === "3.0.2" ? 0 : 1);'\'' && nginx -t'
port=$(compose port chamilo 8080 | sed 's/.*://')
url="http://127.0.0.1:$port"
status() { curl -sS -o /dev/null -w '%{http_code}' "$url$1"; }
[ "$(status /check.php)" = 404 ]
[ "$(status /legacy.php)" = 404 ]
[ "$(status /.env)" = 403 ]
[ "$(status /build/manifest.json)" = 200 ]
[ "$(status /main/install/index.php)" = 200 ]
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
