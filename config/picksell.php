<?php

// Marketplace rules used by the mobile buyer API. Fees are per seller
// parcel; adjust here (or via env) rather than in code.
return [

    'shipping_options' => [
        ['code' => 'standard', 'name' => 'Picksell Standard', 'fee' => 45.00,  'min_days' => 3, 'max_days' => 5,  'official' => true],
        ['code' => 'express',  'name' => 'Picksell Express',  'fee' => 120.00, 'min_days' => 1, 'max_days' => 2,  'official' => true],
        ['code' => 'economy',  'name' => 'Economy (Sea)',     'fee' => 30.00,  'min_days' => 8, 'max_days' => 13, 'official' => false],
    ],

    // Flat platform fee per checkout. 0 hides the row in the app.
    'service_fee' => (float) env('PICKSELL_SERVICE_FEE', 0),

    'commission_rate' => 0.10,

    // Only Cash on Delivery is live; the others show as "Coming soon".
    'payment_methods' => [
        ['code' => 'cod',   'name' => 'Cash on Delivery',     'description' => 'Pay when you receive your order', 'available' => true],
        ['code' => 'gcash', 'name' => 'GCash',                'description' => 'Pay using your GCash wallet',     'available' => false],
        ['code' => 'maya',  'name' => 'Maya',                 'description' => 'Digital banking made easy',       'available' => false],
        ['code' => 'card',  'name' => 'Credit / Debit Card',  'description' => 'Visa, Mastercard, or JCB',        'available' => false],
    ],

    'return_window_days' => 7,

    // Highest quantity of one product a buyer can put in a single order.
    'max_quantity_per_item' => 10,
];
