<?php

namespace App\Services;

use RuntimeException;

/** The money movement was already recorded (same idempotency key). */
class DuplicatePosting extends RuntimeException
{
    public function __construct(public readonly string $key)
    {
        parent::__construct("Already recorded: {$key}");
    }
}
