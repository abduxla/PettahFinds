import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cleans a Sri Lankan phone number into the digits-only form expected by
/// `wa.me` links. Returns `null` if the input doesn't look like a valid
/// number (less than 7 digits after stripping).
///
///   "+94 77 123 4567"  → "94771234567"
///   "077-123 4567"     → "94771234567"  (leading 0 → country code 94)
///   "771234567"        → "94771234567"  (assume LK if no country code)
String? cleanWhatsAppNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return null;

  // If it already starts with a country code, keep as-is.
  if (digits.startsWith('94') && digits.length >= 11) return digits;

  // Local LK format: drop leading 0 and prefix 94.
  if (digits.startsWith('0')) return '94${digits.substring(1)}';

  // Anything else: assume the user typed the local part without 0.
  if (digits.length == 9) return '94$digits';

  return digits;
}

/// Opens the system WhatsApp deep-link for [rawNumber] with [message]
/// pre-filled. Returns false on failure (and shows a snackbar) so callers
/// can decide whether to fall back. Never throws.
Future<bool> launchWhatsApp({
  required BuildContext context,
  required String rawNumber,
  required String message,
}) async {
  final cleaned = cleanWhatsAppNumber(rawNumber);
  if (cleaned == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid WhatsApp number')),
      );
    }
    return false;
  }
  final uri = Uri.parse(
    'https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}',
  );
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
    return ok;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
    return false;
  }
}
