import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  bool _sending = false;
  bool _readMarked = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final appUser = ref.read(appUserProvider).valueOrNull;
    final conv = ref
        .read(conversationStreamProvider(widget.conversationId))
        .valueOrNull;
    if (appUser == null || conv == null) return;
    final fromCustomer = appUser.uid == conv.customerId;
    setState(() => _sending = true);
    try {
      await ref.read(chatServiceProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: appUser.uid,
            senderName: appUser.displayName,
            text: text,
            fromCustomer: fromCustomer,
          );
      _inputCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _markReadOnce(String id, bool isCustomer) {
    if (_readMarked) return;
    _readMarked = true;
    ref.read(chatServiceProvider).markRead(
          conversationId: id,
          isCustomer: isCustomer,
        );
  }

  @override
  Widget build(BuildContext context) {
    final convAsync =
        ref.watch(conversationStreamProvider(widget.conversationId));
    final messagesAsync =
        ref.watch(conversationMessagesProvider(widget.conversationId));
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          // Always return to the inbox (/chat). User mental model on a
          // messaging app is "back = my list of chats", not "back = the
          // last screen I was on". Even if the stack has /home or a
          // product detail below us, this jumps to the chat list.
          onPressed: () => context.go('/chat'),
        ),
        title: convAsync.when(
          // Title = the OTHER party. Customer sees business name; seller
          // sees the customer's name. Falls back to a generic placeholder
          // for legacy threads created before customerName was
          // denormalized onto the conversation doc.
          data: (c) {
            if (c == null) return Text('Chat', style: _titleStyle());
            final viewerIsSeller =
                appUser != null && appUser.uid == c.sellerId;
            final label = viewerIsSeller
                ? (c.customerName.isNotEmpty ? c.customerName : 'Customer')
                : (c.businessName.isNotEmpty ? c.businessName : 'Business');
            return Text(label, style: _titleStyle());
          },
          loading: () => Text('Chat', style: _titleStyle()),
          error: (_, _) => Text('Chat', style: _titleStyle()),
        ),
      ),
      body: SafeArea(
        top: false,
        child: convAsync.when(
          data: (conv) {
            if (conv == null) {
              return Center(
                child: Text(
                  'Conversation not found.',
                  style: GoogleFonts.dmSans(color: AppColors.text3),
                ),
              );
            }
            if (appUser != null) {
              final isCustomer = appUser.uid == conv.customerId;
              _markReadOnce(conv.id, isCustomer);
            }
            return Column(
              children: [
                // Product header card.
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImage(
                          imageUrl: conv.productImage,
                          width: 44,
                          height: 44,
                          placeholderIcon: Icons.shopping_bag_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conv.productTitle.isNotEmpty
                                  ? conv.productTitle
                                  : 'Product',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text1,
                              ),
                            ),
                            Text(
                              conv.businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 11.5,
                                color: AppColors.text3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (conv.productId.isNotEmpty)
                        IconButton(
                          onPressed: () =>
                              context.go('/home/product/${conv.productId}'),
                          icon: const Icon(Icons.arrow_outward_rounded,
                              size: 18, color: AppColors.teal),
                          tooltip: 'View product',
                        ),
                    ],
                  ),
                ),

                // Messages list (reversed — newest at the bottom).
                Expanded(
                  child: messagesAsync.when(
                    data: (msgs) => msgs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                appUser?.uid == conv.customerId
                                    ? 'Send the first message about this product.'
                                    : 'No customer messages yet.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: AppColors.text3,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            reverse: true,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            itemCount: msgs.length,
                            itemBuilder: (_, i) => MessageBubble(
                              message: msgs[i],
                              sellerId: conv.sellerId,
                            ),
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          SizedBox(height: 16),
                          ShimmerBox(height: 44, radius: 14),
                          SizedBox(height: 8),
                          ShimmerBox(height: 44, radius: 14),
                        ],
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text('Couldn\'t load: $e',
                          style: GoogleFonts.dmSans(color: AppColors.text3)),
                    ),
                  ),
                ),

                // Composer.
                _Composer(
                  controller: _inputCtrl,
                  sending: _sending,
                  onSend: _send,
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(height: 16),
                ShimmerBox(height: 64, radius: 12),
                SizedBox(height: 16),
                ShimmerBox(height: 44, radius: 14),
                SizedBox(height: 8),
                ShimmerBox(height: 44, radius: 14),
              ],
            ),
          ),
          error: (e, _) => Center(
            child: Text('Conversation error: $e',
                style: GoogleFonts.dmSans(color: AppColors.text3)),
          ),
        ),
      ),
    );
  }

  TextStyle _titleStyle() => GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.text1,
        letterSpacing: -0.3,
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSection,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    counterText: '',
                  ),
                  style: GoogleFonts.dmSans(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) {
                final enabled =
                    !sending && value.text.trim().isNotEmpty;
                return Material(
                  color: enabled ? AppColors.teal : AppColors.text4,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? onSend : null,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
