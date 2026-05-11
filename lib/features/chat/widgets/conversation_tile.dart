import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/conversation.dart';
import '../../../widgets/cached_image.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool viewerIsSeller;
  final VoidCallback onTap;
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.viewerIsSeller,
    required this.onTap,
  });

  String _stamp(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) return DateFormat.jm().format(d);
    if (now.difference(d).inDays < 7) return DateFormat('EEE').format(d);
    return DateFormat.MMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final unread = viewerIsSeller
        ? conversation.unreadCountSeller
        : conversation.unreadCountCustomer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedImage(
                imageUrl: conversation.productImage,
                width: 56,
                height: 56,
                placeholderIcon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.productTitle.isNotEmpty
                              ? conversation.productTitle
                              : 'Product',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text1,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _stamp(conversation.lastMessageAt ?? conversation.updatedAt),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.text3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage.isNotEmpty
                              ? conversation.lastMessage
                              : (viewerIsSeller
                                  ? 'New inquiry'
                                  : 'Say hi to ${conversation.businessName}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            color: unread > 0
                                ? AppColors.text1
                                : AppColors.text3,
                            fontWeight:
                                unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.orange,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
