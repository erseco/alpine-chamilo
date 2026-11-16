# The digest pins the multi-platform manifest, not just the local architecture.
FROM ghcr.io/erseco/alpine-php-webserver:3.24-php84@sha256:a4fd132a1a2a8141c69eb4529935f51c1f293aeaa8789e8013e7ef9a05184018

ARG CHAMILO_VERSION=3.0.2
ARG CHAMILO_SHA256=c54055f1754b377287c8e73880d2b967128b6d6a86bf3b91262f56cb4df855cf
LABEL org.opencontainers.image.source="https://github.com/erseco/alpine-chamilo" \
      org.opencontainers.image.description="Chamilo LMS on Alpine Linux, Nginx and PHP-FPM" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.version="${CHAMILO_VERSION}"

# hadolint ignore=DL3066
USER root
# The base image already selects ash with pipefail.
# hadolint ignore=DL3018,DL4006,SC2016
RUN apk add --no-cache php84-bcmath php84-ldap unzip \
    && rm -rf /var/www/html/* \
    && curl -fsSL --retry 5 "https://github.com/chamilo/chamilo-lms/releases/download/v${CHAMILO_VERSION}/chamilo-${CHAMILO_VERSION}.zip" -o /tmp/chamilo.zip \
    && echo "${CHAMILO_SHA256}  /tmp/chamilo.zip" | sha256sum -c - \
    && unzip -q /tmp/chamilo.zip -d /var/www/html \
    && rm /tmp/chamilo.zip \
    && test "$(php -r '$v = require "/var/www/html/version.php"; echo $v["new_version"];')" = "$CHAMILO_VERSION" \
    && test -f /var/www/html/vendor/autoload.php \
    && test -f /var/www/html/public/build/manifest.json \
    && printf '%s\n' "$CHAMILO_VERSION" > /etc/chamilo-version \
    && mkdir -p /data/jwt \
    && touch /data/.env \
    && ln -s /data/.env /var/www/html/.env \
    && rm -rf /var/www/html/config/jwt \
    && ln -s /data/jwt /var/www/html/config/jwt \
    && chown -R nobody:nobody /data /var/www/html/config /var/www/html/var
# The image uses MariaDB, so it does not need the base image's PostgreSQL driver.
RUN apk del --no-cache php84-pgsql
# The installer copies these defaults into the persistent .env file.
RUN grep -Fx "APP_ENV='prod'" /var/www/html/.env.dist \
    && grep -Fx "APP_DEBUG='0'" /var/www/html/.env.dist \
    && chmod 600 /data/.env
COPY --chown=nobody rootfs/ /
RUN chmod +x /docker-entrypoint-init.d/10-chamilo.sh /docker-entrypoint-init.d/20-trusted-proxies.sh /usr/local/bin/chamilo-healthcheck /etc/service/chamilo-installer-guard/run
ENV nginx_root_directory=/var/www/html/public \
    client_max_body_size=256M post_max_size=256M upload_max_filesize=256M \
    memory_limit=512M opcache_enable=1
# hadolint ignore=DL3066
USER nobody

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD ["/usr/local/bin/chamilo-healthcheck"]
