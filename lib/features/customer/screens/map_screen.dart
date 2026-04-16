// Premium map placeholder screen.
//
// To wire up a real map in production, add one of:
//   - google_maps_flutter (needs API keys in AndroidManifest / AppDelegate)
//   - flutter_map (OpenStreetMap, no key required)
// Then replace the `_MapCanvas` widget below with the real map widget.
// All business data wiring, markers, bottom sheets are already scaffolded.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

final _mapBusinessesProvider = StreamProvider<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).streamAll();
});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Business? _selected;

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(_mapBusinessesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Faux premium map canvas
          const _MapCanvas(),

          // Floating markers (scaled to screen, for visual scaffolding)
          businessesAsync.when(
            data: (all) => _MarkerLayer(
              businesses: all.take(8).toList(),
              selectedId: _selected?.id,
              onTap: (b) => setState(() => _selected = b),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Top bar (floating)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  _FloatingIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.go('/home'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: AppTheme.textMuted, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search this area',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentDark],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.tune_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom floating business list / preview
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
              child: _selected != null
                  ? _BusinessPreviewCard(
                      business: _selected!,
                      onClose: () => setState(() => _selected = null),
                    )
                  : businessesAsync.when(
                      data: (list) => list.isEmpty
                          ? const EmptyStateWidget(
                              icon: Icons.map_outlined,
                              title: 'No businesses yet',
                            )
                          : _NearbyStrip(
                              businesses: list.take(6).toList(),
                              onTap: (b) => setState(() => _selected = b),
                            ),
                      loading: () => const _NearbyStripSkeleton(),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppErrorWidget(
                          message: e.toString(),
                          onRetry: () =>
                              ref.invalidate(_mapBusinessesProvider),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Faux map canvas — premium placeholder until a real map SDK is wired up
// =====================================================================
class _MapCanvas extends StatelessWidget {
  const _MapCanvas();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE9E6DD),
            Color(0xFFF2EFE6),
            Color(0xFFE9E6DD),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _MapGridPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle diagonal beige "streets"
    final streets = Paint()
      ..color = const Color(0xFFDDD9CC)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(0, size.height * 0.22), Offset(size.width, size.height * 0.38),
        streets);
    canvas.drawLine(
        Offset(size.width * 0.1, 0), Offset(size.width * 0.3, size.height),
        streets);
    canvas.drawLine(
        Offset(size.width * 0.7, 0), Offset(size.width * 0.55, size.height),
        streets);
    canvas.drawLine(
        Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.85),
        streets);

    // Faux park/water blobs
    final park = Paint()..color = const Color(0xFFD9E4D2);
    canvas.drawCircle(
        Offset(size.width * 0.78, size.height * 0.25), 60, park);

    final water = Paint()..color = const Color(0xFFC7D8E0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.05, size.height * 0.55, 120, 80),
        const Radius.circular(40),
      ),
      water,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =====================================================================
// Marker layer (placeholder positions derived from index)
// =====================================================================
class _MarkerLayer extends StatelessWidget {
  final List<Business> businesses;
  final String? selectedId;
  final ValueChanged<Business> onTap;

  const _MarkerLayer({
    required this.businesses,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return Stack(
      children: [
        for (int i = 0; i < businesses.length; i++)
          Positioned(
            left: (screen.width * _positions[i % _positions.length].dx) - 26,
            top: (screen.height * _positions[i % _positions.length].dy) - 26,
            child: _Marker(
              business: businesses[i],
              selected: businesses[i].id == selectedId,
              onTap: () => onTap(businesses[i]),
            ),
          ),
      ],
    );
  }

  // Spread of relative screen positions for visual scaffolding.
  static const _positions = [
    Offset(0.25, 0.30),
    Offset(0.62, 0.28),
    Offset(0.80, 0.42),
    Offset(0.40, 0.48),
    Offset(0.18, 0.55),
    Offset(0.55, 0.62),
    Offset(0.75, 0.58),
    Offset(0.35, 0.38),
  ];
}

class _Marker extends StatelessWidget {
  final Business business;
  final bool selected;
  final VoidCallback onTap;

  const _Marker({
    required this.business,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 56.0 : 44.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.accent : Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withAlpha(selected ? 120 : 60),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: business.logoUrl.isNotEmpty
              ? CachedImage(imageUrl: business.logoUrl, fit: BoxFit.cover)
              : Container(
                  color: AppTheme.accentLight,
                  child: const Icon(Icons.store_rounded,
                      color: AppTheme.accent, size: 22),
                ),
        ),
      ),
    );
  }
}

// =====================================================================
// Floating UI pieces
// =====================================================================
class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: AppTheme.text, size: 22),
      ),
    );
  }
}

class _NearbyStrip extends StatelessWidget {
  final List<Business> businesses;
  final ValueChanged<Business> onTap;

  const _NearbyStrip({required this.businesses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: businesses.length,
        itemBuilder: (_, i) {
          final b = businesses[i];
          return GestureDetector(
            onTap: () => onTap(b),
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(16),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedImage(
                      imageUrl: b.bannerUrl.isNotEmpty
                          ? b.bannerUrl
                          : b.logoUrl,
                      width: 68,
                      height: 68,
                      placeholderIcon: Icons.storefront,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                        const SizedBox(height: 4),
                        Text(b.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: AppTheme.accent),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(b.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSub,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NearbyStripSkeleton extends StatelessWidget {
  const _NearbyStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          width: 260,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              ShimmerBox(width: 68, height: 68, radius: 14),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 130, height: 14, radius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: 90, height: 12, radius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: 110, height: 10, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessPreviewCard extends StatelessWidget {
  final Business business;
  final VoidCallback onClose;

  const _BusinessPreviewCard({
    required this.business,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(24),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CachedImage(
                  imageUrl: business.bannerUrl,
                  height: 130,
                  width: double.infinity,
                  placeholderIcon: Icons.storefront,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(business.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                      ),
                      if (business.isVerified)
                        const Icon(Icons.verified,
                            size: 18, color: AppTheme.accent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${business.category} • ${business.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (business.ratingCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFE0A500), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                business.ratingAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB8860B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () =>
                              context.go('/home/business/${business.id}'),
                          child: const Text('View Business'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
