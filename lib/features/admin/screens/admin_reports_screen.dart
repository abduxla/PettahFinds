import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/report.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reportsAsync = ref.watch(
      StreamProvider<List<Report>>(
          (ref) => ref.read(reportRepositoryProvider).streamAll()),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: reportsAsync.when(
        data: (reports) => reports.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.flag_outlined, title: 'No reports')
            : ListView.builder(
                itemCount: reports.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final r = reports[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
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
                          if (r.businessId != null)
                            Text('Business: ${r.businessId}'),
                          if (r.productId != null)
                            Text('Product: ${r.productId}'),
                          Text(
                              'Reported: ${DateFormat.yMMMd().format(r.createdAt)}'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) async {
                          try {
                            await ref
                                .read(reportRepositoryProvider)
                                .updateStatus(r.id, status);
                            if (context.mounted) {
                              context.showSnackBar(
                                  'Report marked as $status');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              context.showSnackBar(e.toString(),
                                  isError: true);
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'pending', child: Text('Pending')),
                          PopupMenuItem(
                              value: 'reviewed', child: Text('Reviewed')),
                          PopupMenuItem(
                              value: 'resolved', child: Text('Resolved')),
                        ],
                        child: Chip(
                          label: Text(r.status.toUpperCase(),
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString()),
      ),
    );
  }
}
