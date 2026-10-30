<?php

/*
| Copies the PickSell website's database layout into database/schema/sqlite-schema.sql, which the
| tests load so they run against exactly the tables the app shares with the website.
|
| Re-run it whenever the website adds or changes migrations:
|
|   php scripts/sync-website-schema.php C:\projects\PickSell\PickSell
|
| It runs the website's migrations into a throwaway SQLite file (nothing else is touched), then
| writes every table and index plus the migration records.
*/

[$self, $website] = $argv + [null, null];
if (! $website || ! is_file($website.'/artisan')) {
    fwrite(STDERR, "Usage: php scripts/sync-website-schema.php <path to the PickSell website project>\n");
    exit(1);
}

$db = tempnam(sys_get_temp_dir(), 'picksell-schema-');
$env = [
    'APP_ENV' => 'local',
    'APP_KEY' => 'base64:'.base64_encode(random_bytes(32)),
    'DB_CONNECTION' => 'sqlite',
    'DB_DATABASE' => $db,
    'CACHE_STORE' => 'array',
    'SESSION_DRIVER' => 'array',
];
$process = proc_open([PHP_BINARY, 'artisan', 'migrate', '--force', '--no-interaction'], [1 => STDOUT, 2 => STDERR], $pipes, $website, $env + getenv());
if (proc_close($process) !== 0) {
    fwrite(STDERR, "The website's migrations failed; schema not updated.\n");
    exit(1);
}

$pdo = new PDO('sqlite:'.$db);
$sql = [];
foreach ($pdo->query("select sql from sqlite_master where sql is not null and name not like 'sqlite_%' order by case type when 'table' then 0 when 'index' then 1 else 2 end, name") as $row) {
    $sql[] = $row['sql'].';';
}
foreach ($pdo->query('select migration, batch from migrations order by id') as $row) {
    $sql[] = sprintf("INSERT INTO migrations (migration, batch) VALUES ('%s', %d);", str_replace("'", "''", $row['migration']), $row['batch']);
}
// This app's own migration records (config/database.php `migrations.table`).
$sql[] = 'CREATE TABLE "mobile_api_migrations" ("id" integer primary key autoincrement not null, "migration" varchar not null, "batch" integer not null);';
$pdo = null;
@unlink($db);

$out = dirname(__DIR__).'/database/schema/sqlite-schema.sql';
file_put_contents($out, implode("\n", $sql)."\n");
echo 'Wrote '.count($sql)." statements to {$out}\n";
