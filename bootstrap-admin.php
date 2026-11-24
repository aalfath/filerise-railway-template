<?php
// Creates the first FileRise admin from environment variables, before Apache
// listens, so no visitor can claim the instance through the setup wizard.
// Exit codes: 0 = admin created or users already exist, non-zero = refuse to start.
declare(strict_types=1);

$usersDir  = '/var/www/users';
$usersFile = $usersDir . '/users.txt';
$marker    = $usersDir . '/.setup_complete';
$userRegex = '/^(?!\.{1,2}$)[\p{L}\p{N}_\- .@]+$/u'; // REGEX_USER in config/config.php

function hasUsers(string $file, string $re): bool {
    if (!is_file($file)) return false;
    foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
        $parts = explode(':', trim($line));
        if (count($parts) >= 3 && preg_match($re, $parts[0])) return true;
    }
    return false;
}

if (hasUsers($usersFile, $userRegex)) {
    if (!is_file($marker)) {
        file_put_contents($marker, json_encode(['completedAt' => time()]), LOCK_EX);
    }
    fwrite(STDOUT, "[railway] users exist; admin bootstrap skipped\n");
    exit(0);
}

$user = trim((string)getenv('FILERISE_ADMIN_USER'));
$pass = trim((string)getenv('FILERISE_ADMIN_PASSWORD'));
if ($user === '') $user = 'admin';
if (!preg_match($userRegex, $user)) {
    fwrite(STDERR, "[railway] FILERISE_ADMIN_USER is not a valid FileRise user name\n");
    exit(2);
}
if (strlen($pass) < 12) {
    fwrite(STDERR, "[railway] FILERISE_ADMIN_PASSWORD is missing or shorter than 12 characters; refusing to start with an open setup page\n");
    exit(3);
}

if (!is_dir($usersDir) && !mkdir($usersDir, 0775, true)) {
    fwrite(STDERR, "[railway] cannot create $usersDir\n");
    exit(4);
}
$hash = password_hash($pass, PASSWORD_BCRYPT);
$nonce = bin2hex(random_bytes(6));
$tmp = $usersFile . '.tmp.' . $nonce;
if (file_put_contents($tmp, $user . ':' . $hash . ':1' . PHP_EOL, LOCK_EX) === false || !rename($tmp, $usersFile)) {
    @unlink($tmp);
    fwrite(STDERR, "[railway] could not write users.txt\n");
    exit(5);
}
$mtmp = $marker . '.tmp.' . $nonce;
if (file_put_contents($mtmp, json_encode(['completedAt' => time()]), LOCK_EX) === false || !rename($mtmp, $marker)) {
    @unlink($mtmp);
    fwrite(STDERR, "[railway] could not write the setup-complete marker\n");
    exit(6);
}
if (!hasUsers($usersFile, $userRegex)) {
    fwrite(STDERR, "[railway] admin bootstrap did not persist\n");
    exit(7);
}
fwrite(STDOUT, "[railway] created admin user '$user' from FILERISE_ADMIN_PASSWORD\n");
exit(0);
