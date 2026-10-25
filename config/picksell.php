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

        // Rider pay (riders treated as independent contractors — an
        // operational assumption, not a legal determination). Accrues only
        // when status is 'active'; 'proposed' shows the rates without paying.
        // Amounts in pesos; see documentation/finance-returns-payouts.md.
        'rider_pay' => [
            'status'            => env('PICKSELL_RIDER_PAY_STATUS', 'unconfigured'), // unconfigured | proposed | active
            'base_per_stop'     => env('PICKSELL_RIDER_PAY_BASE_PER_STOP'),          // first parcel delivered at an address
            'additional_parcel' => env('PICKSELL_RIDER_PAY_ADDITIONAL_PARCEL'),      // each extra parcel, same address, same day
            'failed_attempt'    => env('PICKSELL_RIDER_PAY_FAILED_ATTEMPT'),         // per failed attempt; unset = 0
            // Extra pay by delivery municipality or province, e.g. ['Antipolo' => '20.00'].
            'zone_adjustments'  => [],
        ],

        // RR 16-2023: 1% creditable withholding on one-half of gross
        // remittances to sellers. Off until per-seller exemptions (sworn
        // declarations, the ₱500,000 threshold) are tracked — ask your accountant.
        'withholding' => [
            'enabled' => (bool) env('PICKSELL_WITHHOLDING_ENABLED', false),
            'rate'    => '0.01',
            'base'    => '0.5',
        ],

        // Require a different admin to approve a payout than the one who
        // created it, for payouts at or above the threshold (pesos; 0 = all).
        'payout_requires_second_admin' => (bool) env('PICKSELL_PAYOUT_SECOND_ADMIN', false),
        'second_admin_threshold'       => env('PICKSELL_PAYOUT_SECOND_ADMIN_THRESHOLD', '0'),
    ],

    /*
    | Returns. Change-of-mind returns follow the published return window;
    | defect claims (DTI: repair, replacement or refund) get a longer window.
    | These are operational defaults to confirm with counsel, not legal limits.
    */
    'returns' => [
        'defect_claim_days' => (int) env('PICKSELL_DEFECT_CLAIM_DAYS', 60),
        'defect_reasons'    => ['Damaged or defective item', 'Wrong item received', 'Item not as described', 'Missing parts or accessories'],

        // Presumed responsible party by reason; admin confirms or changes it.
        'presumed_liability' => [
            'Damaged or defective item'    => 'seller',
            'Wrong item received'          => 'seller',
            'Item not as described'        => 'seller',
            'Missing parts or accessories' => 'seller',
            'Changed my mind'              => 'buyer',
        ],

        // Who funds an approved refund, by responsible party. A buyer-caused
        // return only gets a refund the seller agreed to, so the seller funds it.
        // Courier damage is funded by Picksell and recovered from logistics
        // separately; the rider who hands over the cash is never charged.
        'refund_funded_by' => [
            'seller'    => 'seller',
            'buyer'     => 'seller',
            'logistics' => 'platform',
            'platform'  => 'platform',
        ],
    ],

    'delivery' => [
        // After this many failed attempts the parcel goes back to the seller.
        'max_attempts'   => (int) env('PICKSELL_MAX_DELIVERY_ATTEMPTS', 3),
        'failed_reasons' => [
            'Buyer not available', 'Buyer refused the parcel', 'Wrong or incomplete address',
            'Buyer could not be contacted', 'Buyer could not pay the COD amount', 'Unsafe to deliver', 'Other',
        ],
    ],

    // Highest quantity of one product a buyer can put in a single order.
    'max_quantity_per_item' => 10,
];
