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

/// Retail price label for a product. Vendors may withhold the price
/// (null, or legacy 0) — those render as "Ask for price" and the buyer's
/// pathway is the existing chat button. ALL product price display sites
/// must use this instead of interpolating `formatLkr` directly, so the
/// ask-for-price behavior stays consistent app-wide.
String productPriceLabel(double? priceLkr) =>
    (priceLkr == null || priceLkr <= 0)
        ? 'Ask for price'
        : 'LKR ${formatLkr(priceLkr)}';
