<?php

use Illuminate\Support\Facades\Route;

// This server only serves the buyer mobile app's API (/api/...). The website is the Picksell project.
Route::get('/', fn () => response()->json([
    'name' => 'PickSell buyer app API',
    'website' => 'https://pick-sell.shop',
]));
