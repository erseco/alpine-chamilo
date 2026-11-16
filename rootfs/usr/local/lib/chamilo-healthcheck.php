<?php

declare(strict_types=1);

use Symfony\Component\Dotenv\Dotenv;

try {
    require '/var/www/html/vendor/autoload.php';
    (new Dotenv())->loadEnv('/var/www/html/.env');
    $host = $_SERVER['DATABASE_HOST'];
    $port = $_SERVER['DATABASE_PORT'];
    $database = $_SERVER['DATABASE_NAME'];
    $connection = new PDO(
        "mysql:host=$host;port=$port;dbname=$database",
        $_SERVER['DATABASE_USER'],
        $_SERVER['DATABASE_PASSWORD'],
        [PDO::ATTR_TIMEOUT => 3, PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $connection->query('SELECT 1');
} catch (Throwable $error) {
    fwrite(STDERR, "Chamilo database healthcheck failed\n");
    exit(1);
}
