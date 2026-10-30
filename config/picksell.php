<?php

/*
| Buyer mobile API settings. Business rules (pricing, order steps, returns) come from the Picksell
| website, which shares this database; anything here only shapes what the app shows.
*/
return [
    // The website offers Cash on Delivery only.
    'payment_methods' => [
        ['code' => 'cod', 'name' => 'Cash on Delivery', 'description' => 'Pay in cash when you receive your order', 'available' => true],
    ],

    // Category chips on the shop home; the same fixed list the website shows, plus any category in use.
    'home_categories' => ['Beauty', 'Books', 'Clothing', 'Electronics', 'Fashion', 'Food & Grocery', 'Home & Living', 'Pet Supplies', 'Sports', 'Toys'],

    // Reasons offered when a buyer cancels; saved as the cancellation reason in the order history.
    'cancel_reasons' => [
        'Need to change delivery address', 'Need to change the variation or quantity',
        'Found a better price elsewhere', 'Ordered by mistake', 'Other',
    ],

    // "Report a problem" categories; each report becomes a complaint on the website's Complaints page.
    'report_categories' => ['Damaged Item', 'Missing Item', 'Wrong Item', 'Quality Issue', 'Delivery Delay', 'Other'],
];
