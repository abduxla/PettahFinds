import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official-style WhatsApp glyph rendered from the bundled SVG asset.
///
/// Uses a ColorFilter so callers can tint the mark — default is the
/// WhatsApp brand green (#25D366). Drop-in replacement for any
/// `Icons.chat_*` icon currently used as a "Chat on WhatsApp" affordance.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  /// WhatsApp brand green, per the official assets.
  static const brandGreen = Color(0xFF25D366);

  const WhatsAppIcon({
    super.key,
    this.size = 22,
    this.color = brandGreen,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/whatsapp.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
