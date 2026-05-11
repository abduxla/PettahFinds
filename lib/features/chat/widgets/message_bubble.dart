import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/chat_message.dart';

/// Per spec: seller messages render right, customer messages render left
/// regardless of viewer — fixed alignment for a consistent thread look.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String sellerId;
  const MessageBubble({
    super.key,
    required this.message,
    required this.sellerId,
  });

  @override
  Widget build(BuildContext context) {
    final isSeller = message.senderId == sellerId;
    final bg = isSeller ? AppColors.teal : AppColors.tealLight;
    final fg = isSeller ? Colors.white : AppColors.text1;
    final align = isSeller ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isSeller ? 16 : 4),
      bottomRight: Radius.circular(isSeller ? 4 : 16),
    );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: fg,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat.jm().format(message.createdAt),
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: isSeller
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
