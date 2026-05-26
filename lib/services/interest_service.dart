import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which product categories a user shows interest in by recording
/// each product view's category. On refresh, the home screen uses this
/// data to prioritise categories and shuffle within them so the customer
/// sees fresh products first.
///
/// Interest scores are stored locally via SharedPreferences — no server
/// round-trip needed. Each category view increments a simple counter;
/// categories with higher counts appear earlier in the home feed.
///
/// Also tracks which product IDs have already been "shown" (appeared
/// prominently in the home feed) so refreshes can de-prioritise them
/// and surface un-shown products first.
class InterestService {
  static const _catKey = 'interest_category_counts_v1';
  static const _shownKey = 'interest_shown_product_ids_v1';
  static const int _maxShownIds = 200;

  // ── Category interest ──────────────────────────────────────────────

  /// Record that the user viewed a product in [category].
  Future<void> recordCategoryInterest(String category) async {
    if (category.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_catKey) ?? <String>[];
    final counts = _decodeCounts(raw);
    counts[category] = (counts[category] ?? 0) + 1;
    await prefs.setStringList(_catKey, _encodeCounts(counts));
  }

  /// Returns categories ranked by interest (most-viewed first).
  Future<List<String>> rankedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_catKey) ?? <String>[];
    final counts = _decodeCounts(raw);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  /// Returns the raw interest counts map.
  Future<Map<String, int>> interestCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_catKey) ?? <String>[];
    return _decodeCounts(raw);
  }

  // ── Shown-products tracking ────────────────────────────────────────

  /// Mark product IDs as having been shown prominently on the home feed.
  Future<void> markShown(List<String> productIds) async {
    if (productIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_shownKey) ?? <String>[];
    final set = current.toSet()..addAll(productIds);
    final trimmed = set.toList();
    if (trimmed.length > _maxShownIds) {
      trimmed.removeRange(0, trimmed.length - _maxShownIds);
    }
    await prefs.setStringList(_shownKey, trimmed);
  }

  /// Returns the set of product IDs previously shown.
  Future<Set<String>> shownProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_shownKey) ?? <String>[]).toSet();
  }

  /// Clears shown-products history so every product is "fresh" again.
  Future<void> clearShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shownKey);
  }

  // ── Codec ──────────────────────────────────────────────────────────
  // Stored as ["category:count", …] so SharedPreferences can persist it
  // without pulling in dart:convert for JSON.

  Map<String, int> _decodeCounts(List<String> raw) {
    final map = <String, int>{};
    for (final entry in raw) {
      final idx = entry.lastIndexOf(':');
      if (idx < 0) continue;
      final cat = entry.substring(0, idx);
      final count = int.tryParse(entry.substring(idx + 1)) ?? 0;
      map[cat] = count;
    }
    return map;
  }

  List<String> _encodeCounts(Map<String, int> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').toList();
  }
}
