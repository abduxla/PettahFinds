import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/extensions/context_extensions.dart';
import '../core/providers/providers.dart';
import '../services/account_deletion_service.dart';

/// Self-delete confirmation flow. Two safety gates:
///   1. The user must type the literal word DELETE.
///   2. Firebase requires a recent sign-in to remove the Auth account;
///      when [deleteSelf] throws RequiresRecentLoginException we present
///      the appropriate re-auth UI (password field or Google picker)
///      and retry once.
///
/// On success, navigates to /sign-in and surfaces a success snackbar
/// from there. The caller is unmounted by then.
Future<void> showDeleteAccountFlow(BuildContext context, WidgetRef ref,
    {required bool isBusinessOwner}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConfirmDeleteDialog(isBusinessOwner: isBusinessOwner),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  await _runDeleteWithReauth(context, ref);
}

Future<void> _runDeleteWithReauth(
    BuildContext context, WidgetRef ref) async {
  // Block the UI with a transparent barrier + spinner while the cascade
  // runs. The cascade can take a few seconds on accounts with many
  // documents, and tapping around mid-delete would be confusing.
  final service = ref.read(accountDeletionServiceProvider);
  _showBlockingSpinner(context);

  try {
    await service.deleteSelf();
    if (!context.mounted) return;
    _dismissBlockingSpinner(context);
    context.go('/sign-in');
    context.showSuccessSnackBar('Your account has been deleted.');
    return;
  } on RequiresRecentLoginException {
    if (!context.mounted) return;
    _dismissBlockingSpinner(context);
  } catch (e) {
    if (!context.mounted) return;
    _dismissBlockingSpinner(context);
    context.showErrorSnackBar(e);
    return;
  }

  // Re-auth path.
  final reauthed = await _runReauth(context, ref);
  if (!reauthed) return;
  if (!context.mounted) return;

  _showBlockingSpinner(context);
  try {
    await service.deleteSelf();
    if (!context.mounted) return;
    _dismissBlockingSpinner(context);
    context.go('/sign-in');
    context.showSuccessSnackBar('Your account has been deleted.');
  } catch (e) {
    if (!context.mounted) return;
    _dismissBlockingSpinner(context);
    context.showErrorSnackBar(e);
  }
}

Future<bool> _runReauth(BuildContext context, WidgetRef ref) async {
  final service = ref.read(accountDeletionServiceProvider);

  if (service.currentUserIsGoogle) {
    // Google flow: a single explainer dialog, then trigger the picker.
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm with Google'),
        content: const Text(
            'Firebase needs you to sign in with Google one more time to '
            'confirm this destructive action. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (go != true) return false;
    if (!context.mounted) return false;
    try {
      await service.reauthenticateWithGoogle();
      return true;
    } catch (e) {
      if (context.mounted) context.showErrorSnackBar(e);
      return false;
    }
  }

  // Password flow.
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm with your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Firebase needs your password to confirm this destructive '
              'action.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm')),
      ],
    ),
  );
  if (ok != true) return false;
  if (!context.mounted) return false;
  try {
    await service.reauthenticateWithPassword(ctrl.text);
    return true;
  } catch (e) {
    if (context.mounted) context.showErrorSnackBar(e);
    return false;
  }
}

void _showBlockingSpinner(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(),
        ),
      ),
    ),
  );
}

void _dismissBlockingSpinner(BuildContext context) {
  // The spinner is the topmost dialog; one pop removes it.
  if (Navigator.canPop(context)) Navigator.pop(context);
}

class _ConfirmDeleteDialog extends StatefulWidget {
  final bool isBusinessOwner;
  const _ConfirmDeleteDialog({required this.isBusinessOwner});

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final _ctrl = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final now = _ctrl.text.trim().toUpperCase() == 'DELETE';
      if (now != _canDelete) setState(() => _canDelete = now);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          const Text('Delete account?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isBusinessOwner
                ? 'This permanently deletes your account, your business listing, all products on it, every review you\'ve written, every conversation you\'ve had, and all your saved items. It cannot be undone.'
                : 'This permanently deletes your account, every review you\'ve written, every conversation you\'ve had, and all your saved items. It cannot be undone.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'Type DELETE to confirm:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'DELETE',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}
