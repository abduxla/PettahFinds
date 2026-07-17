import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

/// Lets a user review and unblock people they've blocked. Reachable
/// from the profile menu. Part of the App Store Guideline 1.2 user-
/// safety set (block + flag + manage). Blocking happens inline on
/// chat / reviews; this screen is the management surface.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(realUserProvider);
    final blockedAsync = ref.watch(blockedUidsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: Text(
          'Blocked Users',
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: blockedAsync.when(
        data: (uids) {
          if (uids.isEmpty) {
            return _empty();
          }
          final list = uids.toList();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _BlockedUserTile(
              blockedUid: list[i],
              blockerUid: me?.uid ?? '',
            ),
          );
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.teal)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Couldn\'t load: $e',
                style: GoogleFonts.dmSans(color: AppColors.text3)),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.block_rounded,
                  color: AppColors.teal, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'No blocked users',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When you block someone from a chat or review, they show up '
              'here. You can unblock them anytime.',
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
}

class _BlockedUserTile extends ConsumerWidget {
  final String blockedUid;
  final String blockerUid;
  const _BlockedUserTile({
    required this.blockedUid,
    required this.blockerUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByIdProvider(blockedUid));
    final user = userAsync.valueOrNull;
    final name = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : (user?.email.trim().isNotEmpty == true
            ? user!.email
            : 'User ${blockedUid.length > 6 ? blockedUid.substring(0, 6) : blockedUid}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.tealLight,
            child: Icon(Icons.person_rounded, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await ref.read(blockRepositoryProvider).unblockUser(
                      blockerUid: blockerUid,
                      blockedUid: blockedUid,
                    );
                if (context.mounted) {
                  context.showSuccessSnackBar('Unblocked');
                }
              } catch (e) {
                if (context.mounted) context.showErrorSnackBar(e);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              side: BorderSide(color: AppColors.teal),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }
}
