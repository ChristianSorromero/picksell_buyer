import 'product.dart';

/// Hardcoded products for the dashboard + product page template.
/// Replace with data from your API later.
const List<Product> sampleProducts = [
  Product(
    id: 1,
    name: 'Waterproof Daily Backpack',
    category: 'Fashion',
    price: 899,
    originalPrice: 1299,
    sellerName: 'Urban Store',
    sellerLocation: 'Quezon City, Metro Manila',
    rating: 4.8,
    soldCount: 1200,
    stock: 24,
    description:
        'Lightweight water-resistant backpack with a padded laptop sleeve, '
        'hidden anti-theft pocket and breathable back panel. Perfect for '
        'school, work and everyday commuting.',
    variantGroups: [
      ProductVariantGroup(name: 'Color', options: ['Yellow', 'Black', 'Navy']),
      ProductVariantGroup(name: 'Size', options: ['Regular', 'Large']),
    ],
  ),
  Product(
    id: 2,
    name: 'Classic White Sneakers',
    category: 'Fashion',
    price: 2450,
    originalPrice: 2999,
    sellerName: 'Shoe Hub',
    sellerLocation: 'Makati, Metro Manila',
    rating: 4.9,
    soldCount: 3500,
    stock: 8,
    description:
        'Clean low-top sneakers with a cushioned insole and durable rubber '
        'outsole. Easy to style with anything in your wardrobe.',
    variantGroups: [
      ProductVariantGroup(name: 'Color', options: ['White', 'Cream']),
      ProductVariantGroup(
        name: 'Size',
        options: ['38', '39', '40', '41', '42', '43'],
      ),
    ],
  ),
  Product(
    id: 3,
    name: 'Oversized Cotton Hoodie',
    category: 'Fashion',
    price: 799,
    sellerName: 'Thread & Co',
    sellerLocation: 'Cebu City, Cebu',
    rating: 4.7,
    soldCount: 860,
    stock: 42,
    description:
        'Soft heavyweight cotton hoodie with a relaxed oversized fit and '
        'front kangaroo pocket.',
    variantGroups: [
      ProductVariantGroup(name: 'Color', options: ['Rose', 'Gray', 'Black']),
      ProductVariantGroup(name: 'Size', options: ['S', 'M', 'L', 'XL']),
    ],
  ),
  Product(
    id: 4,
    name: 'Trail Running Cap',
    category: 'Fashion',
    price: 349,
    sellerName: 'Urban Store',
    sellerLocation: 'Quezon City, Metro Manila',
    rating: 4.6,
    soldCount: 420,
    stock: 60,
    description: 'Quick-dry cap with an adjustable strap and reflective trim.',
    variantGroups: [
      ProductVariantGroup(name: 'Color', options: ['Black', 'Olive', 'Sand']),
    ],
  ),
  Product(
    id: 5,
    name: 'Wireless Headphones',
    category: 'Electronics',
    price: 1899,
    originalPrice: 2499,
    sellerName: 'Tech Hub',
    sellerLocation: 'Pasig, Metro Manila',
    rating: 4.6,
    soldCount: 2100,
    stock: 15,
    description:
        'Bluetooth 5.3 over-ear headphones with active noise reduction and '
        'up to 40 hours of playtime.',
    variantGroups: [
      ProductVariantGroup(name: 'Color', options: ['Black', 'White']),
    ],
  ),
  Product(
    id: 6,
    name: 'Smartwatch Series X',
    category: 'Electronics',
    price: 3299,
    sellerName: 'Gadget Central',
    sellerLocation: 'Davao City, Davao del Sur',
    rating: 4.5,
    soldCount: 640,
    stock: 5,
    description:
        'Fitness smartwatch with heart-rate tracking, sleep monitoring and a '
        'bright AMOLED display.',
    variantGroups: [
      ProductVariantGroup(name: 'Strap', options: ['Black', 'Silver', 'Rose']),
    ],
  ),
  Product(
    id: 7,
    name: 'Pro Basketball',
    category: 'Sports',
    price: 1250,
    sellerName: 'Sports Depot',
    sellerLocation: 'Laguna',
    rating: 4.8,
    soldCount: 980,
    stock: 30,
    description: 'Indoor/outdoor composite leather basketball with deep channels.',
    variantGroups: [
      ProductVariantGroup(name: 'Size', options: ['6', '7']),
    ],
  ),
  Product(
    id: 8,
    name: 'Minimalist Desk Lamp',
    category: 'Home',
    price: 649,
    sellerName: 'Home Nest',
    sellerLocation: 'Calamba, Laguna',
    rating: 4.7,
    soldCount: 430,
    stock: 0, // demo: out-of-stock state
    description: 'Dimmable LED desk lamp with touch control and USB charging.',
    variantGroups: [
      ProductVariantGroup(name: 'Color', options: ['White', 'Black']),
    ],
  ),
];
