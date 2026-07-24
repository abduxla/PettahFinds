import 'package:intl/intl.dart';

/// Single site-wide LKR formatter.
///
/// Always renders with comma thousands separators and zero decimal
/// places (LKR is a "no-cents-in-everyday-quotes" currency for retail
/// listings in this app — wholesale + retail prices are stored as
/// doubles but always displayed as whole rupees). Negative values
/// pass through unchanged because nothing in the data model is
/// expected to be negative; if one ever appears it'll render as
/// `-1,234` which is still parseable to a reader.
///
/// Usage:
///   Text('LKR ${formatLkr(product.priceLkr)}')
///
/// DO NOT roll a new helper in another file — the goal is one
/// formatting source so any future change (e.g. add cents for
/// some category) only edits this one spot.
final NumberFormat _priceFormatter = NumberFormat('#,###');

String formatLkr(num amount) => _priceFormatter.format(amount);

/// The label shown when a vendor withholds the retail price (null, or a
/// legacy 0). "Contact for price" is deliberately professional and
/// action-oriented — it reads like a considered wholesale quote rather
/// than "Ask for price" (which sounded tentative), and it points the
/// buyer at the chat button that is the actual pathway. Single constant
/// so the wording only ever lives in one place.
const String priceOnRequestLabel = 'Contact for price';

/// Retail price label for a product. Vendors may withhold the price
/// (null, or legacy 0) — those render as [priceOnRequestLabel] and the
/// buyer's pathway is the existing chat button. When a selling [unit] is
/// set (e.g. "Meter"), the price reads "LKR 950 / Meter". ALL product
/// price display sites must use this instead of interpolating `formatLkr`
/// directly, so price-on-request and per-unit pricing stay consistent
/// app-wide.
String productPriceLabel(double? priceLkr, {String unit = ''}) {
  if (priceLkr == null || priceLkr <= 0) return priceOnRequestLabel;
  final u = unit.trim();
  return u.isEmpty ? 'LKR ${formatLkr(priceLkr)}' : 'LKR ${formatLkr(priceLkr)} / $u';
}
