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
  final hadPlus = raw.trim().startsWith('+');
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return null;

  // LK with country code (94 + 9 digits = 11). Reject 94-prefixed strings
  // that are too short / too long since wa.me silently fails on those.
  if (digits.startsWith('94')) {
    if (digits.length == 11) return digits;
    return null;
  }

  // Local LK format: 0 + 9 digits → 94 + 9 digits.
  if (digits.startsWith('0') && digits.length == 10) {
    return '94${digits.substring(1)}';
  }

  // Bare 9-digit local part without 0.
  if (digits.length == 9 && !digits.startsWith('0')) return '94$digits';

  // International (starts with `+`) but not LK — trust the user only when
  // a leading `+` made the country code explicit. Otherwise we'd silently
  // dial whichever country wa.me decides the digits map to.
  if (hadPlus && digits.length >= 10 && digits.length <= 15) return digits;

  return null;
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
