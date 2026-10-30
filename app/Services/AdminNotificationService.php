<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Str;

class AdminNotificationService
{
    public const TYPE = 'App\\Notifications\\AdminActivity';

    /**
     * @param  string|null  $subject  what the alert is about (e.g. "registration:12"). An unread alert for the
     *                                same event and subject is refreshed instead of duplicated, and resolve()
     *                                clears it once someone acts on that subject.
     */
    public function notifyAdmins(
        string $event,
        string $title,
        string $message,
        string $url,
        ?int $exceptActorId = null,
        string $priority = 'normal',
        ?string $subject = null,
    ): void
    {
        $payload = array_filter([
            'event' => $event,
            'subject' => $subject,
            'title' => $title,
            'message' => $message,
            'url' => $url,
            'priority' => $priority,
        ], fn ($value) => $value !== null);

        User::query()
            ->where('role', 'admin')
            ->where('status', 'approved')
            ->when($exceptActorId, fn ($query) => $query->whereKeyNot($exceptActorId))
            ->orderBy('id')
            ->each(function (User $admin) use ($payload, $event, $subject): void {
                $existing = null;
                if ($subject !== null) {
                    $query = $admin->unreadNotifications()->where('type', self::TYPE)->getQuery();
                    self::whereData($query, 'event', $event);
                    self::whereData($query, 'subject', $subject);
                    $existing = $query->first();
                }

                if ($existing) {
                    $existing->forceFill(['data' => $payload, 'created_at' => now(), 'updated_at' => now()])->save();

                    return;
                }

                $admin->notifications()->create([
                    'id' => (string) Str::uuid(),
                    'type' => self::TYPE,
                    'data' => $payload,
                ]);
            });
    }

    /** Marks every admin's unread alerts about $subject as read once the underlying item has been handled. */
    public function resolve(string $subject): void
    {
        $query = DatabaseNotification::query()->where('type', self::TYPE)->whereNull('read_at');
        self::whereData($query, 'subject', $subject);
        $query->update(['read_at' => now()]);
    }

    /**
     * Constrains the text `data` column to rows whose JSON has $key equal to $value (or starting with it when
     * $prefix is set). Older rows were stored JSON-encoded twice, so both encodings are matched. The pattern
     * uses an explicit escape character so backslashes stay literal on MySQL, PostgreSQL and SQLite alike.
     */
    public static function whereData(Builder $query, string $key, string $value, bool $prefix = false, string $boolean = 'and'): Builder
    {
        $plain = substr(json_encode([$key => $value], JSON_THROW_ON_ERROR), 1, $prefix ? -2 : -1);
        $doubled = substr(json_encode($plain, JSON_THROW_ON_ERROR), 1, -1);
        $like = fn (string $needle) => '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $needle).'%';

        return $query->where(fn (Builder $q) => $q
            ->whereRaw("data like ? escape '!'", [$like($plain)])
            ->orWhereRaw("data like ? escape '!'", [$like($doubled)]), boolean: $boolean);
    }
}
