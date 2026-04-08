import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/business.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

class AdminBusinessesScreen extends ConsumerWidget {
  const AdminBusinessesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final businessesAsync = ref.watch(
      StreamProvider<List<Business>>(
          (ref) => ref.read(businessRepositoryProvider).streamAll()),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('All Businesses')),
      body: businessesAsync.when(
        data: (businesses) => businesses.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.store_outlined, title: 'No businesses')
            : ListView.builder(
                itemCount: businesses.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final b = businesses[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: b.logoUrl.isNotEmpty
                            ? NetworkImage(b.logoUrl)
                            : null,
                        child: b.logoUrl.isEmpty
                            ? const Icon(Icons.store)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(b.businessName)),
                          if (b.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 16,
                                color: theme.colorScheme.primary),
                          ],
                        ],
                      ),
                      subtitle: Text(
                          '${b.category} • ${b.location}\nOwner: ${b.ownerUid}',
                          maxLines: 2),
                      trailing: Switch(
                        value: b.isVerified,
                        onChanged: (val) async {
                          try {
                            await ref
                                .read(businessRepositoryProvider)
                                .toggleVerification(b.id, val);
                            if (context.mounted) {
                              context.showSnackBar(
                                val
                                    ? '${b.businessName} verified'
                                    : '${b.businessName} unverified',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              context.showSnackBar(e.toString(),
                                  isError: true);
                            }
                          }
                        },
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
