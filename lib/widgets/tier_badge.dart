import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../models/business_tier.dart';

/// Visual styling for a [BusinessTier] badge. Kept in the widget layer so
/// the model stays pure Dart. Elite uses a violet that reads as "top of
/// the ladder" against the teal/orange brand.
extension TierBadgeStyle on BusinessTier {
  IconData get badgeIcon {
    switch (this) {
      case BusinessTier.listed:
        return Icons.storefront_outlined;
      case BusinessTier.spotlight:
        return Icons.star_border_rounded;
      case BusinessTier.prime:
        return Icons.star_rounded;
      case BusinessTier.elite:
        return Icons.workspace_premium_rounded;
    }
  }

  Color get badgeColor {
    switch (this) {
      case BusinessTier.listed:
        return AppColors.text4;
      case BusinessTier.spotlight:
        return AppColors.teal;
      case BusinessTier.prime:
        return AppColors.orange;
      case BusinessTier.elite:
        return const Color(0xFF7C3AED);
    }
  }
}

/// A small status badge for a membership level.
///
/// Renders nothing for [BusinessTier.listed] (the free floor has no
/// badge). Use [compact] for a tight icon-only chip on dense cards; the
/// default shows icon + label.
class TierBadge extends StatelessWidget {
  final BusinessTier tier;
  final bool compact;

  const TierBadge({super.key, required this.tier, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!tier.hasBadge) return const SizedBox.shrink();
    final color = tier.badgeColor;

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(tier.badgeIcon, size: 12, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.badgeIcon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            tier.label,
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
