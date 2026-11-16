#!/bin/sh
# Cold backup of the four volumes, restore into a new Compose project and check the course content.
set -eu

: "${TEST_COMPOSE_PROJECT:?Run through tests/install.sh}"
restore="${TEST_COMPOSE_PROJECT}-restore"
backup="${TEST_COMPOSE_PROJECT}-backup"
volumes='chamilo-state chamilo-config chamilo-var chamilo-db'
cleanup() {
    docker compose --env-file /dev/null -p "$restore" -f compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true
    docker volume rm "$backup" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM
tar_in() {
    target=$1
    shift
    docker run --rm -u 0 --entrypoint tar -v "$target:/source" -v "$backup:/backup" "$CHAMILO_IMAGE" "$@"
}

docker compose --env-file /dev/null -p "$TEST_COMPOSE_PROJECT" -f compose.yaml stop >/dev/null
for volume in $volumes; do
    tar_in "${TEST_COMPOSE_PROJECT}_$volume" -C /source -czf "/backup/$volume.tar.gz" .
done
for volume in $volumes; do
    docker volume create "${restore}_$volume" >/dev/null
    tar_in "${restore}_$volume" -C /source -xzf "/backup/$volume.tar.gz"
done
docker compose --env-file /dev/null -p "$restore" -f compose.yaml up -d --no-build 2>/dev/null
port=$(docker compose --env-file /dev/null -p "$restore" -f compose.yaml port chamilo 8080 | sed 's/.*://')
TEST_URL="http://127.0.0.1:$port"
export TEST_URL
attempt=0
until curl -s -o /dev/null "$TEST_URL/fpm-ping"; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 60 ] || { docker compose --env-file /dev/null -p "$restore" -f compose.yaml logs; exit 1; }
    sleep 2
done
[ "$(curl -s -o /dev/null -w '%{http_code}' "$TEST_URL/main/install/index.php")" = 403 ]
node tests/e2e/install.cjs course-check
printf '%s\n' 'Backup and restore checks passed.'
