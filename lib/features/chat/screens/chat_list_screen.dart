import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/conversation.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/sign_in_required.dart';
import '../widgets/conversation_tile.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    if (authState.valueOrNull == null && !authState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgSection,
        appBar: AppBar(
          backgroundColor: AppColors.bgSection,
          title: Text('Messages', style: _title()),
        ),
        body: const SignInRequired(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Sign in to message sellers',
          subtitle:
              'Chat directly with Pettah businesses about their products.',
        ),
      );
    }
    if (appUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgSection,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    final isBusiness = appUser.isBusiness;
    return DefaultTabController(
      length: isBusiness ? 2 : 1,
      child: Scaffold(
        backgroundColor: AppColors.bgSection,
        appBar: AppBar(
          backgroundColor: AppColors.bgSection,
          title: Text('Messages', style: _title()),
          bottom: isBusiness
              ? TabBar(
                  indicatorColor: AppColors.teal,
                  labelColor: AppColors.teal,
                  unselectedLabelColor: AppColors.text3,
                  labelStyle: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Inbox'),
                    Tab(text: 'My questions'),
                  ],
                )
              : null,
        ),
        body: isBusiness
            ? TabBarView(
                children: [
                  _SellerList(uid: appUser.uid),
                  _CustomerList(uid: appUser.uid),
                ],
              )
            : _CustomerList(uid: appUser.uid),
      ),
    );
  }

  TextStyle _title() => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.text1,
        letterSpacing: -0.3,
      );
}

class _CustomerList extends ConsumerWidget {
  final String uid;
  const _CustomerList({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerConversationsProvider(uid));
    return async.when(
      data: (items) =>
          _renderList(context, items, viewerIsSeller: false),
      loading: () => const _ChatListSkeleton(),
      error: (e, _) => AppErrorWidget(message: e.toString()),
    );
  }
}

class _SellerList extends ConsumerWidget {
  final String uid;
  const _SellerList({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerConversationsProvider(uid));
    return async.when(
      data: (items) => _renderList(context, items, viewerIsSeller: true),
      loading: () => const _ChatListSkeleton(),
      error: (e, _) => AppErrorWidget(message: e.toString()),
    );
  }
}

Widget _renderList(BuildContext context, List<Conversation> items,
    {required bool viewerIsSeller}) {
  if (items.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.teal, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              viewerIsSeller ? 'No customer messages yet' : 'No chats yet',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              viewerIsSeller
                  ? 'When customers message about your products, threads will show up here.'
                  : 'Open a product and tap Chat Seller to start a conversation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.text3,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (_, i) => ConversationTile(
      conversation: items[i],
      viewerIsSeller: viewerIsSeller,
      onTap: () => context.go('/chat/${items[i].id}'),
    ),
  );
}

class _ChatListSkeleton extends StatelessWidget {
  const _ChatListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) =>
          const ShimmerBox(height: 76, radius: 12),
    );
  }
}
