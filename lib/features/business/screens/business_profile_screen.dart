import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';

class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return businessAsync.when(
      data: (businessDynamic) {
        if (businessDynamic == null) {
          return const Scaffold(body: Center(child: Text('No business')));
        }
        final business = businessDynamic as Business;

        return Scaffold(
          backgroundColor: AppColors.bgSection,
          body: CustomScrollView(
            slivers: [
              // Hero banner
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.tealDark,
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/business'),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      backgroundColor: Colors.black26,
                      child: IconButton(
                        icon:
                            const Icon(Icons.edit_rounded, color: Colors.white),
                        onPressed: () => context.go('/business-profile/edit'),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedImage(
                    imageUrl: business.bannerUrl,
                    height: 200,
                    width: double.infinity,
                    placeholderIcon: Icons.storefront,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + name + category
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.teal.withValues(alpha: 0.25),
                                  width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 34,
                              backgroundColor: AppColors.tealLight,
                              backgroundImage: business.logoUrl.isNotEmpty
                                  ? NetworkImage(business.logoUrl)
                                  : null,
                              child: business.logoUrl.isEmpty
                                  ? const Icon(Icons.store,
                                      size: 30, color: AppColors.teal)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(business.businessName,
                                          style: GoogleFonts.nunito(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: AppColors.text1,
                                          )),
                                    ),
                                    if (business.isVerified) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified,
                                          size: 20, color: AppColors.teal),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.tealLight,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(business.category,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.teal,
                                          )),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.bg,
                                        border: Border.all(
                                            color: AppColors.border),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                          business.membershipTier
                                              .toUpperCase(),
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text2,
                                          )),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Rating
                      if (business.ratingCount > 0) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              RatingBarIndicator(
                                rating: business.ratingAvg,
                                itemSize: 20,
                                itemBuilder: (_, _) => const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.orange),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                business.ratingAvg.toStringAsFixed(1),
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text1,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                ' (${business.ratingCount} reviews)',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.text3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Description
                      const SizedBox(height: 20),
                      Text(business.description,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            height: 1.55,
                            color: AppColors.text2,
                          )),

                      const SizedBox(height: 24),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 16),

                      // Contact info
                      Text('Contact',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppColors.text1,
                          )),
                      const SizedBox(height: 12),
                      _InfoRow(
                          Icons.location_on_outlined, business.location),
                      _InfoRow(Icons.phone_outlined, business.phone),
                      _InfoRow(Icons.email_outlined, business.email),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: DetailSkeleton()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _InfoRow(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text1,
                )),
          ),
        ],
      ),
    );
  }
}
