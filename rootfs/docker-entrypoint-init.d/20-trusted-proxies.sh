#!/bin/sh
set -eu

proxy_file=/etc/nginx/chamilo-trusted-proxies.conf
fpm_file=/etc/php83/php-fpm.d/zz-chamilo-proxies.conf
: > "$proxy_file"
proxy_list=
# Split only the administrator-supplied comma-separated list.
for proxy in $(printf '%s' "${CHAMILO_TRUSTED_PROXIES:-}" | tr ',' ' '); do
    case "$proxy" in
        *[!0-9a-fA-F:./]*)
            echo >&2 'Invalid trusted proxy: use explicit IP addresses or nonzero CIDR ranges'
            exit 1
            ;;
    esac
    case "$proxy" in
        */*)
            prefix=${proxy##*/}
            case "$prefix" in
                ''|0*|*[!0-9]*) echo >&2 'Trusted proxy CIDR prefix must be nonzero'; exit 1 ;;
            esac
            ;;
    esac
    printf '%s 1;\n' "$proxy" >> "$proxy_file"
    proxy_list="${proxy_list:+$proxy_list,}$proxy"
done
if [ -n "$proxy_list" ]; then
    printf '[www]\nenv[TRUSTED_PROXIES] = "%s"\n' "$proxy_list" > "$fpm_file"
else
    rm -f "$fpm_file"
fi
nginx -t
php-fpm83 -t
