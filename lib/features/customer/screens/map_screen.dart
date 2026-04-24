// Real interactive Mapbox map screen.
//
// Token: pass via `flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxxx`
// (see lib/main.dart). When a token is missing, the screen degrades
// to a clean "configure to see live map" info state and still lists
// nearby businesses along the bottom.
//
// Platform setup (must be done manually):
//  - Android: add a public Mapbox download token to
//      android/gradle.properties as:
//        MAPBOX_DOWNLOADS_TOKEN=sk.xxxxx (secret, download-only)
//    and permission block is required in AndroidManifest.xml
//    (ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION — only needed for
//    the optional "my location" puck).
//  - iOS: add NSLocationWhenInUseUsageDescription in Info.plist if
//    you want location; add MBXAccessToken in Info.plist or pass via
//    --dart-define (we use --dart-define here).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/categories.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart' show hasMapboxToken;
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

// Pettah, Colombo — default map center.
const _defaultLng = 79.8542;
const _defaultLat = 6.9388;

final _mapBusinessesProvider =
    StreamProvider.autoDispose<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).streamAll();
});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  mbx.MapboxMap? _map;
  mbx.PointAnnotationManager? _markers;
  final Map<String, Business> _annotationToBusiness = {};
  Business? _selected;
  bool _locating = false;
  String? _categoryFilter; // null = All

  List<Business> _applyFilter(List<Business> src) {
    if (_categoryFilter == null) return src;
    return src
        .where((b) =>
            AppCategories.normalize(b.category) == _categoryFilter)
        .toList();
  }

  @override
  void dispose() {
    _markers = null;
    _map = null;
    super.dispose();
  }

  Future<void> _onMapCreated(mbx.MapboxMap mapboxMap) async {
    _map = mapboxMap;
    await mapboxMap.logo.updateSettings(mbx.LogoSettings(
      marginBottom: 140,
      marginLeft: 8,
    ));
    await mapboxMap.attribution.updateSettings(mbx.AttributionSettings(
      marginBottom: 140,
    ));
    await mapboxMap.scaleBar
        .updateSettings(mbx.ScaleBarSettings(enabled: false));
    await mapboxMap.compass
        .updateSettings(mbx.CompassSettings(enabled: false));

    final mgr = await mapboxMap.annotations.createPointAnnotationManager();
    mgr.addOnPointAnnotationClickListener(_MarkerTapListener(this));
    _markers = mgr;

    // If businesses are already loaded, paint markers now.
    final current = ref.read(_mapBusinessesProvider).valueOrNull;
    if (current != null) {
      await _syncMarkers(current);
    }
  }

  Future<void> _syncMarkers(List<Business> businesses) async {
    final mgr = _markers;
    if (mgr == null) return;
    await mgr.deleteAll();
    _annotationToBusiness.clear();
    final withCoords = businesses.where((b) => b.hasCoordinates).toList();
    if (withCoords.isEmpty) return;
    for (final b in withCoords) {
      final annotation = await mgr.create(mbx.PointAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(b.longitude!, b.latitude!),
        ),
        iconSize: 1.6,
        iconImage: 'marker-15',
        iconColor: AppTheme.accent.toARGB32(),
      ));
      _annotationToBusiness[annotation.id] = b;
    }
  }

  void _onMarkerTap(mbx.PointAnnotation annotation) {
    final business = _annotationToBusiness[annotation.id];
    if (business == null) return;
    setState(() => _selected = business);
    _map?.flyTo(
      mbx.CameraOptions(
        center: annotation.geometry,
        zoom: 15,
      ),
      mbx.MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) _snack('Turn on device location to use this.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) _snack('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _map?.flyTo(
        mbx.CameraOptions(
          center: mbx.Point(
            coordinates: mbx.Position(pos.longitude, pos.latitude),
          ),
          zoom: 14,
        ),
        mbx.MapAnimationOptions(duration: 700),
      );
    } catch (e) {
      if (mounted) _snack('Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(_mapBusinessesProvider);

    // Repaint markers when the business list updates. `ref.listen` keeps
    // the subscription out of the build path so it doesn't cause rebuilds.
    ref.listen<AsyncValue<List<Business>>>(_mapBusinessesProvider,
        (_, next) {
      final list = next.valueOrNull;
      if (list != null) _syncMarkers(_applyFilter(list));
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Real map (or token-missing info card)
          Positioned.fill(
            child: hasMapboxToken
                ? mbx.MapWidget(
                    key: const ValueKey('mapbox-map'),
                    cameraOptions: mbx.CameraOptions(
                      center: mbx.Point(
                        coordinates:
                            mbx.Position(_defaultLng, _defaultLat),
                      ),
                      zoom: 12.5,
                    ),
                    styleUri: mbx.MapboxStyles.MAPBOX_STREETS,
                    onMapCreated: _onMapCreated,
                  )
                : const _NoTokenFallback(),
          ),

          // Top bar + filter chips
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      _FloatingIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.go('/home'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.go('/search'),
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18),
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
                            child: const Row(
                              children: [
                                Icon(Icons.search_rounded,
                                    color: AppTheme.textMuted, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Search businesses',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _CategoryChipsBar(
                  selected: _categoryFilter,
                  onChanged: (v) {
                    setState(() {
                      _categoryFilter = v;
                      _selected = null;
                    });
                    final list =
                        ref.read(_mapBusinessesProvider).valueOrNull;
                    if (list != null) _syncMarkers(_applyFilter(list));
                  },
                ),
              ],
            ),
          ),

          // My location FAB (right side, above bottom strip)
          if (hasMapboxToken)
            Positioned(
              right: 16,
              bottom: 240,
              child: _FloatingIconButton(
                icon: _locating
                    ? Icons.more_horiz_rounded
                    : Icons.my_location_rounded,
                onTap: _goToMyLocation,
                tint: AppTheme.accent,
              ),
            ),

          // Bottom business strip / preview
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
                      data: (all) {
                        final list = _applyFilter(all);
                        if (list.isEmpty) {
                          return const EmptyStateWidget(
                            icon: Icons.map_outlined,
                            title: 'No businesses here',
                          );
                        }
                        return _NearbyStrip(
                          businesses: list.take(6).toList(),
                          onTap: (b) {
                            setState(() => _selected = b);
                            if (b.hasCoordinates) {
                              _map?.flyTo(
                                mbx.CameraOptions(
                                  center: mbx.Point(
                                    coordinates: mbx.Position(
                                        b.longitude!, b.latitude!),
                                  ),
                                  zoom: 15,
                                ),
                                mbx.MapAnimationOptions(duration: 600),
                              );
                            }
                          },
                        );
                      },
                      loading: () => const _NearbyStripSkeleton(),
                      error: (e, _) => Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
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

class _MarkerTapListener extends mbx.OnPointAnnotationClickListener {
  final _MapScreenState state;
  _MarkerTapListener(this.state);

  @override
  void onPointAnnotationClick(mbx.PointAnnotation annotation) {
    state._onMarkerTap(annotation);
  }
}

// =====================================================================
// Graceful preview backdrop shown when no Mapbox token is configured.
// It is NOT a fake map — just a calm premium surface that lets the
// bottom business strip take focus until the live map is enabled.
// (Configure MAPBOX_ACCESS_TOKEN via --dart-define to swap this out
// for the real map.)
// =====================================================================
class _NoTokenFallback extends StatelessWidget {
  const _NoTokenFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.bgAlt, AppTheme.bg],
        ),
      ),
      child: CustomPaint(
        painter: _SoftGridPainter(),
        size: Size.infinite,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 220),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withAlpha(50),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.explore_rounded,
                      size: 34, color: AppTheme.accent),
                ),
                const SizedBox(height: 20),
                const Text('Explore nearby',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.text,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Browse local businesses around Pettah and Colombo '
                  'from the list below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSub,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withAlpha(90)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =====================================================================
// Floating UI pieces
// =====================================================================
class _CategoryChipsBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _CategoryChipsBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <String?>[null, ...AppCategories.all];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = items[i];
          final active = selected == c;
          final label = c ?? 'All';
          return GestureDetector(
            onTap: () => onChanged(c),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppTheme.accent : Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppTheme.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  const _FloatingIconButton({
    required this.icon,
    required this.onTap,
    this.tint,
  });

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
        child: Icon(icon, color: tint ?? AppTheme.text, size: 22),
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
                      imageUrl:
                          b.bannerUrl.isNotEmpty ? b.bannerUrl : b.logoUrl,
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
        itemBuilder: (_, i) => Container(
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
