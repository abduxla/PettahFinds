import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business_tier.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/tier_badge.dart';

/// The seller-facing "Your level" screen.
///
/// Deliberately shows ONLY the business's *current* level and what it
/// includes — framed as earned status. There is intentionally no price,
/// no "upgrade" button, no comparison of other levels, and no link out.
/// Any paid arrangement happens entirely off-app; this screen never hints
/// at it. (See [BusinessTier] for the rationale.)
class MembershipLevelScreen extends ConsumerWidget {
  const MembershipLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text(
          'Your level',
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: businessAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserBusinessProvider),
        ),
        data: (business) {
          if (business == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Set up your business first to see your level.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final tier = business.effectiveTier;
          final productsAsync = ref.watch(businessProductsProvider(business.id));
          final activeCount = productsAsync.valueOrNull
                  ?.where((p) => p.isActive)
                  .length ??
              0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _HeroCard(
                tier: tier,
                validUntil: business.tierValidUntil,
              ),
              const SizedBox(height: 14),
              _UsageCard(activeCount: activeCount, tier: tier),
              const SizedBox(height: 14),
              _PerksCard(tier: tier),
              const SizedBox(height: 18),
              Text(
                'Your level reflects your verification, listing quality, '
                'customer ratings, and how actively you engage with buyers.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.text3,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final BusinessTier tier;
  final DateTime? validUntil;
  const _HeroCard({required this.tier, required this.validUntil});

  @override
  Widget build(BuildContext context) {
    final color = tier.badgeColor;
    final statusLine = tier.isPaid && validUntil != null
        ? 'Active until ${MaterialLocalizations.of(context).formatShortDate(validUntil!)}'
        : 'Your shop is live on PetaFinds';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(tier.badgeIcon, size: 32, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            "You're on",
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: AppColors.text3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'PetaFinds ${tier.label}',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.text1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusLine,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: AppColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final int activeCount;
  final BusinessTier tier;
  const _UsageCard({required this.activeCount, required this.tier});

  @override
  Widget build(BuildContext context) {
    final cap = tier.listingCap;
    final ratio = cap > 0 ? (activeCount / cap).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Active listings',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text1,
                ),
              ),
              const Spacer(),
              Text(
                '$activeCount / ${tier.listingCapLabel}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: tier == BusinessTier.elite ? null : ratio,
              minHeight: 8,
              backgroundColor: AppColors.bgSection,
              valueColor: AlwaysStoppedAnimation(tier.badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerksCard extends StatelessWidget {
  final BusinessTier tier;
  const _PerksCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "What's included",
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text1,
                ),
              ),
              const Spacer(),
              TierBadge(tier: tier),
            ],
          ),
          const SizedBox(height: 12),
          for (final perk in tier.perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 17, color: tier.badgeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      perk,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: AppColors.text2,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
