<?php

// Chamilo boots Symfony with this request: keep the path for the plugin and hide it from the router.
$pathInfo = (string) ($_SERVER['PATH_INFO'] ?? '');
$_SERVER['REQUEST_URI'] = (string) $_SERVER['SCRIPT_NAME'];
unset($_SERVER['PATH_INFO'], $_SERVER['ORIG_PATH_INFO']);

require_once __DIR__.'/../../main/inc/global.inc.php';

header('Content-Type: text/plain');
echo ContainerTestPlugin::create()->isEnabled() ? 'enabled' : 'disabled', '|',
    api_is_platform_admin() ? 'admin' : 'anonymous', '|', $pathInfo;
