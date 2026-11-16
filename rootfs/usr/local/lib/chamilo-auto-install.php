<?php

declare(strict_types=1);

/*
 * Unattended fresh installation, opt-in through CHAMILO_AUTO_INSTALL=true.
 *
 * Replays the fresh-install branch of public/main/install/index.php (Chamilo 3.0.2)
 * with the release's own functions, as the chamilo-exelearning development image
 * does. Unlike the web installer, the state file is written last and atomically:
 * a failed run leaves no APP_INSTALLED=1, and the next start fails on the
 * existing tables instead of reinitialising the database.
 */

use Chamilo\CoreBundle\Framework\Container;
use Chamilo\CoreBundle\Helpers\ScimHelper;
use Chamilo\Kernel;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Console\Input\ArrayInput;
use Symfony\Component\Console\Output\ConsoleOutput;
use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\HttpFoundation\Session\Session as HttpSession;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;

const ROOT = '/var/www/html/';
const ENV_FILE = '/data/.env';

function fail(string $message): never
{
    fwrite(STDERR, "Chamilo unattended installation failed: $message\n");
    exit(1);
}

function env(string $name, ?string $default = null): string
{
    $value = getenv($name);
    if (false === $value || '' === $value) {
        if (null === $default) {
            fail("$name is required");
        }

        return $default;
    }

    return $value;
}

ini_set('memory_limit', '-1');
set_time_limit(0);

$url = rtrim(env('CHAMILO_URL'), '/').'/';
if (!preg_match('#^https?://[^/]+/$#', $url)) {
    fail('CHAMILO_URL must be an http(s) origin such as https://chamilo.example.org');
}
$adminPassword = env('CHAMILO_ADMIN_PASSWORD');
if (strlen($adminPassword) < 12) {
    fail('CHAMILO_ADMIN_PASSWORD must have at least 12 characters');
}
$adminEmail = env('CHAMILO_ADMIN_EMAIL');
$language = env('CHAMILO_LANGUAGE', 'en_US');
$db = [
    'host' => env('DB_HOST', 'db'),
    'port' => env('DB_PORT', '3306'),
    'name' => env('DB_NAME', 'chamilo'),
    'user' => env('DB_USER', 'chamilo'),
    'password' => env('DB_PASSWORD'),
];

$pdo = null;
for ($attempt = 0; null === $pdo; ++$attempt) {
    try {
        $pdo = new PDO(
            "mysql:host={$db['host']};port={$db['port']};dbname={$db['name']}",
            $db['user'],
            $db['password'],
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 3]
        );
    } catch (PDOException $error) {
        if ($attempt >= 60) {
            fail('the database is not reachable');
        }
        sleep(2);
    }
}
if ((int) $pdo->query('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()')->fetchColumn() > 0) {
    fail('the database is not empty but the state volume has no installed .env; restore the matching state volume');
}

require_once ROOT.'vendor/autoload.php';

define('SYSTEM_INSTALLATION', 1);
define('INSTALL_TYPE_UPDATE', 'update');
define('FORM_FIELD_DISPLAY_LENGTH', 40);
define('DATABASE_FORM_FIELD_DISPLAY_LENGTH', 25);
define('MAX_FORM_FIELD_LENGTH', 80);

Container::$session = new HttpSession(new MockArraySessionStorage());

require_once ROOT.'public/main/install/install.lib.php';

$pending = ENV_FILE.'.installing';
updateEnvFile(ROOT.'.env.dist', $pending, [
    '{{DATABASE_HOST}}' => $db['host'],
    '{{DATABASE_PORT}}' => $db['port'],
    '{{DATABASE_NAME}}' => $db['name'],
    '{{DATABASE_USER}}' => $db['user'],
    '{{DATABASE_PASSWORD}}' => $db['password'],
    '{{APP_INSTALLED}}' => 1,
    '{{APP_ENCRYPT_METHOD}}' => 'bcrypt',
    '{{APP_SECRET}}' => generateRandomToken(),
    '{{DB_MANAGER_ENABLED}}' => '0',
    '{{SOFTWARE_NAME}}' => 'Chamilo',
    '{{SOFTWARE_URL}}' => env('CHAMILO_INSTITUTION_URL', $url),
    '{{DENY_DELETE_USERS}}' => '0',
    '{{HOSTING_TOTAL_SIZE_LIMIT}}' => '0',
    '{{THEME_FALLBACK}}' => 'chamilo',
    '{{PACKAGER}}' => 'chamilo',
    '{{DEFAULT_TEMPLATE}}' => 'default',
    '{{ADMIN_CHAMILO_ANNOUNCEMENTS_DISABLE}}' => '0',
    '{{SCIM_TOKEN}}' => ScimHelper::createToken(),
]);
chmod($pending, 0600);
setEnvDatabaseServerVersion($pending, (string) $pdo->query('SELECT VERSION()')->fetchColumn());
$pdo = null;

(new Dotenv())->load($pending);
$kernel = new Kernel((string) $_SERVER['APP_ENV'], true);
$application = new Application($kernel);
$application->setAutoExit(false);
$run = static function (string $command, array $arguments = []) use ($application): void {
    $input = new ArrayInput(['command' => $command] + $arguments);
    $input->setInteractive(false);
    if (0 !== $application->run($input, new ConsoleOutput())) {
        fail("$command did not succeed");
    }
};

$run('doctrine:schema:create');
$run('doctrine:migrations:sync-metadata-storage');
$run('doctrine:migrations:version', ['--add' => true, '--all' => true]);
$kernel->boot();
$kernel->getContainer()->get('translator')->setLocale($language);
$run('doctrine:fixtures:load');

$kernel->boot();
finishInstallationWithContainer(
    $kernel->getContainer(),
    ROOT,
    'bcrypt',
    $adminPassword,
    env('CHAMILO_ADMIN_LASTNAME', 'Administrator'),
    env('CHAMILO_ADMIN_FIRSTNAME', 'Chamilo'),
    env('CHAMILO_ADMIN_USERNAME', 'admin'),
    $adminEmail,
    '',
    $language,
    env('CHAMILO_INSTITUTION', 'Chamilo'),
    env('CHAMILO_INSTITUTION_URL', $url),
    env('CHAMILO_SITE_NAME', 'Chamilo'),
    'false',
    0,
    '',
    env('CHAMILO_MAILER_DSN', 'null://null'),
    env('CHAMILO_MAILER_FROM_EMAIL', $adminEmail),
    env('CHAMILO_MAILER_FROM_NAME', 'Chamilo'),
    $kernel,
    $url
);

rename($pending, ENV_FILE) || fail('could not publish the state file');
fwrite(STDOUT, "Chamilo installed at $url\n");
