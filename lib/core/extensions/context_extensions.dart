import 'package:flutter/material.dart';

/// Strips Firebase error prefixes like `[firebase_auth/wrong-password] ...`
String cleanErrorMessage(Object error) {
  final raw = error.toString();
  // Firebase errors: [firebase_auth/code] message
  final regex = RegExp(r'\[[\w_/\-]+\]\s*');
  var cleaned = raw.replaceAll(regex, '');
  // Remove "Exception: " prefix
  if (cleaned.startsWith('Exception: ')) {
    cleaned = cleaned.substring(11);
  }
  return cleaned.trim();
}

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  MediaQueryData get mq => MediaQuery.of(this);
  double get screenWidth => mq.size.width;
  double get screenHeight => mq.size.height;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? colorScheme.error
            : colorScheme.inverseSurface,
      ),
    );
  }

  void showErrorSnackBar(Object error) {
    showSnackBar(cleanErrorMessage(error), isError: true);
  }

  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
