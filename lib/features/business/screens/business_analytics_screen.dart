import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business_stats.dart';
import '../../../models/business_tier.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/tier_badge.dart';

/// Seller analytics — customer engagement totals for the shop.
///
/// Gated to levels with [BusinessTier.hasAnalytics] (Prime / Elite). Lower
/// levels see a tasteful locked preview that names which levels include it
/// — status framing only, with no price, no "upgrade" button, and no link
/// out, consistent with the rest of the membership surface.
class BusinessAnalyticsScreen extends ConsumerWidget {
  const BusinessAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text(
          'Analytics',
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
                  'Set up your business first to see analytics.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final tier = business.effectiveTier;
          if (!tier.hasAnalytics) {
            return const _LockedAnalytics();
          }

          final statsAsync = ref.watch(businessStatsProvider(business.id));
          return statsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => AppErrorWidget(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(businessStatsProvider(business.id)),
            ),
            data: (stats) => _AnalyticsBody(stats: stats, tier: tier),
          );
        },
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  final BusinessStats stats;
  final BusinessTier tier;
  const _AnalyticsBody({required this.stats, required this.tier});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _TotalCard(total: stats.totalEngagements, tier: tier),
        const SizedBox(height: 14),
        _StatCard(
          icon: Icons.storefront_rounded,
          label: 'Shop profile views',
          value: stats.profileViews,
          color: AppColors.teal,
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.inventory_2_rounded,
          label: 'Product views',
          value: stats.productViews,
          color: AppColors.orange,
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.chat_bubble_rounded,
          label: 'Chats started',
          value: stats.chatsStarted,
          color: const Color(0xFF7C3AED),
        ),
        const SizedBox(height: 18),
        Text(
          'Totals since analytics became available on your shop. Numbers '
          'update live as customers browse.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            height: 1.5,
            color: AppColors.text3,
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final int total;
  final BusinessTier tier;
  const _TotalCard({required this.total, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Total customer engagements',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: AppColors.text3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              TierBadge(tier: tier, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$total',
            style: GoogleFonts.nunito(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppColors.text1,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool locked;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text1,
              ),
            ),
          ),
          if (locked)
            const Icon(Icons.lock_outline_rounded,
                size: 20, color: AppColors.text4)
          else
            Text(
              '$value',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.text1,
                letterSpacing: -0.5,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown to levels without analytics. Names the levels that include it
/// (status info) — deliberately no price, no upgrade button, no link out.
class _LockedAnalytics extends StatelessWidget {
  const _LockedAnalytics();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.insights_rounded,
                size: 32, color: AppColors.teal),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'See how customers find you',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.text1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Performance analytics is part of the Prime and Elite levels — '
          'track your shop views, product views, and customer chats over time.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.text3,
          ),
        ),
        const SizedBox(height: 22),
        const _StatCard(
          icon: Icons.storefront_rounded,
          label: 'Shop profile views',
          value: 0,
          color: AppColors.teal,
          locked: true,
        ),
        const SizedBox(height: 12),
        const _StatCard(
          icon: Icons.inventory_2_rounded,
          label: 'Product views',
          value: 0,
          color: AppColors.orange,
          locked: true,
        ),
        const SizedBox(height: 12),
        const _StatCard(
          icon: Icons.chat_bubble_rounded,
          label: 'Chats started',
          value: 0,
          color: Color(0xFF7C3AED),
          locked: true,
        ),
      ],
    );
  }
}
