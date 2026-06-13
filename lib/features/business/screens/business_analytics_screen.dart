import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business_stats.dart';
import '../../../models/business_tier.dart';
import '../../../models/product.dart';
import '../../../models/product_stat.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/tier_badge.dart';

/// Seller analytics — customer engagement totals for the shop, plus a
/// per-product breakdown so the seller can see which listings are pulling.
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
        loading: () => LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserBusinessProvider),
        ),
        data: (business) {
          if (business == null) {
            return Center(
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
          if (!tier.hasAnalytics) return const _LockedAnalytics();
          return _LoadedAnalytics(businessId: business.id, tier: tier);
        },
      ),
    );
  }
}

class _LoadedAnalytics extends ConsumerWidget {
  final String businessId;
  final BusinessTier tier;
  const _LoadedAnalytics({required this.businessId, required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(businessStatsProvider(businessId));
    final productStats =
        ref.watch(productStatsProvider(businessId)).valueOrNull ??
            <ProductStat>[];
    final products =
        ref.watch(businessProductsProvider(businessId)).valueOrNull ??
            <Product>[];
    final titles = {for (final p in products) p.id: p.title};

    return statsAsync.when(
      loading: () => LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(businessStatsProvider(businessId)),
      ),
      data: (stats) => _AnalyticsBody(
        stats: stats,
        tier: tier,
        productStats: productStats,
        titles: titles,
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  final BusinessStats stats;
  final BusinessTier tier;
  final List<ProductStat> productStats;
  final Map<String, String> titles;
  const _AnalyticsBody({
    required this.stats,
    required this.tier,
    required this.productStats,
    required this.titles,
  });

  @override
  Widget build(BuildContext context) {
    final ranked = productStats.where((p) => p.views > 0 || p.chats > 0).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _TotalCard(total: stats.totalEngagements, tier: tier),
        SizedBox(height: 14),
        _StatCard(
          icon: Icons.storefront_rounded,
          label: 'Shop profile views',
          value: stats.profileViews,
          color: AppColors.teal,
        ),
        SizedBox(height: 12),
        _StatCard(
          icon: Icons.inventory_2_rounded,
          label: 'Product views',
          value: stats.productViews,
          color: AppColors.orange,
        ),
        SizedBox(height: 12),
        _StatCard(
          icon: Icons.chat_bubble_rounded,
          label: 'Chats started',
          value: stats.chatsStarted,
          color: Color(0xFF7C3AED),
        ),

        // Per-product breakdown
        SizedBox(height: 22),
        Row(
          children: [
            Text(
              'Top products',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'by views',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.text3,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        if (ranked.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'No product activity yet. As customers open your listings, '
                'your most-viewed products will rank here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.text3,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < ranked.length && i < 15; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1, indent: 16, endIndent: 16,
                        color: AppColors.border),
                  _ProductStatRow(
                    rank: i + 1,
                    productId: ranked[i].productId,
                    title: titles[ranked[i].productId] ?? 'Removed product',
                    views: ranked[i].views,
                    saves: ranked[i].saves,
                    chats: ranked[i].chats,
                    // Only navigate to listings that still exist.
                    tappable: titles.containsKey(ranked[i].productId),
                  ),
                ],
              ],
            ),
          ),

        SizedBox(height: 18),
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

class _ProductStatRow extends StatelessWidget {
  final int rank;
  final String productId;
  final String title;
  final int views;
  final int saves;
  final int chats;
  final bool tappable;
  const _ProductStatRow({
    required this.rank,
    required this.productId,
    required this.title,
    required this.views,
    required this.saves,
    required this.chats,
    required this.tappable,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.text4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _miniStat(Icons.visibility_rounded, views, AppColors.teal),
          const SizedBox(width: 9),
          _miniStat(Icons.bookmark_rounded, saves, AppColors.orange),
          const SizedBox(width: 9),
          _miniStat(Icons.chat_bubble_rounded, chats, const Color(0xFF7C3AED)),
          if (tappable) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.text4),
          ],
        ],
      ),
    );

    if (!tappable) return row;
    // Tap opens the listing (owner preview) so a seller can tell apart
    // same-named products — e.g. the same item in different colorways.
    return InkWell(
      onTap: () => context.push('/product/$productId?mode=owner'),
      child: row,
    );
  }

  Widget _miniStat(IconData icon, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        SizedBox(width: 3),
        Text(
          '$value',
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.text2,
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
      padding: EdgeInsets.all(20),
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
              SizedBox(width: 6),
              TierBadge(tier: tier, compact: true),
            ],
          ),
          SizedBox(height: 6),
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
      padding: EdgeInsets.all(16),
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
          SizedBox(width: 14),
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
            Icon(Icons.lock_outline_rounded,
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
      padding: EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.insights_rounded,
                size: 32, color: AppColors.teal),
          ),
        ),
        SizedBox(height: 16),
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
        SizedBox(height: 8),
        Text(
          'Performance analytics is part of the Prime and Elite levels — '
          'track your shop views, product views, customer chats, and which '
          'listings pull the most interest over time.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.text3,
          ),
        ),
        SizedBox(height: 22),
        _StatCard(
          icon: Icons.storefront_rounded,
          label: 'Shop profile views',
          value: 0,
          color: AppColors.teal,
          locked: true,
        ),
        SizedBox(height: 12),
        _StatCard(
          icon: Icons.inventory_2_rounded,
          label: 'Product views',
          value: 0,
          color: AppColors.orange,
          locked: true,
        ),
        const SizedBox(height: 12),
        _StatCard(
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
