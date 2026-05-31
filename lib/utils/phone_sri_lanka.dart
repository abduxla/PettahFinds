// Sri Lanka phone number normalization and validation.
//
// Accepted input formats (spaces, hyphens, parentheses are ignored):
//   07XXXXXXXX   — 10-digit local with trunk prefix 0
//   +94XXXXXXXXX — E.164 with +
//   94XXXXXXXXX  — E.164 without +
//
// All paths produce +94XXXXXXXXX (12 chars) or null if the number is invalid.

class SriLankaPhone {
  // Keep only digits.
  static String _digits(String v) => v.replaceAll(RegExp(r'[^\d]'), '');

  // Converts a raw user-typed number to E.164. Returns null if invalid.
  static String? toE164(String raw) {
    final d = _digits(raw);
    // 94 + 9 digits = 11 digits → already E.164-style without +
    if (d.startsWith('94') && d.length == 11) return '+$d';
    // 0 + 9 digits = 10 digits → local trunk format
    if (d.startsWith('0') && d.length == 10) return '+94${d.substring(1)}';
    return null;
  }

  // True when [value] looks like a phone rather than an email address.
  static bool looksLikePhone(String value) {
    if (value.contains('@')) return false;
    final d = _digits(value);
    return d.startsWith('0') || d.startsWith('94');
  }

  // Required validator — returns error string or null.
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    if (toE164(value.trim()) == null) {
      return 'Enter a valid Sri Lanka number (e.g. 077 123 4567)';
    }
    return null;
  }

  // Optional validator — blank is accepted.
  static String? validateOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (toE164(value.trim()) == null) {
      return 'Enter a valid Sri Lanka number (e.g. 077 123 4567)';
    }
    return null;
  }
}
