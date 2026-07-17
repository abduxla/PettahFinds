import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/biz_insights.dart';
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

class _LoadedAnalytics extends ConsumerStatefulWidget {
  final String businessId;
  final BusinessTier tier;
  const _LoadedAnalytics({required this.businessId, required this.tier});

  @override
  ConsumerState<_LoadedAnalytics> createState() => _LoadedAnalyticsState();
}

class _LoadedAnalyticsState extends ConsumerState<_LoadedAnalytics>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from background: iOS may have dropped the socket under the
    // Firestore listen channel without the SDK noticing, which freezes the
    // counters until it times out (minutes). Re-creating the subscriptions
    // forces a fresh channel + immediate server read, so numbers are
    // current the moment the seller looks at the screen again.
    if (state == AppLifecycleState.resumed) _resync();
  }

  void _resync() {
    ref.invalidate(businessStatsProvider(widget.businessId));
    ref.invalidate(productStatsProvider(widget.businessId));
    ref.invalidate(businessProductsProvider(widget.businessId));
    ref.invalidate(bizInsightsProvider(widget.businessId));
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(businessStatsProvider(widget.businessId));
    final productStats =
        ref.watch(productStatsProvider(widget.businessId)).valueOrNull ??
            <ProductStat>[];
    final products =
        ref.watch(businessProductsProvider(widget.businessId)).valueOrNull ??
            <Product>[];
    final insights =
        ref.watch(bizInsightsProvider(widget.businessId)).valueOrNull;

    return statsAsync.when(
      loading: () => LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () =>
            ref.invalidate(businessStatsProvider(widget.businessId)),
      ),
      data: (stats) => RefreshIndicator(
        color: AppColors.teal,
        onRefresh: () async {
          _resync();
          // Hold the spinner until the fresh subscription delivers, so a
          // pull always means "these numbers are current as of now".
          await ref.read(businessStatsProvider(widget.businessId).future);
        },
        child: _AnalyticsBody(
          stats: stats,
          tier: widget.tier,
          productStats: productStats,
          products: products,
          insights: insights,
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  final BusinessStats stats;
  final BusinessTier tier;
  final List<ProductStat> productStats;
  final List<Product> products;
  /// Nightly market intelligence — null until the first nightly run (the
  /// Vibranium market-position card hides itself in that case).
  final BizInsights? insights;
  const _AnalyticsBody({
    required this.stats,
    required this.tier,
    required this.productStats,
    required this.products,
    this.insights,
  });

  @override
  Widget build(BuildContext context) {
    // Build a row for EVERY product the shop has, joining its stats
    // (defaulting to zero for products no one has viewed yet). Previously
    // this listed only products with recorded views, so a just-added
    // product never appeared until a customer opened it — the seller
    // couldn't confirm it was being tracked. Sort by views desc, then
    // newest first so a brand-new listing surfaces at the top of the
    // zero-activity group instead of vanishing.
    final statById = {for (final s in productStats) s.productId: s};
    final ranked = [...products]
      ..sort((a, b) {
        final av = statById[a.id]?.views ?? 0;
        final bv = statById[b.id]?.views ?? 0;
        if (av != bv) return bv.compareTo(av);
        return b.createdAt.compareTo(a.createdAt);
      });

    return ListView(
      // Always scrollable so the RefreshIndicator pull works even when the
      // content fits on one screen (short product lists).
      physics: const AlwaysScrollableScrollPhysics(),
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

        // ---- Vibranium-only intelligence ----
        // Market position comes from the nightly aggregation job and only
        // renders once the shop's first run has produced a bizInsights doc.
        // The conversion funnel is computed client-side from the stats
        // already streaming above, so it's always available.
        if (tier == BusinessTier.elite && insights != null) ...[
          SizedBox(height: 12),
          _MarketPositionCard(insights: insights!),
        ],
        if (tier == BusinessTier.elite) ...[
          SizedBox(height: 12),
          _FunnelCard(
            stats: stats,
            productStats: productStats,
            products: products,
          ),
        ],

        // Per-product breakdown
        SizedBox(height: 22),
        Row(
          children: [
            Text(
              'Your products',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'ranked by views',
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
                'Add your first product and it will appear here, ready to '
                'track as customers start browsing.',
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
                for (var i = 0; i < ranked.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1, indent: 16, endIndent: 16,
                        color: AppColors.border),
                  _ProductStatRow(
                    rank: i + 1,
                    productId: ranked[i].id,
                    title: ranked[i].title,
                    views: statById[ranked[i].id]?.views ?? 0,
                    saves: statById[ranked[i].id]?.saves ?? 0,
                    chats: statById[ranked[i].id]?.chats ?? 0,
                    tappable: true,
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

/// Vibranium: the shop's marketplace rank from the nightly aggregation —
/// #N of M, percentile band, overnight movement, and views vs the
/// category average. Numbers refresh once a night (03:30 Colombo).
class _MarketPositionCard extends StatelessWidget {
  final BizInsights insights;
  const _MarketPositionCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final move = insights.movement;
    final vsAvg = insights.viewsVsAvgPct;
    return Container(
      padding: EdgeInsets.all(16),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emoji_events_rounded,
                    color: AppColors.orange, size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Market position',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text1,
                  ),
                ),
              ),
              if (insights.percentileBand.isNotEmpty)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    insights.percentileBand,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${insights.marketplacePosition}',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text1,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'of ${insights.totalBusinesses} shops on PetaFinds',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: AppColors.text3,
                  ),
                ),
              ),
              Spacer(),
              if (move != null && move != 0)
                Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        move > 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: move > 0 ? AppColors.teal : AppColors.red,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '${move.abs()} overnight',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              move > 0 ? AppColors.teal : AppColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (vsAvg != null) ...[
            SizedBox(height: 12),
            Divider(height: 1, color: AppColors.border),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Views vs ${insights.category.isEmpty ? 'category' : insights.category} average',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: AppColors.text3,
                    ),
                  ),
                ),
                Text(
                  '${vsAvg >= 0 ? '+' : ''}$vsAvg%',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: vsAvg >= 0 ? AppColors.teal : AppColors.red,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 8),
          Text(
            'Updated nightly',
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              color: AppColors.text4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vibranium: how browsing turns into interest — views → saves → chats
/// with conversion rates, plus up to two per-product reads (a product
/// getting looks but no chats; the best converter). Computed entirely
/// from the stats already streaming into this screen.
class _FunnelCard extends StatelessWidget {
  final BusinessStats stats;
  final List<ProductStat> productStats;
  final List<Product> products;
  const _FunnelCard({
    required this.stats,
    required this.productStats,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final views = stats.productViews;
    final saves = stats.saves;
    final chats = stats.chatsStarted;
    String rate(int part) =>
        views <= 0 ? '—' : '${((part / views) * 100).toStringAsFixed(1)}%';

    // Per-product reads. Titles joined from the live product list.
    final titleById = {
      for (final p in products)
        p.id: p.shortTitle.isNotEmpty ? p.shortTitle : p.title,
    };
    ProductStat? looker; // most-viewed product with zero chats
    ProductStat? converter; // best chats-per-view among viewed products
    for (final s in productStats) {
      if (!titleById.containsKey(s.productId)) continue;
      if (s.views >= 15 && s.chats == 0) {
        if (looker == null || s.views > looker.views) looker = s;
      }
      if (s.views >= 10 && s.chats > 0) {
        final best = converter;
        if (best == null ||
            s.chats / s.views > best.chats / best.views) {
          converter = s;
        }
      }
    }

    Widget step(String label, int value) => Expanded(
          child: Column(
            children: [
              Text(
                '$value',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text1,
                ),
              ),
              SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.text3,
                ),
              ),
            ],
          ),
        );

    Widget insightRow(IconData icon, Color color, String text) => Padding(
          padding: EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: color),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.text2,
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: EdgeInsets.all(16),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.filter_alt_rounded,
                    color: Color(0xFF7C3AED), size: 22),
              ),
              SizedBox(width: 14),
              Text(
                'Conversion insights',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text1,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              step('Product views', views),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.text4),
              step('Saved (${rate(saves)})', saves),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.text4),
              step('Chats (${rate(chats)})', chats),
            ],
          ),
          if (looker != null)
            insightRow(
              Icons.visibility_rounded,
              AppColors.orange,
              '"${titleById[looker.productId]}" gets plenty of looks but '
              'no chats yet — a sharper price or better photos could '
              'convert that interest.',
            ),
          if (converter != null)
            insightRow(
              Icons.trending_up_rounded,
              AppColors.teal,
              '"${titleById[converter.productId]}" converts best — '
              '${converter.chats} chat${converter.chats == 1 ? '' : 's'} '
              'from ${converter.views} views.',
            ),
          if (looker == null && converter == null)
            insightRow(
              Icons.hourglass_empty_rounded,
              AppColors.text4,
              'Per-product insights appear as customers browse your '
              'listings.',
            ),
        ],
      ),
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
