<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Buyer registration no longer collects sex/address up front;
            // the address is captured later through the Address Manager.
            $table->enum('sex', ['Male', 'Female'])->nullable()->change();
            $table->string('province')->nullable()->change();
            $table->string('municipality')->nullable()->change();
            $table->string('barangay')->nullable()->change();

            // Six-digit email verification code (stored hashed).
            $table->string('email_verification_code')->nullable()->after('email_verified_at');
            $table->timestamp('email_verification_expires_at')->nullable()->after('email_verification_code');
            $table->timestamp('email_verification_sent_at')->nullable()->after('email_verification_expires_at');
            $table->unsignedTinyInteger('email_verification_attempts')->default(0)->after('email_verification_sent_at');

            $table->timestamp('terms_accepted_at')->nullable()->after('email_verification_attempts');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'email_verification_code', 'email_verification_expires_at',
                'email_verification_sent_at', 'email_verification_attempts',
                'terms_accepted_at',
            ]);

            $table->enum('sex', ['Male', 'Female'])->nullable(false)->change();
            $table->string('province')->nullable(false)->change();
            $table->string('municipality')->nullable(false)->change();
            $table->string('barangay')->nullable(false)->change();
        });
    }
};
