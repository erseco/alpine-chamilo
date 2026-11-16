# Example of a derived image that adds a Chamilo plugin (used by tests/auto-install.sh).
ARG BASE=alpine-chamilo:test
FROM ${BASE}
USER root
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY ContainerTest /var/www/html/public/plugin/ContainerTest
# public/plugin is a Composer classmap entry: register the plugin classes in the release autoloader.
RUN cd /var/www/html \
    && composer dump-autoload --optimize --no-scripts --no-interaction \
    && rm /usr/bin/composer
USER nobody
