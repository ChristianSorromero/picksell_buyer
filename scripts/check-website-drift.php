<?php

/*
| Lists where this API's copies of the website's buyer rules differ from the website's own code
| (comments, imports, namespaces and whitespace are ignored). The order rules must stay identical
| on both sides, or an order moves differently depending on which server touched it.
|
|   php scripts/check-website-drift.php C:\projects\Picksell
|
| Exit code 1 when a rule differs. Read-only.
*/

[$self, $website] = $argv + [null, null];
if (! $website || ! is_file($website.'/artisan')) {
    fwrite(STDERR, "Usage: php scripts/check-website-drift.php <path to the PickSell website project>\n");
    exit(2);
}
$here = dirname(__DIR__);

// website file => [this project's file, methods to compare (null = whole class)]
$rules = [
    'app/Services/Orders/OrderLifecycleService.php' => ['app/Services/Orders/OrderLifecycleService.php', null],
    'app/Services/Orders/OrderCancellationService.php' => ['app/Services/Orders/OrderCancellationService.php', null],
    'app/Services/OrderPlacement.php' => ['app/Services/OrderPlacement.php', null],
    'app/Services/CartQuote.php' => ['app/Services/CartQuote.php', null],
    'app/Models/Order.php' => ['app/Models/Order.php', ['booted', 'recordStatusChange']],
];
// The website's port of this API (routes/buyer-api.php), when it has one.
$apiPort = [
    'app/Support/BuyerApi/OrderStatus.php' => ['app/Support/OrderStatus.php', null],
    'app/Support/BuyerApi/BuyerPresenter.php' => ['app/Support/BuyerPresenter.php', null],
];
foreach (glob($here.'/app/Http/Controllers/Api/*.php') as $file) {
    $apiPort['app/Http/Controllers/BuyerApi/'.basename($file)] = ['app/Http/Controllers/Api/'.basename($file), null];
}
if (is_dir($website.'/app/Http/Controllers/BuyerApi')) {
    $rules += $apiPort;
}

function code(string $path, ?array $methods): ?string
{
    if (! is_file($path)) {
        return null;
    }
    $out = '';
    foreach (token_get_all(file_get_contents($path)) as $t) {
        if (is_array($t) && in_array($t[0], [T_COMMENT, T_DOC_COMMENT], true)) {
            continue;
        }
        $out .= is_array($t) ? $t[1] : $t;
    }
    // The website's port keeps this API's settings in config/buyer-api.php; here they are config/picksell.php.
    $out = preg_replace(['/^\s*(namespace|use)\s+[^;{]+;\s*$/m', "/config\\('buyer-api\\./", '/\s+/'], ['', "config('picksell.", ' '], $out);
    if ($methods === null) {
        return trim($out);
    }
    $parts = [];
    foreach ($methods as $m) {
        $start = preg_match('/function\s+'.$m.'\s*\(/', $out, $hit, PREG_OFFSET_CAPTURE) ? $hit[0][1] : null;
        if ($start === null) {
            $parts[] = "<missing {$m}>";
            continue;
        }
        $depth = 0;
        for ($i = strpos($out, '{', $start); $i < strlen($out); $i++) {
            $depth += $out[$i] === '{' ? 1 : ($out[$i] === '}' ? -1 : 0);
            if ($depth === 0) {
                break;
            }
        }
        $parts[] = substr($out, $start, $i - $start + 1);
    }

    return implode("\n", $parts);
}

$differs = 0;
foreach ($rules as $theirs => [$ours, $methods]) {
    $a = code($website.'/'.$theirs, $methods);
    $b = code($here.'/'.$ours, $methods);
    if ($a === $b) {
        echo "same     {$ours}".($methods ? ' ('.implode(', ', $methods).')' : '')."\n";
        continue;
    }
    $differs++;
    if ($a === null || $b === null) {
        echo 'MISSING  '.($a === null ? "website {$theirs}" : "here {$ours}")."\n";
        continue;
    }
    // First differing stretch, for a quick look.
    $i = strspn($a ^ $b, "\0");
    echo "DIFFERS  {$ours}\n         website: …".substr($a, max(0, $i - 40), 120)."…\n         here:    …".substr($b, max(0, $i - 40), 120)."…\n";
}
echo $differs ? "{$differs} file(s) differ.\n" : "All shared rules match.\n";
exit($differs ? 1 : 0);
