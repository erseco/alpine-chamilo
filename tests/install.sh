#!/bin/sh
set -eu

export DB_PASSWORD='install-test-password' DB_ROOT_PASSWORD='install-root-password' CHAMILO_PORT=0
export CHAMILO_IMAGE="${CHAMILO_IMAGE:-alpine-chamilo:test}"
project="chamilo-install-$$"
compose() { docker compose -p "$project" -f compose.yaml "$@"; }
cleanup() { compose down -v --remove-orphans >/dev/null; }
trap cleanup EXIT HUP INT TERM
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
compose exec -T chamilo sh -c 'sha256sum /data/.env > /data/env-check; printf persisted > var/integration-persistence'
compose up -d --no-deps --force-recreate --no-build chamilo
wait_http
# This command is evaluated inside the container.
# shellcheck disable=SC2016
compose exec -T chamilo sh -c 'sha256sum -c /data/env-check && test "$(cat var/integration-persistence)" = persisted'
[ "$(curl -s -o /dev/null -w '%{http_code}' "$TEST_URL/main/install/index.php")" = 403 ]
node tests/e2e/install.cjs login
printf '%s\n' 'Installation, login and persistence checks passed.'
