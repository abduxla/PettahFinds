import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import '../../../core/theme/app_colors.dart';
import '../../../main.dart' show hasMapboxToken;

// Pettah, Colombo — default centre for new businesses.
const _kDefaultLat = 6.9388;
const _kDefaultLng = 79.8542;

/// Full-screen location picker for business setup/edit.
///
/// Returns `(latitude, longitude)` when the user confirms, or `null`
/// if cancelled.
///
/// When a Mapbox token is available the user pans the map to centre
/// the crosshair pin over their shop. When no token is configured
/// (e.g. web preview or unconfigured build) a manual text-entry
/// fallback is shown instead.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  /// Push and wait for a `(lat, lng)` result.
  static Future<(double, double)?> show(
    BuildContext context, {
    double? lat,
    double? lng,
  }) {
    return Navigator.push<(double, double)>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            LocationPickerScreen(initialLat: lat, initialLng: lng),
      ),
    );
  }

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  mbx.MapboxMap? _map;
  bool _confirming = false;

  // Manual-entry fallback controllers (also used as default when map
  // unavailable).
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLat ?? _kDefaultLat;
    final lng = widget.initialLng ?? _kDefaultLng;
    _latCtrl = TextEditingController(text: lat.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: lng.toStringAsFixed(6));
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);

    // Map path — read the current camera centre.
    if (hasMapboxToken && _map != null) {
      try {
        final state = await _map!.getCameraState();
        // In mapbox_maps_flutter 2.22+, CameraState.center is a Point.
        // Position stores coordinates as [lng, lat] per GeoJSON convention.
        final lat = state.center.coordinates.lat.toDouble();
        final lng = state.center.coordinates.lng.toDouble();
        if (mounted) Navigator.pop(context, (lat, lng));
        return;
      } catch (_) {
        // Parsing failed — fall through to manual entry.
      }
    }

    // Manual-entry path.
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Enter a valid latitude (−90 to 90) and longitude (−180 to 180).'),
          ),
        );
      }
      return;
    }
    if (mounted) Navigator.pop(context, (lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _confirming ? null : _confirm,
              child: _confirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm'),
            ),
          ),
        ],
      ),
      body: hasMapboxToken
          ? Stack(
              children: [
                // Live Mapbox map.
                mbx.MapWidget(
                  key: const ValueKey('location-picker-map'),
                  cameraOptions: mbx.CameraOptions(
                    center: mbx.Point(
                      coordinates: mbx.Position(
                        widget.initialLng ?? _kDefaultLng,
                        widget.initialLat ?? _kDefaultLat,
                      ),
                    ),
                    zoom: 16,
                  ),
                  styleUri: mbx.MapboxStyles.MAPBOX_STREETS,
                  onMapCreated: (map) => _map = map,
                ),
                // Centre crosshair — the selected point.
                const Center(
                  child: Icon(
                    Icons.location_pin,
                    size: 52,
                    color: AppColors.teal,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                // Instruction banner.
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(240),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Pan the map to place the pin on your business location, then tap Confirm',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _ManualCoordinateEntry(
              latCtrl: _latCtrl,
              lngCtrl: _lngCtrl,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manual fallback (no Mapbox token configured).
// ─────────────────────────────────────────────────────────────────────────────
class _ManualCoordinateEntry extends StatelessWidget {
  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;

  const _ManualCoordinateEntry({
    required this.latCtrl,
    required this.lngCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.location_on_outlined,
              size: 52, color: AppColors.teal),
          const SizedBox(height: 16),
          Text(
            'Enter your business coordinates',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Open Google Maps, search for your address, long-press to drop a '
            'pin, then copy the latitude and longitude shown.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: latCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Latitude',
              hintText: '6.9388',
              prefixIcon: Icon(Icons.north_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lngCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Longitude',
              hintText: '79.8542',
              prefixIcon: Icon(Icons.east_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
