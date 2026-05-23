import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Saffron-orange circular badge that overlays any message / inbox
/// icon to indicate unread count. Pure presentation — the caller
/// passes the live count, which should come from
/// `totalUnreadCountProvider` so the badge ticks in real time off the
/// same Firestore listener the chat list uses.
///
/// Renders nothing when [count] is 0 — no empty disc, no zero text.
class UnreadBadge extends StatelessWidget {
  final Widget child;
  final int count;

  /// Brand saffron orange.
  static const _badgeColor = Color(0xFFE8821A);

  const UnreadBadge({
    super.key,
    required this.child,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final label = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -4,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            decoration: BoxDecoration(
              color: _badgeColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
