#!/bin/sh
set -eu

cd /var/www/html
CHAMILO_IMAGE_VERSION=$(cat /etc/chamilo-version)
if [ -f /data/image-version ]; then
    previous=$(cat /data/image-version)
    if [ "$previous" != "$CHAMILO_IMAGE_VERSION" ]; then
        echo >&2 "Chamilo version changed from $previous to $CHAMILO_IMAGE_VERSION; upgrades and downgrades are not yet supported. Restore the previous image and volume."
        exit 1
    fi
else
    printf '%s\n' "$CHAMILO_IMAGE_VERSION" > /data/image-version
fi
mkdir -p /data/jwt
[ -f /data/.env ] || touch /data/.env
case "${CHAMILO_INSTALLER_ENABLED:-false}" in
    true) rm -f /tmp/chamilo-installer-disabled ;;
    false) touch /tmp/chamilo-installer-disabled ;;
    *) echo >&2 "CHAMILO_INSTALLER_ENABLED must be true or false"; exit 1 ;;
esac
if grep -Eq "^APP_INSTALLED=['\"]?1['\"]?[[:space:]]*$" /data/.env; then
    touch /data/installed
fi
