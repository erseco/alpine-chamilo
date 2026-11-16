#!/bin/sh
# Unattended installation: course workflow, idempotent restart and refusal to reuse a populated database.
set -eu

port="${AUTO_INSTALL_TEST_PORT:-18093}"
# The literal dollar signs exercise credential escaping.
# shellcheck disable=SC2016
export DB_PASSWORD='auto Pa$$word!#@' DB_ROOT_PASSWORD='auto-root-password' CHAMILO_PORT="$port" CHAMILO_INSTALLER_ENABLED=false
export CHAMILO_STATE_MODE=rw CHAMILO_CONFIG_MODE=rw CHAMILO_TRUSTED_PROXIES='' CHAMILO_AUTO_INSTALL=true
export CHAMILO_ADMIN_PASSWORD='Testing-Only-Password-123!' CHAMILO_ADMIN_EMAIL=admin@example.test CHAMILO_URL="http://127.0.0.1:$port"
# Install into a derived image that adds a plugin, as documented for plugin users.
docker build -q --build-arg BASE="${CHAMILO_IMAGE:-alpine-chamilo:test}" -t alpine-chamilo:plugin-test tests/fixtures/plugin >/dev/null
export CHAMILO_IMAGE=alpine-chamilo:plugin-test
project="chamilo-auto-$$"
compose() { docker compose --env-file /dev/null -p "$project" -f compose.yaml "$@"; }
TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/chamilo-auto.XXXXXX")
TEST_SCORM_ZIP="$TEST_TMPDIR/scorm.zip"
export TEST_TMPDIR TEST_SCORM_ZIP
cleanup() { compose down -v --remove-orphans >/dev/null 2>&1; rm -rf "$TEST_TMPDIR"; }
trap cleanup EXIT HUP INT TERM
(cd tests/fixtures/scorm && zip -q "$TEST_SCORM_ZIP" imsmanifest.xml index.html)

wait_healthy() {
    container=$(compose ps -aq chamilo)
    attempt=0
    until [ "$(docker inspect -f '{{.State.Health.Status}}' "$container")" = healthy ]; do
        attempt=$((attempt + 1))
        [ "$attempt" -lt 120 ] || { compose logs chamilo; exit 1; }
        sleep 2
    done
    TEST_URL="http://127.0.0.1:$(compose port chamilo 8080 | sed 's/.*://')"
    export TEST_URL
}
compose up -d --no-build
wait_healthy
compose logs chamilo | grep -q "Chamilo installed at $CHAMILO_URL/"
# Evaluated inside the container.
# shellcheck disable=SC2016
compose exec -T chamilo sh -c 'test -f /data/installed && test ! -e /data/.env.installing && test "$(stat -c %a /data/.env)" = 600'
[ "$(curl -s -o /dev/null -w '%{http_code}' "$TEST_URL/main/install/index.php")" = 403 ]
node tests/e2e/install.cjs course
jar="$TEST_TMPDIR/cookies"
curl -fsS -c "$jar" -H "Origin: $TEST_URL" -H 'Content-Type: application/json' \
    -d "{\"username\":\"admin\",\"password\":\"$CHAMILO_ADMIN_PASSWORD\"}" "$TEST_URL/login_json" >/dev/null
for action in install enable; do
    curl -fsS -b "$jar" -H "Origin: $TEST_URL" -d "a=$action&plugin=ContainerTest" "$TEST_URL/main/inc/ajax/plugin.ajax.php" | grep -q '"success":true'
done
[ "$(curl -fsS -b "$jar" "$TEST_URL/plugin/ContainerTest/check.php/package/index.html")" = 'enabled|admin|/package/index.html' ]

compose up -d --no-deps --force-recreate --no-build chamilo
wait_healthy
node tests/e2e/install.cjs course-check

# A new, empty state volume must not reinitialise an existing database.
compose stop chamilo >/dev/null
compose rm -f chamilo >/dev/null
docker volume rm "${project}_chamilo-state" >/dev/null
compose up -d --no-deps --no-build chamilo
container=$(compose ps -aq chamilo)
attempt=0
while [ "$(docker inspect -f '{{.State.Running}}' "$container")" = true ]; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 60 ] || { compose logs chamilo; exit 1; }
    sleep 1
done
docker logs "$container" 2>&1 | grep -q 'the database is not empty'
printf '%s\n' 'Unattended installation and plugin checks passed.'
