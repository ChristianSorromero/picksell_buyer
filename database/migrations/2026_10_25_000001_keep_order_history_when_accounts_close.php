<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Closing an account anonymises the user row instead of deleting it, so
 * orders, returns and complaints that point at it keep their history.
 * The foreign keys now refuse a hard delete rather than cascading it.
 * Also adds the 'deactivated' status the admin users page already sets.
 */
return new class extends Migration
{
    private const KEYS = [
        'orders'          => ['buyer_id', 'seller_id'],
        'return_requests' => ['buyer_id'],
        'complaints'      => ['filed_by'],
    ];

    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->enum('status', ['pending', 'approved', 'disapproved', 'suspended', 'deactivated'])->default('pending')->change();
            $table->timestamp('anonymized_at')->nullable();
        });

        $this->rebuildKeys(fn ($foreign) => $foreign->restrictOnDelete());
    }

    public function down(): void
    {
        $this->rebuildKeys(fn ($foreign) => $foreign->cascadeOnDelete());

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('anonymized_at');
            $table->enum('status', ['pending', 'approved', 'disapproved', 'suspended'])->default('pending')->change();
        });
    }

    private function rebuildKeys(callable $onDelete): void
    {
        foreach (self::KEYS as $tableName => $columns) {
            Schema::table($tableName, function (Blueprint $table) use ($columns, $onDelete) {
                foreach ($columns as $column) {
                    $table->dropForeign([$column]);
                    $onDelete($table->foreign($column)->references('id')->on('users'));
                }
            });
        }
    }
};
