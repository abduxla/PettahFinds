import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/chat_message.dart';

/// Standard chat alignment: messages I sent render on the right (teal
/// solid), messages from the other party render on the left (teal
/// light). Earlier this was hardcoded seller-right / customer-left
/// regardless of viewer — both sides saw the same alignment, which
/// confused everyone because their own messages appeared on the left
/// in their own inbox. [viewerUid] flips the bubble per-viewer so each
/// person sees the conventional "my side / their side" split.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String viewerUid;
  const MessageBubble({
    super.key,
    required this.message,
    required this.viewerUid,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.senderId == viewerUid;
    final bg = isMine ? AppColors.teal : AppColors.tealLight;
    final fg = isMine ? Colors.white : AppColors.text1;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
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
                  color: isMine
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
