# Plugins

`public/plugin` is a Composer classmap entry in Chamilo 3. A plugin's classes, including its `*EventSubscriber` files, exist for Chamilo only after the autoloader is regenerated. Copying files into the directory is not enough.

## Derived image (recommended)

Bake the plugin into your own image and regenerate the autoloader at build time:

```dockerfile
FROM erseco/alpine-chamilo:3.0.2
USER root
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY MyPlugin /var/www/html/public/plugin/MyPlugin
RUN cd /var/www/html \
    && composer dump-autoload --optimize --no-scripts --no-interaction \
    && rm /usr/bin/composer
USER nobody
```

The compiled cache is cleared at every start (see [operations](operations.md#volumes)), so the new classes are picked up without manual `cache:clear`. Regenerating the classmap drops only the `Chamilo\Tests` entries, which point to tests not shipped in the release. CI builds `tests/fixtures/plugin/Dockerfile`, installs and enables the plugin through Chamilo's plugin administration endpoint, and calls it with a `PATH_INFO` suffix.

Copy only the files your plugin ships. The classmap scans `public/plugin` recursively, so a development `vendor/`, `node_modules/` or build output would be loaded as well.

Then go to **Administration → Plugins**, add `?show_all_plugins=1` to the URL so third-party plugins are listed, and install and enable it.

The [eXeLearning plugin](https://github.com/exelearning/chamilo-exelearning) has been verified this way: install, enable, upload of an `.elpx` package, viewer, and package content served through `content.php/<…>/index.html` with the plugin's own security headers.

## PATH_INFO and authorization

Nginx passes `PATH_INFO` and the `Authorization` header to PHP entry points under `/plugin/` and `/main/`, and serves the plugin's static files directly. Chamilo's legacy bootstrap (`main/inc/global.inc.php`) starts Symfony with the current request, and the Symfony router answers 500 for an unknown path. A plugin that uses path-based URLs must therefore read and remove `PATH_INFO` before the bootstrap, as eXeLearning does:

```php
$pathInfo = (string) ($_SERVER['PATH_INFO'] ?? '');
$_SERVER['REQUEST_URI'] = (string) $_SERVER['SCRIPT_NAME'];
unset($_SERVER['PATH_INFO'], $_SERVER['ORIG_PATH_INFO']);
require_once __DIR__.'/../../main/inc/global.inc.php';
```

## Plugin development

For a plugin mounted from your working copy, use a derived development image that also keeps Composer and makes `vendor/composer` writable by `nobody`, and add an init script under `/docker-entrypoint-init.d/` that runs `composer dump-autoload` at start. Combine it with `CHAMILO_AUTO_INSTALL=true` for a disposable environment that installs itself. Hide development-only directories of the mounted plugin (for example with anonymous volumes over `vendor/` and `node_modules/`).

Plugin storage lives in `var/upload/plugins`, which is in the `chamilo-var` volume. Plugin database tables live in the database. Both are covered by the backup procedure. Changing a plugin's code is a new image, not a Chamilo version change, so it is not blocked; the plugin's own upgrade steps remain your responsibility.
