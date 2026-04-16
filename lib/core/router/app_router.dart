import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/customer/screens/customer_shell.dart';
import '../../features/customer/screens/home_screen.dart';
import '../../features/customer/screens/map_screen.dart';
import '../../features/customer/screens/search_screen.dart';
import '../../features/customer/screens/category_businesses_screen.dart';
import '../../features/customer/screens/businesses_list_screen.dart';
import '../../features/customer/screens/business_detail_screen.dart';
import '../../features/customer/screens/products_list_screen.dart';
import '../../features/customer/screens/product_detail_screen.dart';
import '../../features/customer/screens/favorites_screen.dart';
import '../../features/customer/screens/profile_screen.dart';
import '../../features/customer/screens/notifications_screen.dart';
import '../../features/customer/screens/settings_screen.dart';
import '../../features/business/screens/business_shell.dart';
import '../../features/business/screens/business_dashboard_screen.dart';
import '../../features/business/screens/business_setup_screen.dart';
import '../../features/business/screens/manage_products_screen.dart';
import '../../features/business/screens/add_edit_product_screen.dart';
import '../../features/business/screens/business_profile_screen.dart';
import '../../features/business/screens/edit_business_profile_screen.dart';
import '../../features/business/screens/business_settings_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_businesses_screen.dart';
import '../../features/admin/screens/admin_products_screen.dart';
import '../../features/admin/screens/admin_reports_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _customerShellKey = GlobalKey<NavigatorState>(debugLabel: 'customer');
final _businessShellKey = GlobalKey<NavigatorState>(debugLabel: 'business');
final _adminShellKey = GlobalKey<NavigatorState>(debugLabel: 'admin');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final appUser = ref.watch(appUserProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final currentPath = state.uri.path;

      // Allow splash always — it handles its own navigation
      if (currentPath == '/splash') return null;

      // While auth is still initializing, don't redirect — stay put
      if (isAuthLoading) return null;

      // Not logged in → sign in (unless already on auth pages)
      final authPaths = ['/sign-in', '/sign-up', '/forgot-password', '/onboarding'];
      if (!isLoggedIn) {
        return authPaths.contains(currentPath) ? null : '/sign-in';
      }

      // Logged in. We need the AppUser to enforce role-based access.
      final user = appUser.valueOrNull;
      // AppUser still loading from Firestore — don't redirect yet
      if (user == null) return null;

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
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, __) => const SignUpScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),

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
                  GoRoute(
                    path: 'products/edit/:productId',
                    builder: (_, state) => AddEditProductScreen(
                      productId: state.pathParameters['productId'],
                    ),
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
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/business-settings',
              builder: (_, __) => const BusinessSettingsScreen(),
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
