import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device's default maps app pointed at [lat],[lng].
/// Uses the Google Maps web direction URL which works on Android (opens
/// Google Maps), iOS (opens the default browser or Maps), and web.
/// Shows a snackbar on failure — never throws.
Future<void> openDirections(
    BuildContext context, double lat, double lng) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
  );
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _showError(context);
  } catch (_) {
    if (context.mounted) _showError(context);
  }
}

void _showError(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(content: Text('Could not open navigation.')),
    );
}
