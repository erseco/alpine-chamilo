#!/bin/sh
set -eu

: "${TEST_COMPOSE_PROJECT:?Run through tests/install.sh}"
compose() { docker compose --env-file /dev/null -p "$TEST_COMPOSE_PROJECT" -f compose.yaml "$@"; }
tls_dir=$(mktemp -d "${TMPDIR:-/tmp}/chamilo-tls.XXXXXX")
proxy="${TEST_COMPOSE_PROJECT}-tls"
cleanup() {
    docker rm -f "$proxy" >/dev/null 2>&1 || true
    rm -rf "$tls_dir"
}
trap cleanup EXIT HUP INT TERM
chmod 755 "$tls_dir"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=Chamilo test CA' \
    -keyout "$tls_dir/ca.key" -out "$tls_dir/ca.crt" >/dev/null 2>&1
openssl req -new -newkey rsa:2048 -nodes -subj '/CN=chamilo.test' \
    -keyout "$tls_dir/server.key" -out "$tls_dir/server.csr" >/dev/null 2>&1
printf 'subjectAltName=DNS:chamilo.test\nextendedKeyUsage=serverAuth\n' > "$tls_dir/extensions"
openssl x509 -req -days 1 -in "$tls_dir/server.csr" -CA "$tls_dir/ca.crt" -CAkey "$tls_dir/ca.key" \
    -CAcreateserial -extfile "$tls_dir/extensions" -out "$tls_dir/server.crt" >/dev/null 2>&1
chmod 644 "$tls_dir/server.key" "$tls_dir/server.crt"
cat > "$tls_dir/nginx.conf" <<'NGINX'
worker_processes 1;
pid /tmp/tls-proxy.pid;
error_log stderr warn;
events { worker_connections 128; }
http {
    access_log /dev/stdout;
    map $http_host $public_port { default 443; ~:(\d+)$ $1; }
    server {
        listen 8443 ssl;
        ssl_certificate /tls/server.crt;
        ssl_certificate_key /tls/server.key;
        location / {
            proxy_pass http://chamilo:8080;
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-Port $public_port;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For $remote_addr;
        }
    }
}
NGINX
docker run -d --name "$proxy" --network "${TEST_COMPOSE_PROJECT}_default" \
    -p 127.0.0.1::8443 -v "$tls_dir:/tls:ro" --entrypoint nginx "$CHAMILO_IMAGE" \
    -c /tls/nginx.conf -g 'daemon off;' >/dev/null
CHAMILO_TRUSTED_PROXIES=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$proxy")
export CHAMILO_TRUSTED_PROXIES
compose up -d --no-deps --force-recreate --no-build chamilo
port=$(docker port "$proxy" 8443/tcp | sed 's/.*://')
origin="https://chamilo.test:$port"
attempt=0
until curl --noproxy '*' --silent --fail --cacert "$tls_dir/ca.crt" \
    --resolve "chamilo.test:$port:127.0.0.1" "$origin/" -o /dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 60 ] || { compose logs chamilo; docker logs "$proxy"; exit 1; }
    sleep 2
done
if curl --noproxy '*' --silent --fail --cacert "$tls_dir/ca.crt" \
    --resolve "wrong.test:$port:127.0.0.1" "https://wrong.test:$port/" -o /dev/null 2>&1; then
    echo >&2 'TLS hostname verification unexpectedly succeeded'
    exit 1
fi
status=$(curl --noproxy '*' --silent --cacert "$tls_dir/ca.crt" \
    --resolve "chamilo.test:$port:127.0.0.1" -D "$tls_dir/headers" -o "$tls_dir/login.json" \
    -w '%{http_code}' -H "Origin: $origin" -H 'Content-Type: application/json' \
    --data '{"username":"admin","password":"Testing-Only-Password-123!"}' "$origin/login_json")
[ "$status" = 200 ]
tr -d '\r' < "$tls_dir/headers" | grep -i '^set-cookie:.*chamilo2=.*secure' >/dev/null
printf '%s\n' 'TLS proxy, certificate validation and secure login cookie passed.'
