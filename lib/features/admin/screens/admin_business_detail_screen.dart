import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../utils/price_format.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/loading_widget.dart';

/// Admin moderation surface for a single business.
///
/// Reachable from the admin Businesses list (`/admin/businesses`) by
/// tapping any row → `/admin/businesses/review/:id`. Stays inside the
/// admin shell so the bottom nav remains visible.
///
/// Capabilities (all enforced server-side by the `isAdmin()` rule):
///   • Review full business details (contact, category, owner, etc.)
///   • Approve / Un-approve via the toggle in the header card
///   • Audit every product the business has listed (active + inactive)
///   • Per-product Activate / Deactivate + Delete
///
/// Non-goals: editing business profile fields (admins shouldn't
/// silently edit a merchant's listing copy). Deleting the entire
/// business + cascading the owner's account is intentionally LEFT
/// on the parent list screen — destructive enough that the extra
/// hop is a feature.
class AdminBusinessDetailScreen extends ConsumerWidget {
  final String businessId;
  const AdminBusinessDetailScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(businessByIdProvider(businessId));

    return businessAsync.when(
      data: (business) {
        if (business == null) {
          return _scaffold(
            context,
            title: 'Business',
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Business not found. It may have been deleted.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _AdminBusinessDetailBody(business: business);
      },
      loading: () => _scaffold(context,
          title: 'Business', body: const LoadingWidget()),
      error: (e, _) => _scaffold(
        context,
        title: 'Business',
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(businessByIdProvider(businessId)),
        ),
      ),
    );
  }

  Scaffold _scaffold(BuildContext context,
      {required String title, required Widget body}) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/admin/businesses'),
        ),
        title: Text(
          title,
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: body,
    );
  }
}

class _AdminBusinessDetailBody extends ConsumerWidget {
  final Business business;
  const _AdminBusinessDetailBody({required this.business});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerAsync = ref.watch(userByIdProvider(business.ownerUid));
    final productsAsync =
        ref.watch(businessProductsProvider(business.id));

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/admin/businesses'),
        ),
        title: Text(
          'Review business',
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        children: [
          _HeaderCard(business: business),
          _DetailsCard(business: business, owner: ownerAsync.valueOrNull),
          _ProductsSection(
            businessId: business.id,
            productsAsync: productsAsync,
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Header card — verification status + approve / unapprove toggle
// =========================================================================
class _HeaderCard extends ConsumerWidget {
  final Business business;
  const _HeaderCard({required this.business});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending = !business.isVerified;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + name + status pill
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: business.logoUrl.isNotEmpty
                      ? CachedImage(
                          imageUrl: business.logoUrl,
                          width: 56,
                          height: 56,
                          placeholderIcon: Icons.store,
                        )
                      : Container(
                          color: AppColors.tealLight,
                          child: const Icon(Icons.store,
                              color: AppColors.teal, size: 26),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.businessName.isNotEmpty
                          ? business.businessName
                          : '(no name)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pending
                            ? Colors.orange.withAlpha(40)
                            : AppColors.tealLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pending ? 'Pending review' : 'Verified',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pending ? Colors.orange[900] : AppColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary moderation action — big approve / unapprove button.
          // Wraps businessRepository.toggleVerification(). Invalidates
          // businessByIdProvider so the header re-renders the new status.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () async {
                try {
                  await ref
                      .read(businessRepositoryProvider)
                      .toggleVerification(business.id, pending);
                  ref.invalidate(businessByIdProvider(business.id));
                  ref.invalidate(allBusinessesAdminProvider);
                  ref.invalidate(pendingBusinessesProvider);
                  if (context.mounted) {
                    context.showSuccessSnackBar(pending
                        ? '${business.businessName} approved — now visible to customers'
                        : '${business.businessName} unverified — hidden from customers');
                  }
                } catch (e) {
                  if (context.mounted) context.showErrorSnackBar(e);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    pending ? AppColors.teal : theme.colorScheme.errorContainer,
                foregroundColor: pending
                    ? Colors.white
                    : theme.colorScheme.onErrorContainer,
              ),
              icon: Icon(
                  pending ? Icons.check_circle_outline : Icons.block_rounded,
                  size: 18),
              label: Text(pending ? 'Approve business' : 'Un-approve'),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Details card — full business info + owner lookup
// =========================================================================
class _DetailsCard extends StatelessWidget {
  final Business business;
  final dynamic owner; // AppUser? — typed dynamic to avoid extra import
  const _DetailsCard({required this.business, required this.owner});

  @override
  Widget build(BuildContext context) {
    final ownerName = owner?.displayName?.toString().trim() ?? '';
    final ownerEmail = owner?.email?.toString().trim() ?? '';
    final ownerLabel = ownerName.isNotEmpty && ownerEmail.isNotEmpty
        ? '$ownerName ($ownerEmail)'
        : ownerName.isNotEmpty
            ? ownerName
            : ownerEmail.isNotEmpty
                ? ownerEmail
                : 'uid ${business.ownerUid}';

    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text1,
            ),
          ),
          const SizedBox(height: 10),
          _kv('Owner', ownerLabel),
          _kv('Owner UID', business.ownerUid),
          _kv('Category', business.category),
          _kv('Location', business.location),
          _kv('Phone', business.phone.isNotEmpty ? business.phone : '—'),
          _kv('WhatsApp',
              business.whatsappNumber.isNotEmpty ? business.whatsappNumber : '—'),
          _kv('Email', business.email.isNotEmpty ? business.email : '—'),
          if (business.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Description',
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 0.4,
                )),
            const SizedBox(height: 4),
            Text(business.description,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: AppColors.text1,
                  height: 1.45,
                )),
          ],
          if (business.createdByAdminUid != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      color: AppColors.teal, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Onboarded by admin',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.text3,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.text1,
                )),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Products section — admin actions: toggle active, hard delete
// =========================================================================
class _ProductsSection extends StatelessWidget {
  final String businessId;
  final AsyncValue<List<Product>> productsAsync;
  const _ProductsSection({
    required this.businessId,
    required this.productsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Products',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text1,
                ),
              ),
              const SizedBox(width: 6),
              productsAsync.when(
                data: (list) => Text('(${list.length})',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: AppColors.text3,
                    )),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No products listed.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.text3,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final p in products)
                    _AdminProductTile(product: p, businessId: businessId),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Couldn\'t load products: $e',
                style: GoogleFonts.dmSans(
                    fontSize: 12.5, color: AppColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminProductTile extends ConsumerStatefulWidget {
  final Product product;
  final String businessId;
  const _AdminProductTile({required this.product, required this.businessId});

  @override
  ConsumerState<_AdminProductTile> createState() =>
      _AdminProductTileState();
}

class _AdminProductTileState extends ConsumerState<_AdminProductTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Opacity(
      opacity: p.isActive ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgSection,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: p.image1Url.isNotEmpty
                    ? CachedImage(
                        imageUrl: p.image1Url,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        placeholderIcon: Icons.shopping_bag_outlined,
                      )
                    : Container(
                        color: AppColors.tealLight,
                        child: const Icon(Icons.shopping_bag_outlined,
                            color: AppColors.teal, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title.isNotEmpty ? p.title : '(no title)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text1,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'LKR ${formatLkr(p.priceLkr)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.isActive
                              ? AppColors.tealLight
                              : AppColors.red.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.isActive ? 'Active' : 'Inactive',
                          style: GoogleFonts.dmSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color:
                                p.isActive ? AppColors.teal : AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.text3),
                onSelected: (val) async {
                  if (val == 'toggle') {
                    await _toggleActive();
                  } else if (val == 'delete') {
                    await _confirmDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          p.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(p.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive() async {
    final p = widget.product;
    setState(() => _busy = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .update(p.copyWith(isActive: !p.isActive));
      if (mounted) {
        context.showSuccessSnackBar(
            p.isActive ? 'Product deactivated' : 'Product activated');
      }
      // No explicit invalidate needed — businessProductsProvider is a
      // stream and auto-emits the updated doc.
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final p = widget.product;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '"${p.title}" will be permanently removed from this business\'s '
          'listings. The merchant will not be notified.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(productRepositoryProvider).hardDelete(p.id);
      if (mounted) context.showSuccessSnackBar('Product deleted');
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
