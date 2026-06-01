import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/report.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/loading_widget.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(allReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: reportsAsync.when(
        data: (reports) => reports.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.flag_outlined, title: 'No reports')
            : ListView.builder(
                itemCount: reports.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) => AdminReportTile(report: reports[i]),
              ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString()),
      ),
    );
  }
}

/// Reusable report row used by the Reports tab AND the dashboard's
/// "Recent Reports" preview. Resolves the reported product / business
/// to its actual name via existing providers, surfaces the status,
/// and taps through to the right admin review surface:
///   • product report  → /product/:id?mode=admin
///   • business report → /admin/businesses/review/:id
/// Inside the popup menu the admin can also flip the report's status
/// (Pending / Reviewed / Resolved) without leaving the list.
class AdminReportTile extends ConsumerWidget {
  final Report report;
  const AdminReportTile({super.key, required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = report;

    // Resolve product / business names so the row reads as
    // "Product: Carrom Board" instead of "Product: 0CixkvKGn...".
    final productAsync = (r.productId != null && r.productId!.isNotEmpty)
        ? ref.watch(productByIdProvider(r.productId!))
        : null;
    final businessAsync = (r.businessId != null && r.businessId!.isNotEmpty)
        ? ref.watch(businessByIdProvider(r.businessId!))
        : null;

    final productLabel = productAsync?.when(
      data: (p) =>
          p?.title.trim().isNotEmpty == true ? p!.title : '(deleted)',
      loading: () => 'Loading…',
      error: (_, _) => '(unavailable)',
    );
    final businessLabel = businessAsync?.when(
      data: (b) => b?.businessName.trim().isNotEmpty == true
          ? b!.businessName
          : '(deleted)',
      loading: () => 'Loading…',
      error: (_, _) => '(unavailable)',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        // Tap → drill into the reported target's admin review surface.
        // Product reports use /product/:id?mode=admin (activate /
        // deactivate / delete CTAs). Business reports use the admin
        // business review screen (full info + product list + Approve).
        onTap: () {
          if (r.productId != null && r.productId!.isNotEmpty) {
            context.push('/product/${r.productId}?mode=admin');
          } else if (r.businessId != null && r.businessId!.isNotEmpty) {
            context.push('/admin/businesses/review/${r.businessId}');
          } else {
            context.showSnackBar(
                'This report has no product or business attached.',
                isError: true);
          }
        },
        leading: Icon(
          Icons.flag,
          color: r.status == 'pending'
              ? theme.colorScheme.error
              : r.status == 'reviewed'
                  ? Colors.orange
                  : Colors.green,
        ),
        title: Text(r.reason),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (productLabel != null) Text('Product: $productLabel'),
            if (businessLabel != null) Text('Business: $businessLabel'),
            if (r.details != null && r.details!.trim().isNotEmpty)
              Text('Note: ${r.details}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('Reported: ${DateFormat.yMMMd().format(r.createdAt)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (status) async {
            try {
              await ref
                  .read(reportRepositoryProvider)
                  .updateStatus(r.id, status);
              if (context.mounted) {
                context.showSnackBar('Report marked as $status');
              }
            } catch (e) {
              if (context.mounted) {
                context.showSnackBar(e.toString(), isError: true);
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'pending', child: Text('Pending')),
            PopupMenuItem(value: 'reviewed', child: Text('Reviewed')),
            PopupMenuItem(value: 'resolved', child: Text('Resolved')),
          ],
          child: Chip(
            label: Text(r.status.toUpperCase(),
                style: const TextStyle(fontSize: 11)),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
