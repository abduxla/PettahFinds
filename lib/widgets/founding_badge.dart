import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Founding Business" chip — the permanent honor carried by the first 50
/// businesses to join PetaFinds. Stamped server-side only (see
/// onBusinessCreated in functions/index.js); this widget just renders it.
class FoundingBadge extends StatelessWidget {
  final bool compact;
  const FoundingBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // warm gold wash
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0A82E), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: compact ? 10 : 12,
            color: const Color(0xFFB07B10),
          ),
          const SizedBox(width: 3),
          Text(
            'Founding Business',
            style: GoogleFonts.dmSans(
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFB07B10),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience: renders nothing unless the business earned the badge.
class MaybeFoundingBadge extends StatelessWidget {
  final bool foundingMember;
  final bool compact;
  const MaybeFoundingBadge({
    super.key,
    required this.foundingMember,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!foundingMember) return const SizedBox.shrink();
    return FoundingBadge(compact: compact);
  }
}
