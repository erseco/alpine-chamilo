#!/bin/sh
set -eu

# The literal dollar signs exercise credential escaping.
# shellcheck disable=SC2016
export DB_PASSWORD='test Pa$$word!#@' DB_ROOT_PASSWORD='install-root-password' CHAMILO_PORT=0 CHAMILO_INSTALLER_ENABLED=true CHAMILO_STATE_MODE=rw CHAMILO_CONFIG_MODE=rw
export CHAMILO_IMAGE="${CHAMILO_IMAGE:-alpine-chamilo:test}" CHAMILO_TRUSTED_PROXIES=
project="chamilo-install-$$"
compose() { docker compose --env-file /dev/null -p "$project" -f compose.yaml "$@"; }
TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/chamilo-install.XXXXXX")
TEST_SCORM_ZIP="$TEST_TMPDIR/scorm.zip"
export TEST_TMPDIR TEST_SCORM_ZIP
cleanup() { compose down -v --remove-orphans >/dev/null; rm -rf "$TEST_TMPDIR"; }
trap cleanup EXIT HUP INT TERM
(cd tests/fixtures/scorm && zip -q "$TEST_SCORM_ZIP" imsmanifest.xml index.html)
compose up -d --no-build
wait_http() {
    port=$(compose port chamilo 8080 | sed 's/.*://')
    export TEST_URL="http://127.0.0.1:$port"
    attempt=0
    until curl -s -o /dev/null "$TEST_URL/fpm-ping"; do
        attempt=$((attempt + 1))
        [ "$attempt" -lt 60 ] || { compose logs chamilo db; exit 1; }
        sleep 2
    done
}
wait_http
node tests/e2e/install.cjs install
attempt=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "$TEST_URL/main/install/index.php")" = 403 ]; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 15 ] || { echo >&2 'Installer was not closed after installation'; exit 1; }
    sleep 1
done
node tests/e2e/install.cjs course
compose exec -T chamilo sh -c 'sha256sum /data/.env > /data/env-check; printf persisted > var/integration-persistence'
export CHAMILO_STATE_MODE=ro CHAMILO_CONFIG_MODE=ro CHAMILO_INSTALLER_ENABLED=false
compose up -d --no-deps --force-recreate --no-build chamilo
wait_http
if compose exec -T chamilo sh -c 'touch /data/readonly-test' >/dev/null 2>&1; then
    echo >&2 'State volume must be read-only after installation'
    exit 1
fi
if compose exec -T chamilo sh -c 'touch /var/www/html/config/readonly-test' >/dev/null 2>&1; then
    echo >&2 'Configuration volume must be read-only after installation'
    exit 1
fi
# This command is evaluated inside the container.
# shellcheck disable=SC2016
compose exec -T chamilo sh -c 'sha256sum -c /data/env-check && test "$(cat var/integration-persistence)" = persisted'
[ "$(curl -s -o /dev/null -w '%{http_code}' "$TEST_URL/main/install/index.php")" = 403 ]
node tests/e2e/install.cjs course-check
compose exec -T chamilo /usr/local/bin/chamilo-healthcheck
compose stop db >/dev/null
[ "$(curl -s -o /dev/null -w '%{http_code}' "$TEST_URL/main/install/index.php")" = 403 ]
if compose exec -T chamilo /usr/local/bin/chamilo-healthcheck; then
    echo >&2 'Healthcheck did not detect the stopped database'
    exit 1
fi
compose start db >/dev/null
CHAMILO_TRUSTED_PROXIES=$(docker network inspect "${project}_default" --format '{{(index .IPAM.Config 0).Gateway}}')
export CHAMILO_TRUSTED_PROXIES
compose up -d --no-deps --force-recreate --no-build chamilo
wait_http
attempt=0
until compose exec -T chamilo /usr/local/bin/chamilo-healthcheck >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 60 ] || { compose logs chamilo db; exit 1; }
    sleep 2
done
node tests/e2e/install.cjs proxy
export TEST_COMPOSE_PROJECT="$project"
tests/tls-proxy.sh
tests/backup-restore.sh
printf '%s\n' 'Installation, course, persistence and backup checks passed.'
