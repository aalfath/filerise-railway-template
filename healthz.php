<?php
// Railway health check: 200 only when the admin exists and the data volume is writable.
header('Content-Type: text/plain');
header('Cache-Control: no-store');
$users = @file_get_contents('/var/www/users/users.txt');
$ok = is_string($users) && preg_match('/^[^:\s][^:]*:[^:]+:[01]/m', $users) === 1
    && is_writable('/var/www/uploads') && is_writable('/var/www/metadata');
http_response_code($ok ? 200 : 503);
echo $ok ? "ok\n" : "not ready\n";
