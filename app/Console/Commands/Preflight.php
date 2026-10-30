<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Throwable;

/**
 * Release gate: checks this deployment's configuration against what
 * production needs. Exits 1 when any blocker is found. Read-only.
 *
 *   php artisan picksell:preflight
 */
class Preflight extends Command
{
    protected $signature = 'picksell:preflight';

    protected $description = 'Check production configuration before a release (read-only)';

    private int $blockers = 0;

    public function handle(): int
    {
        $this->line('<options=bold>Picksell production preflight</>');

        $this->section('Application');
        $this->check(config('app.env') === 'production', 'APP_ENV is production', 'APP_ENV is "' . config('app.env') . '"');
        $this->check(!config('app.debug'), 'APP_DEBUG is off', 'APP_DEBUG is on (exposes stack traces and config)');
        $this->check(filled(config('app.key')), 'APP_KEY is set', 'APP_KEY is missing');
        $url = (string) config('app.url');
        $this->check(str_starts_with($url, 'https://') && !$this->placeholder(parse_url($url, PHP_URL_HOST)),
            'APP_URL uses https', 'APP_URL is not a real https address (' . $url . ')');
        $this->check(config('app.timezone') === 'UTC', 'Timestamps are stored in UTC',
            'app.timezone is "' . config('app.timezone') . '": stored timestamps would be misread (use APP_DISPLAY_TIMEZONE instead)');
        $this->check(config('logging.channels.single.level', 'debug') !== 'debug',
            'Log level is not debug', 'LOG_LEVEL is debug (logs too much, may include personal data)');

        $this->section('Security');
        $this->check(filled(config('sanctum.expiration')), 'App tokens expire (' . config('sanctum.expiration') . ' min)', 'Sanctum tokens never expire');
        $dbUser = (string) config('database.connections.' . config('database.default') . '.username');
        $this->check($dbUser !== 'root', 'Database user is not root', 'Database user is root — use a least-privilege account');

        $this->section('Services');
        $this->check(!in_array(config('mail.default'), ['log', 'array'], true), 'Mail is sent (' . config('mail.default') . ')',
            'MAIL_MAILER is "' . config('mail.default') . '": verification and reset codes would never reach buyers');
        if (config('mail.default') === 'smtp') {
            $host = (string) config('mail.mailers.smtp.host');
            $this->check(!$this->placeholder($host), "SMTP server is {$host}", "MAIL_HOST is not a real mail server ({$host})");
        }
        $this->warnIf($this->placeholder(substr(strrchr((string) config('mail.from.address'), '@') ?: '', 1)),
            'MAIL_FROM_ADDRESS (' . config('mail.from.address') . ') is not on a real domain: mail may be rejected as spam');
        $this->warnIf(config('queue.default') === 'sync', 'QUEUE_CONNECTION is sync: emails are sent during the request; a slow mail server slows checkout and registration');
        // Uploads must land in the website's storage so admins and the website see the same files.
        $root = (string) config('filesystems.disks.public.root');
        $this->check(filled(env('PICKSELL_PUBLIC_STORAGE_ROOT')) && is_dir($root) && is_writable($root),
            "Shared storage is the website's folder ({$root})",
            'PICKSELL_PUBLIC_STORAGE_ROOT must be the website\'s storage/app/public folder, existing and writable (now: ' . $root . ')');
        $storageUrl = (string) config('filesystems.disks.public.url');
        $this->check(str_starts_with($storageUrl, 'https://'), "Files are served from {$storageUrl}",
            'PICKSELL_PUBLIC_STORAGE_URL should be the website\'s https /storage address (now: ' . $storageUrl . ')');

        $this->section('Database');
        try {
            DB::connection()->getPdo();
            $this->check(true, 'Database reachable (' . DB::connection()->getDriverName() . ')', '');
            if (in_array(DB::connection()->getDriverName(), ['mysql', 'mariadb'], true)) {
                $offset = (int) DB::selectOne('select timestampdiff(minute, utc_timestamp(), now()) as m')->m;
                $this->warnIf($offset !== 0, "MySQL session time zone is UTC{$this->signed($offset)}: set DB_TIMEZONE=+00:00 on a new database (an existing one's rows were written under the current setting)");
            }
            $ran = DB::table('migrations')->pluck('migration')->all();
            $pending = collect(glob(database_path('migrations/*.php')))->map(fn ($f) => basename($f, '.php'))->diff($ran)->values();
            $this->check($pending->isEmpty(), 'No pending migrations', $pending->count() . ' pending migration(s): ' . $pending->implode(', '));
            // Tables the website's migrations create; the app depends on all of them.
            $missing = collect(['users', 'products', 'product_images', 'carts', 'cart_items', 'orders', 'order_status_histories',
                'return_requests', 'return_request_events', 'product_reviews', 'messages', 'notifications', 'complaints',
                'wishlist_items', 'recently_viewed_products', 'personal_access_tokens'])->reject(fn ($table) => Schema::hasTable($table));
            $this->check($missing->isEmpty(), 'Website tables present',
                'Missing tables: ' . $missing->implode(', ') . ' — run the website\'s migrations (php artisan migrate in the PickSell project) first');
        } catch (Throwable $e) {
            $this->check(false, '', 'Database not reachable: ' . $e->getMessage());
        }

        $this->section('Business rules');
        $methods = collect(config('picksell.payment_methods'))->where('available', true)->pluck('code')->all();
        $this->check($methods === ['cod'], 'Cash on Delivery is the only payment method', 'Payment methods other than COD are enabled: ' . implode(', ', $methods));
        $this->info('  • Commission rate: ' . config('app.platform_commission_rate') . '% (must equal the website\'s PLATFORM_COMMISSION_RATE)');
        $this->info('  • Shown and scheduled in: ' . config('app.display_timezone') . ' / ' . config('app.schedule_timezone'));

        $this->newLine();
        if ($this->blockers > 0) {
            $this->error("{$this->blockers} blocker(s) found. Not ready for production.");
            return self::FAILURE;
        }
        $this->info('No blockers found. Review the warnings above before releasing.');
        return self::SUCCESS;
    }

    private function section(string $title): void
    {
        $this->newLine();
        $this->line("<fg=cyan>{$title}</>");
    }

    private function check(bool $ok, string $pass, string $fail): void
    {
        if ($ok) {
            $this->line("  <fg=green>✔</> {$pass}");
            return;
        }
        $this->blockers++;
        $this->line("  <fg=red>✘</> {$fail}");
    }

    /** Empty, local, or a template value still to be replaced. */
    private function placeholder(?string $host): bool
    {
        $host = strtolower((string) $host);
        return $host === '' || in_array($host, ['localhost', '127.0.0.1', '::1', '10.0.2.2'], true)
            || str_contains($host, 'change-me') || str_ends_with($host, '.local') || str_ends_with($host, '.example')
            || str_ends_with($host, '.invalid') || str_ends_with($host, '.test');
    }

    /** Minutes as an offset, e.g. +8:00. */
    private function signed(int $minutes): string
    {
        return ($minutes < 0 ? '-' : '+') . intdiv(abs($minutes), 60) . ':' . str_pad((string) (abs($minutes) % 60), 2, '0', STR_PAD_LEFT);
    }

    private function warnIf(bool $condition, string $message): void
    {
        if ($condition) $this->line("  <fg=yellow>!</> {$message}");
    }
}
