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

    // Cash on Delivery is the only payment method: no payment gateway is
    // integrated, so cashless methods are not offered anywhere.
    'payment_methods' => [
        ['code' => 'cod', 'name' => 'Cash on Delivery', 'description' => 'Pay in cash when you receive your order', 'available' => true],
    ],

    // Approved refunds are paid in cash by a rider, the reverse of delivery.
    'refund_methods' => [
        ['code' => 'cash', 'name' => 'Cash, handed over by a Picksell rider'],
    ],

    'return_window_days' => 7,

    /*
    | Settlement and payouts (see documentation/finance-returns-payouts.md). Amounts are pesos and
    | are converted to integer centavos; nothing here moves money by itself,
    | payouts are recorded manually by an admin after the real transfer.
    */
    'finance' => [
        // Seller payouts cover settlements up to the end of the last full
        // period: 'weekly' (Mon–Sun) or 'daily'.
        'payout_period' => env('PICKSELL_PAYOUT_PERIOD', 'weekly'),

        // Who funds platform vouchers: 'platform' (seller is credited the
        // pre-discount price) or 'seller'. Store vouchers are always seller-funded.
        'platform_voucher_funded_by' => env('PICKSELL_PLATFORM_VOUCHER_FUNDED_BY', 'platform'),

        // Rider pay per successful delivery, in pesos. Not set = no rider
        // compensation is accrued (reported as "policy not configured").
        'rider_fee_per_delivery' => env('PICKSELL_RIDER_FEE_PER_DELIVERY'),

        // RR 16-2023: 1% creditable withholding on one-half of gross
        // remittances to sellers. Off until per-seller exemptions (sworn
        // declarations, the ₱500,000 threshold) are tracked — ask your accountant.
        'withholding' => [
            'enabled' => (bool) env('PICKSELL_WITHHOLDING_ENABLED', false),
            'rate'    => '0.01',
            'base'    => '0.5',
        ],

        // Require a different admin to approve a payout than the one who created it.
        'payout_requires_second_admin' => (bool) env('PICKSELL_PAYOUT_SECOND_ADMIN', false),
    ],

    // Highest quantity of one product a buyer can put in a single order.
    'max_quantity_per_item' => 10,
];
