import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/extensions/context_extensions.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_colors.dart';

/// Shows a confirmation dialog and, if confirmed, blocks [blockedUid]
/// on behalf of the signed-in user. Blocking:
///   • removes the blocked user's content from the blocker's feed
///     instantly (the blockedUidsProvider stream emits immediately), and
///   • files a report so the developer/admins are notified.
///
/// Returns true if the block was performed, false if cancelled / failed.
///
/// Used from the chat thread, review tiles, and seller/listing surfaces
/// to satisfy App Store Guideline 1.2 (user-generated content safety).
Future<bool> showBlockUserDialog(
  BuildContext context,
  WidgetRef ref, {
  required String blockedUid,
  String? blockedName,
  String? context_, // optional moderation context, e.g. conversation id
}) async {
  final me = ref.read(authStateProvider).valueOrNull;
  if (me == null) {
    context.showErrorSnackBar('Sign in to block users.');
    return false;
  }
  if (me.uid == blockedUid) {
    context.showErrorSnackBar('You can\'t block yourself.');
    return false;
  }

  final name = (blockedName != null && blockedName.trim().isNotEmpty)
      ? blockedName.trim()
      : 'this user';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.red, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Block $name?',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 18)),
          ),
        ],
      ),
      content: Text(
        'You will no longer see their messages, reviews, or listings, and '
        'they will be removed from your feed immediately. We\'ll also '
        'notify our team to review the content.',
        style: GoogleFonts.dmSans(
            fontSize: 13.5, height: 1.45, color: AppColors.text2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Block & Report'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;
  if (!context.mounted) return false;

  try {
    await ref.read(blockRepositoryProvider).blockUser(
          blockerUid: me.uid,
          blockedUid: blockedUid,
          context: context_,
        );
    if (context.mounted) {
      context.showSuccessSnackBar(
          'Blocked. Their content has been removed from your feed.');
    }
    return true;
  } catch (e) {
    if (context.mounted) context.showErrorSnackBar(e);
    return false;
  }
}
