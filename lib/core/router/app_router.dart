import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/loading_screen.dart';
import '../../features/customer/screens/customer_shell.dart';
import '../../features/customer/screens/home_screen.dart';
import '../../features/customer/screens/map_screen.dart';
import '../../features/customer/screens/search_screen.dart';
import '../../features/customer/screens/business_search_screen.dart';
import '../../features/customer/screens/category_businesses_screen.dart';
import '../../features/customer/screens/businesses_list_screen.dart';
import '../../features/customer/screens/business_detail_screen.dart';
import '../../features/customer/screens/products_list_screen.dart';
import '../../features/customer/screens/product_detail_screen.dart';
import '../../features/customer/screens/favorites_screen.dart';
import '../../features/customer/screens/profile_screen.dart';
import '../../features/customer/screens/notifications_screen.dart';
import '../../features/customer/screens/settings_screen.dart';
import '../../features/customer/screens/edit_customer_profile_screen.dart';
import '../../features/customer/screens/change_password_screen.dart';
import '../../features/customer/screens/support_screen.dart';
import '../../features/business/screens/business_shell.dart';
import '../../features/business/screens/business_dashboard_screen.dart';
import '../../features/business/screens/business_setup_screen.dart';
import '../../features/business/screens/manage_products_screen.dart';
import '../../features/business/screens/add_edit_product_screen.dart';
import '../../features/business/screens/business_profile_screen.dart';
import '../../features/business/screens/edit_business_profile_screen.dart';
import '../../features/business/screens/business_settings_screen.dart';
import '../../features/business/screens/business_reviews_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_businesses_screen.dart';
import '../../features/admin/screens/admin_products_screen.dart';
import '../../features/admin/screens/admin_reports_screen.dart';
import '../../features/legal/legal_document_screen.dart';
import '../../features/legal/legal_documents.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';

/// Public so non-router callers (FCM tap handler, deep links) can
/// reach BuildContext via rootNavigatorKey.currentState/.currentContext
/// without holding a Riverpod ref.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _customerShellKey = GlobalKey<NavigatorState>(debugLabel: 'customer');
final _businessShellKey = GlobalKey<NavigatorState>(debugLabel: 'business');
final _adminShellKey = GlobalKey<NavigatorState>(debugLabel: 'admin');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final appUser = ref.watch(appUserProvider);
  // Watch the mid-OAuth guard so the router rebuilds when it flips and
  // the redirect below can short-circuit during the handshake.
  final isHandlingSignIn = ref.watch(isHandlingSignInProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final currentPath = state.uri.path;

      // MID-OAUTH GUARD. While the Sign-Up / Sign-In screen is mid-
      // handshake (OAuth → existing-doc check → role picker → seed),
      // suppress every redirect. Without this, the appUserProvider's
      // first emission after seedAppUserIfMissing writes the doc
      // would race the still-running `_continueWithOAuth` Future: the
      // redirect sees signed-in + AppUser + on /sign-up (an auth
      // path) → returns roleHome() → router yanks the screen → the
      // post-await `if (!mounted) return;` short-circuits → no doc
      // write actually completes from the caller's perspective →
      // /loading sits empty → "Something went wrong" timeout.
      //
      // The flag is set in the screen's _continueWithOAuth before the
      // OAuth call and cleared in its finally{} block after the doc
      // is written (or the user cancels), so the suppression window
      // is exactly the danger window.
      if (isHandlingSignIn) return null;

      // Allow splash always — it handles its own navigation
      if (currentPath == '/splash') return null;

      // /loading is the post-auth landing pad. It owns its own
      // routing decisions (polls appUserProvider + has an emergency
      // sign-out). The redirect must never touch it or we'd race
      // against its own ref.listen handlers.
      if (currentPath == '/loading') return null;

      // Legal docs are reachable from everywhere (sign-up, settings, product
      // form), regardless of auth state or role.
      if (currentPath.startsWith('/legal/')) return null;

      // Chat surfaces handle their own guest gating + role logic.
      if (currentPath == '/chat' || currentPath.startsWith('/chat/')) {
        return null;
      }

      // Top-level /product/:id is role-agnostic — business owners
      // push to it with ?mode=owner to preview their own listing,
      // customers can deep-link to it too. Skip the role-shell
      // bounce below so business users aren't kicked to /business.
      if (currentPath.startsWith('/product/')) return null;

      // Top-level /edit-product/:id — opened from the owner-view's
      // Edit CTA. Lives outside the business shell so the cross-shell
      // push from /product/:id?mode=owner doesn't fail to mount the
      // shell (white-screen bug). Same skip-the-shell-bounce treatment
      // as /product/:id above.
      if (currentPath.startsWith('/edit-product/')) return null;

      // While auth is still initializing, don't redirect — stay put
      if (isAuthLoading) return null;

      final authPaths = ['/sign-in', '/sign-up', '/forgot-password', '/onboarding'];

      // Guests can browse the customer shell freely. Only business/admin
      // areas require an account — those surfaces that do require a user
      // (favorites, profile, notifications) render their own sign-in
      // prompt rather than being hard-redirected here.
      if (!isLoggedIn) {
        final needsAuth = currentPath.startsWith('/business') ||
            currentPath.startsWith('/business-profile') ||
            currentPath.startsWith('/business-messages') ||
            currentPath.startsWith('/business-settings') ||
            currentPath.startsWith('/admin');
        if (needsAuth) return '/sign-in';
        return null;
      }

      // Logged in. We need the AppUser to enforce role-based access.
      final user = appUser.valueOrNull;
      // CRITICAL stranded-auth guard.
      //
      // Firebase Auth has a user but the /users/{uid} doc hasn't
      // arrived yet — either the stream is still loading, the doc
      // genuinely doesn't exist (signup interrupted mid-flow), or a
      // recently-signed-up doc is still propagating. In every case we
      // route to /loading, which:
      //   • shows a teal spinner
      //   • listens for the doc and routes by role when it appears
      //   • surfaces an emergency Sign Out & Retry after 10s
      //
      // EXCEPT on the auth screens themselves — sign-up/sign-in own
      // their own post-OAuth navigation (role picker bottom sheet,
      // _routeAfterAuth) and a redirect here would yank the screen
      // out from under their `await showModalBottomSheet`.
      if (user == null) {
        if (authPaths.contains(currentPath)) return null;
        return '/loading';
      }

      String roleHome() {
        if (user.isAdmin) return '/admin';
        if (user.isBusiness) {
          if (user.businessId == null || user.businessId!.isEmpty) {
            return '/business/setup';
          }
          return '/business';
        }
        return '/home';
      }

      // Logged in but on auth page → redirect to role home
      if (authPaths.contains(currentPath)) {
        return roleHome();
      }

      // Business user without a business doc must finish setup before
      // accessing any business shell route.
      final needsSetup = user.isBusiness &&
          (user.businessId == null || user.businessId!.isEmpty);
      if (needsSetup && currentPath != '/business/setup') {
        // Allow them to bail out to /home or /sign-in only if explicitly
        // chosen — otherwise force to setup.
        if (currentPath.startsWith('/business') ||
            currentPath.startsWith('/business-profile') ||
            currentPath.startsWith('/business-messages') ||
            currentPath.startsWith('/business-settings') ||
            currentPath.startsWith('/home') ||
            currentPath.startsWith('/admin')) {
          return '/business/setup';
        }
      }

      // Role-shell mismatch guards: keep users inside their own shell.
      final inAdminShell = currentPath.startsWith('/admin');
      final inBusinessShell = currentPath == '/business/setup' ||
          currentPath.startsWith('/business') ||
          currentPath.startsWith('/business-profile') ||
          currentPath.startsWith('/business-messages') ||
          currentPath.startsWith('/business-settings');
      final inCustomerShell = currentPath.startsWith('/home') ||
          currentPath.startsWith('/search') ||
          currentPath.startsWith('/map') ||
          currentPath.startsWith('/favorites') ||
          currentPath.startsWith('/profile');

      if (user.isAdmin && !inAdminShell) {
        return '/admin';
      }
      if (user.isBusiness && !inBusinessShell) {
        return roleHome();
      }
      if (user.isUser && !inCustomerShell) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      // Post-auth landing pad — waits for /users/{uid} doc + routes by role.
      // See LoadingScreen for the rationale (stranded-auth recovery).
      GoRoute(path: '/loading', builder: (_, __) => const LoadingScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, __) => const SignUpScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),

      // --- Legal documents (accessible from anywhere, no auth required) ---
      GoRoute(
        path: '/legal/privacy',
        builder: (_, __) => const LegalDocumentScreen(
          title: LegalDocuments.privacyPolicyTitle,
          body: LegalDocuments.privacyPolicyBody,
        ),
      ),
      GoRoute(
        path: '/legal/user-terms',
        builder: (_, __) => const LegalDocumentScreen(
          title: LegalDocuments.userTermsTitle,
          body: LegalDocuments.userTermsBody,
        ),
      ),
      GoRoute(
        path: '/legal/business-listing-agreement',
        builder: (_, __) => const LegalDocumentScreen(
          title: LegalDocuments.businessListingTitle,
          body: LegalDocuments.businessListingBody,
        ),
      ),
      GoRoute(
        path: '/legal/prohibited-listings',
        builder: (_, __) => const LegalDocumentScreen(
          title: LegalDocuments.prohibitedListingsTitle,
          body: LegalDocuments.prohibitedListingsBody,
        ),
      ),

      // --- Product detail (top-level, role-agnostic) ---
      // Lives outside the customer shell so business owners can view
      // their OWN listing in read-only mode without being bounced by
      // the business-shell redirect rule. Customer access is still
      // available via /home/product/:id (sub-route inside the
      // customer shell), so both paths render the same screen.
      // Query param ?mode=owner toggles the read-only-with-Edit-CTA
      // variant; absence renders the standard customer view.
      GoRoute(
        path: '/product/:productId',
        builder: (_, state) => ProductDetailScreen(
          productId: state.pathParameters['productId']!,
        ),
      ),

      // Top-level edit-product route. Reachable from BOTH:
      //   • product owner view (/product/:id?mode=owner → Edit Product
      //     CTA — cross-shell push that used to white-screen against
      //     the shell-nested route)
      //   • Manage Products list inside the business shell (still
      //     pops back to /business/products via the navigator stack)
      // Single canonical edit screen; the AddEditProductScreen
      // reads currentUserBusinessProvider so it doesn't need the
      // business shell wrapper for context.
      GoRoute(
        path: '/edit-product/:productId',
        builder: (_, state) => AddEditProductScreen(
          productId: state.pathParameters['productId']!,
        ),
      ),

      // --- Chat (top-level so it can be opened from any shell) ---
      //
      // Nested parent/child structure so go_router treats /chat/:id as
      // a sub-route of /chat. Two payoffs:
      //   1) go('/chat/:id') builds the stack as [/chat, /chat/:id] —
      //      pop from the thread naturally returns to the inbox with
      //      the correct right-to-left "pop" slide direction.
      //   2) The back button on ChatScreen can just call pop() (with a
      //      go('/chat') fallback for deep-linked entry), which the
      //      Navigator animates in reverse — no more wrong-direction
      //      slide on back gestures.
      GoRoute(
        path: '/chat',
        builder: (_, __) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: ':conversationId',
            builder: (_, state) => ChatScreen(
              conversationId: state.pathParameters['conversationId']!,
            ),
          ),
        ],
      ),

      // --- Customer Shell ---
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            CustomerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _customerShellKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'businesses',
                    builder: (_, __) => const BusinessesListScreen(),
                  ),
                  GoRoute(
                    path: 'products',
                    builder: (_, __) => const ProductsListScreen(),
                  ),
                  GoRoute(
                    path: 'category/:categoryName',
                    builder: (_, state) => CategoryBusinessesScreen(
                      categoryName: state.pathParameters['categoryName']!,
                    ),
                  ),
                  GoRoute(
                    path: 'business/:businessId',
                    builder: (_, state) => BusinessDetailScreen(
                      businessId: state.pathParameters['businessId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'product/:productId',
                    builder: (_, state) => ProductDetailScreen(
                      productId: state.pathParameters['productId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
            // Businesses-side search, opened from the map screen's pill.
            // Sibling of /search on the same shell branch so the bottom nav
            // stays in place and the existing `startsWith('/search')`
            // redirect rule already covers it.
            GoRoute(
                path: '/search-businesses',
                builder: (_, __) => const BusinessSearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/favorites',
                builder: (_, __) => const FavoritesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
              routes: [
                GoRoute(
                    path: 'settings',
                    builder: (_, __) => const SettingsScreen()),
                GoRoute(
                    path: 'notifications',
                    builder: (_, __) => const NotificationsScreen()),
                GoRoute(
                    path: 'edit',
                    builder: (_, __) =>
                        const EditCustomerProfileScreen()),
                GoRoute(
                    path: 'password',
                    builder: (_, __) => const ChangePasswordScreen()),
                GoRoute(
                    path: 'support',
                    builder: (_, __) => const SupportScreen()),
              ],
            ),
          ]),
        ],
      ),

      // --- Business Shell ---
      GoRoute(
        path: '/business/setup',
        builder: (_, __) => const BusinessSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            BusinessShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _businessShellKey,
            routes: [
              GoRoute(
                path: '/business',
                builder: (_, __) => const BusinessDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'products',
                    builder: (_, __) => const ManageProductsScreen(),
                  ),
                  GoRoute(
                    path: 'products/add',
                    builder: (_, __) => const AddEditProductScreen(),
                  ),
                  // /business/products/edit/:id REMOVED. Edit now lives
                  // at the top-level /edit-product/:id route (see above)
                  // so the cross-shell push from the owner-view CTA
                  // doesn't try to remount the business shell — that
                  // remount was the white-screen bug.
                  GoRoute(
                    path: 'notifications',
                    builder: (_, __) =>
                        const NotificationsScreen(backPath: '/business'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/business-profile',
              builder: (_, __) => const BusinessProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, __) => const EditBusinessProfileScreen(),
                ),
              ],
            ),
          ]),
          // Messages branch — keeps the bottom nav visible while merchant
          // browses chats. Reuses the same ChatListScreen the customer
          // header icon opens; ChatListScreen self-detects role.
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/business-messages',
              builder: (_, __) => const ChatListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/business-settings',
              builder: (_, __) => const BusinessSettingsScreen(),
              routes: [
                GoRoute(
                  path: 'edit-profile',
                  builder: (_, __) => const EditBusinessProfileScreen(),
                ),
                GoRoute(
                  // /business-settings/reviews — Customer Reviews screen.
                  // Nested under the settings branch so pop returns to
                  // settings cleanly and the bottom-nav stays on the
                  // Settings tab while the merchant browses reviews.
                  path: 'reviews',
                  builder: (_, __) => const BusinessReviewsScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),

      // --- Admin Shell ---
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _adminShellKey,
            routes: [
              GoRoute(
                path: '/admin',
                builder: (_, __) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/businesses',
              builder: (_, __) => const AdminBusinessesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/products',
              builder: (_, __) => const AdminProductsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/reports',
              builder: (_, __) => const AdminReportsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
