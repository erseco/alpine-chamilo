#!/bin/sh
set -eu

export DB_PASSWORD='test-password-only' DB_ROOT_PASSWORD='test-root-password-only' CHAMILO_PORT=0
export CHAMILO_IMAGE="${CHAMILO_IMAGE:-alpine-chamilo:test}" CHAMILO_TRUSTED_PROXIES=
project="chamilo-proxy-$$"
compose() { docker compose -p "$project" -f compose.yaml "$@"; }
cleanup() { compose down -v --remove-orphans >/dev/null; }
trap cleanup EXIT HUP INT TERM
wait_http() {
    port=$(compose port chamilo 8080 | sed 's/.*://')
    url="http://127.0.0.1:$port"
    attempt=0
    until curl -s -o /dev/null "$url/fpm-ping"; do
        attempt=$((attempt + 1))
        [ "$attempt" -lt 60 ] || { compose logs chamilo; exit 1; }
        sleep 1
    done
}
install_fixture() {
    container=$(compose ps -q chamilo)
    docker exec -i -u 0 "$container" sh -c 'cat > /var/www/html/public/plugin/proxy-test.php' <<'PHP'
<?php echo ($_SERVER['HTTP_X_FORWARDED_FOR'] ?? ''), '|', ($_SERVER['HTTP_X_FORWARDED_HOST'] ?? ''), '|', ($_SERVER['HTTP_X_FORWARDED_PORT'] ?? ''), '|', ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''), '|', ($_SERVER['HTTPS'] ?? ''), '|', (getenv('TRUSTED_PROXIES') ?: ''), '|', ($_SERVER['HTTP_FORWARDED'] ?? '');
PHP
}
headers() {
    curl -fsS -H 'X-Forwarded-For: 203.0.113.7' -H 'X-Forwarded-Host: learn.example.test' \
        -H 'X-Forwarded-Port: 443' -H 'X-Forwarded-Proto: https' -H 'Forwarded: proto=https' "$1"
}
compose up -d --no-build
wait_http
install_fixture
[ "$(headers "$url/plugin/proxy-test.php")" = '||||||' ]
CHAMILO_TRUSTED_PROXIES=$(docker network inspect "${project}_default" --format '{{(index .IPAM.Config 0).Gateway}}')
export CHAMILO_TRUSTED_PROXIES
compose up -d --no-deps --force-recreate --no-build chamilo
wait_http
install_fixture
[ "$(headers "$url/plugin/proxy-test.php")" = "203.0.113.7|learn.example.test|443|https|on|$CHAMILO_TRUSTED_PROXIES|" ]
[ "$(docker exec "$container" curl -fsS -H 'X-Forwarded-Proto: https' http://127.0.0.1:8080/plugin/proxy-test.php)" = "|||||$CHAMILO_TRUSTED_PROXIES|" ]
for invalid in 0.0.0.0/0 ::/0000 '127.0.0.1;evil'; do
    if docker run --rm -e "CHAMILO_TRUSTED_PROXIES=$invalid" "$CHAMILO_IMAGE" >/dev/null 2>&1; then
        echo >&2 'Invalid trusted proxy must be rejected'
        exit 1
    fi
done
printf '%s\n' 'Trusted and untrusted proxy checks passed.'
