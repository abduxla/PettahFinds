import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local store of recently viewed product IDs.
/// Newest first, capped to [maxItems], de-duplicated.
class RecentlyViewedService {
  static const _key = 'recently_viewed_product_ids_v1';
  static const int maxItems = 10;

  Future<List<String>> getIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> record(String productId) async {
    if (productId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.removeWhere((id) => id == productId);
    current.insert(0, productId);
    if (current.length > maxItems) {
      current.removeRange(maxItems, current.length);
    }
    await prefs.setStringList(_key, current);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
