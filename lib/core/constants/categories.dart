/// Single source of truth for the allowed category list.
///
/// Keep this list short and product-driven — it's used everywhere:
///   - Add/Edit product dropdown
///   - Business setup / edit dropdown
///   - Customer home category grouping (only these render as sections)
///   - Search filters
abstract class AppCategories {
  static const List<String> all = [
    'Clothing',
    'Food & Drink',
    'Grocery',
    'Electronics',
    'Home & Living',
    'Beauty & Wellness',
    'Jewellery',
    'Services',
    'Sports & Outdoors',
    'Stationery & Books',
    'Toys & Kids',
    'Other',
  ];

  static bool isAllowed(String s) => all.contains(s);

  /// Case-insensitive lookup; unknown / empty → 'Other'.
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Other';
    for (final c in all) {
      if (c.toLowerCase() == trimmed.toLowerCase()) return c;
    }
    return 'Other';
  }
}
