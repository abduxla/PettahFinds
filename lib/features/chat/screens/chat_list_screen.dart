import 'dart:async';
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
          // Same canPop-gated leading as the signed-in branch.
          // Guests usually arrive here via push() from the home AppBar
          // chat icon, so canPop is true and the arrow lets them pop
          // back. If they deep-linked /chat directly there's nothing
          // to pop — hide the arrow and let them use the home tab.
          leading: context.canPop()
              ? IconButton(
                  icon:
                      const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: AppColors.text1,
                  onPressed: () => context.pop(),
                )
              : null,
          automaticallyImplyLeading: false,
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
          // Leading arrow renders ONLY when there's a real Navigator
          // entry to pop back to. When the messages screen is reached
          // via the BUSINESS bottom-nav tab (StatefulShellRoute branch
          // → goBranch), canPop() is false and there's no Navigator
          // stack — swipe-back is a no-op by design. Hiding the arrow
          // makes the UI honest about that: the bottom-nav Dashboard
          // tab is the way back. When reached via push() from a
          // drill-down (home AppBar chat icon, profile→messages,
          // business-settings→messages — all use push()) canPop() is
          // true and the arrow + swipe-back both work normally.
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: AppColors.text1,
                  onPressed: () => context.pop(),
                )
              : null,
          // Without an automatic back arrow, Flutter would still try
          // to render the implicit one. Tell it not to bother — null
          // leading + this flag together leave a clean header.
          automaticallyImplyLeading: false,
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

class _CustomerList extends ConsumerStatefulWidget {
  final String uid;
  const _CustomerList({required this.uid});

  @override
  ConsumerState<_CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends ConsumerState<_CustomerList> {
  Timer? _watchdog;
  bool _stuck = false;

  void _arm() {
    _watchdog?.cancel();
    _stuck = false;
    _watchdog = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _stuck = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customerConversationsProvider(widget.uid));
    return async.when(
      data: (items) {
        _watchdog?.cancel();
        return _renderList(context, items, viewerIsSeller: false);
      },
      loading: () => _stuck
          ? _StuckRetry(
              onRetry: () {
                _arm();
                ref.invalidate(customerConversationsProvider(widget.uid));
              },
            )
          : const _ChatListSkeleton(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () {
          _arm();
          ref.invalidate(customerConversationsProvider(widget.uid));
        },
      ),
    );
  }
}

class _SellerList extends ConsumerStatefulWidget {
  final String uid;
  const _SellerList({required this.uid});

  @override
  ConsumerState<_SellerList> createState() => _SellerListState();
}

class _SellerListState extends ConsumerState<_SellerList> {
  Timer? _watchdog;
  bool _stuck = false;

  void _arm() {
    _watchdog?.cancel();
    _stuck = false;
    _watchdog = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _stuck = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerConversationsProvider(widget.uid));
    return async.when(
      data: (items) {
        _watchdog?.cancel();
        return _renderList(context, items, viewerIsSeller: true);
      },
      loading: () => _stuck
          ? _StuckRetry(
              onRetry: () {
                _arm();
                ref.invalidate(sellerConversationsProvider(widget.uid));
              },
            )
          : const _ChatListSkeleton(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () {
          _arm();
          ref.invalidate(sellerConversationsProvider(widget.uid));
        },
      ),
    );
  }
}

class _StuckRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _StuckRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_tethering_error_rounded,
                color: AppColors.text4, size: 36),
            const SizedBox(height: 12),
            Text(
              'Taking longer than usual...',
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: AppColors.text2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.text3,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
              ),
            ),
          ],
        ),
      ),
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
