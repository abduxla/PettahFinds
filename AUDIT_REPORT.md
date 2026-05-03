# PetaFinds — Project Audit Report

**Date:** 2026-04-30
**Branch:** main (clean)
**flutter analyze:** 66 issues — 0 errors, 1 warning, 65 info (mostly `unnecessary_underscores`, 3 `deprecated_member_use`)

This audit inspects code only — no changes made. Issues are grouped by severity. Each entry follows: **Issue · File · Why bad · User impact · Fix · Priority**.

---

## 1. Critical Blockers

### 1.1 Firestore rule lets ANY signed-in user mutate `ratingAvg` / `ratingCount` on any business
- **File:** `firebase/firestore.rules:104-109`
- **Why bad:** The escape clause `affectedKeys().hasOnly(['ratingAvg', 'ratingCount'])` permits any signed-in user to write any value to these fields on any business. There is no check that the writer ever created a review, no clamping, no business-existence check.
- **User impact:** Trivial ranking manipulation. A bad actor can pin any competitor to 0.0 / 1 review or boost their own to 5.0 / 99999 reviews from the client. Public app, public abuse vector.
- **Fix:** Move rating aggregation into a Cloud Function triggered by `onCreate` of `reviews/*`. Block all client writes to those two fields. Until then, restrict to numeric ranges + delta-only writes from the review author at minimum.
- **Priority:** P0

### 1.2 Notifications can never be created — system is dead in production
- **File:** `firebase/firestore.rules:207`, `lib/repositories/notification_repository.dart`
- **Why bad:** Rule says `allow create: if isAdmin();` and the repo has no `create()` method. There is no Cloud Function in the repo. Nothing can write notifications, so the bell, notifications screen, and "Mark all read" are decorative.
- **User impact:** Notifications screen is permanently empty for everyone. Feature ships broken.
- **Fix:** Either ship a Cloud Functions package that mints notifications on review/order/report events, or remove the feature from the UI until backend exists. If keeping for now, set expectations clearly.
- **Priority:** P0

### 1.3 Product / business search loads the entire collection client-side
- **Files:** `lib/repositories/product_repository.dart:89-99`, `lib/repositories/business_repository.dart:77-87`
- **Why bad:** `search()` does `_ref.where('isActive', isEqualTo: true).get()` (or unfiltered for businesses) with **no `limit()`**, then filters in memory by substring. Cost scales with every product/business in Firestore, not with results.
- **User impact:** At 5k products this is ~5k document reads per search and noticeable lag. At 50k, billing & latency become unsustainable. Also burns mobile data.
- **Fix:** Add Algolia / Typesense (referenced in privacy policy already), or at minimum add `keywordsLower` denormalised array fields and use `array-contains` with `.limit(50)`. Cache on client.
- **Priority:** P0

### 1.4 Email sign-up has no email verification gate
- **File:** `lib/repositories/auth_repository.dart:33-62`, `lib/features/auth/screens/sign_in_screen.dart`
- **Why bad:** `signUp` creates the account and the AppUser doc immediately. `signIn` does not check `user.emailVerified`. Anyone can register with `someone-else@gmail.com`, never confirm it, and start writing reviews/reports/listings.
- **User impact:** Spam accounts, impersonation, abusive reviews, abusive reports — all hard to attribute. Also breaks legal compliance for "we know who you are" claims in Terms.
- **Fix:** Call `cred.user!.sendEmailVerification()` at signup. Gate sign-in or sensitive actions (reviews, reports, business creation) behind `currentUser.emailVerified`.
- **Priority:** P0

### 1.5 `currentUserBusinessProvider` is `Provider<dynamic>` with no autoDispose / invalidation
- **File:** `lib/core/providers/providers.dart:93-100`
- **Why bad:** Returns `dynamic` (loses type safety; consumers cast to `Business`). It's a `FutureProvider` (not autoDispose), never invalidated after edits. Stale business data across the business shell.
- **User impact:** Owner edits business profile → goes back to dashboard → still sees old data. Has to kill the app to see changes.
- **Fix:** Type as `FutureProvider<Business?>`. Add `ref.invalidate(currentUserBusinessProvider)` after every successful business update / setup.
- **Priority:** P0

---

## 2. High Priority Bugs

### 2.1 Admin dashboard creates new StreamProviders inside `build()`
- **File:** `lib/features/admin/screens/admin_dashboard_screen.dart:16-27`
- **Why bad:** Every rebuild constructs three new `StreamProvider` instances, leaking the previous Firestore subscriptions. Admin screen is the most-watched page; this leaks fast.
- **User impact:** Memory growth, duplicate listeners, possible quota hits over time.
- **Fix:** Lift the providers to top-level (like `allActiveProductsProvider` already is), then `ref.watch` the existing top-level provider.
- **Priority:** P1

### 2.2 Favorite toggle is racy
- **File:** `lib/repositories/favorite_repository.dart:14-38`
- **Why bad:** Read-then-write without a transaction. Double-tap or fast network can create duplicate favorite docs for the same `(userId, targetType, targetId)`.
- **User impact:** Duplicate hearts, inconsistent state, "unfavorite" leaving a dangling doc.
- **Fix:** Use a deterministic doc id (e.g. `${userId}_${targetType}_${targetId}`) and a transaction or `set(merge:false)` with `exists` precondition.
- **Priority:** P1

### 2.3 Recently-viewed resolves products serially
- **File:** `lib/core/providers/providers.dart:57-72`
- **Why bad:** Iterates IDs and calls `repo.getById()` one at a time. N round trips on the home screen mount.
- **User impact:** Visible lag / waterfall on home open when ≥3 recently viewed.
- **Fix:** Batch with `Future.wait` or use `whereIn` (max 30) for a single Firestore query.
- **Priority:** P1

### 2.4 Splash 8-second timeout drops admin/business users on `/home` momentarily
- **File:** `lib/features/auth/screens/splash_screen.dart:47`
- **Why bad:** If AppUser stream is slow, timeout fires `_goGuestStart()` even when a Firebase user exists. They land on `/home`, then router redirect bounces them to the role home — visible flicker, broken back stack.
- **User impact:** Admin/business users may briefly see customer home, then be teleported. Confusing on first launch with cold network.
- **Fix:** Branch the timeout: if `authState.valueOrNull != null`, route to `_routeByRole` with a fallback default; only guests should hit `/home` / `/onboarding`.
- **Priority:** P1

### 2.5 Settings screen "Edit Profile" / "Change Password" buttons do nothing
- **File:** `lib/features/customer/screens/settings_screen.dart:29-39`
- **Why bad:** Tapping does nothing (TODO stubs). No snackbar, no "coming soon".
- **User impact:** Looks broken to the user. They'll think the app is buggy.
- **Fix:** Either implement, or show a "Coming soon" snackbar like the business membership tile already does.
- **Priority:** P1

### 2.6 Reviews can be created without verifying the business exists
- **File:** `firebase/firestore.rules:158-163`
- **Why bad:** Rule only checks `businessId is string`. Anyone can spam-create reviews against fake or arbitrary IDs.
- **User impact:** Spam reviews bloating the collection; bad data feeding rating writes (which are themselves unprotected — see 1.1).
- **Fix:** Add `exists(/databases/$(database)/documents/businesses/$(request.resource.data.businessId))` to the create rule.
- **Priority:** P1

### 2.7 Splash → `/onboarding` writes prefs only after the user reaches slide 3 or taps Skip
- **File:** `lib/features/auth/screens/onboarding_screen.dart`
- **Why bad:** If the user kills the app on slide 1, onboarding replays next launch — fine. But if they backgrounded mid-flow and came back hours later, same thing. Acceptable, but the splash route is `/home` for the timeout fallback and `/onboarding` only for fresh prefs check — race possible if SharedPreferences resolves slow.
- **User impact:** Edge: very slow disk I/O could cause onboarding to replay once on reinstall.
- **Fix:** Read the flag once early (in `initState`) and stash, then make routing decisions from the in-memory copy.
- **Priority:** P1

### 2.8 Storage rules path comment vs upload path mismatch
- **File:** `firebase/storage.rules:46-49`, `lib/features/business/screens/add_edit_product_screen.dart:131`
- **Why bad:** Comment says uploads go to `/products/{businessId}/{productId}/...` but the app actually uploads `/products/{businessId}/{ts}_{i}.{ext}` (no productId segment, since productId doesn't exist at upload time for new products). Rule still works because `{allPaths=**}` is permissive, but the documented contract is wrong.
- **User impact:** Future maintainers will tighten the rule based on the comment, breaking uploads.
- **Fix:** Update the comment to match the actual layout, or refactor uploads to write under `/products/{businessId}/{productId}/...` (need productId allocated before upload, e.g. `_ref.doc().id`).
- **Priority:** P1

### 2.9 No business existence check on product create at write time
- **File:** `firebase/firestore.rules:125-126`
- **Why bad:** `ownsBusiness()` does check ownership via Firestore `get`, so this is fine. (Marking as **OK** — kept as a checklist item only.)
- **Priority:** N/A — verified safe.

---

## 3. Medium Priority Bugs

### 3.1 No `limit()` on home / list streams
- **Files:** `lib/repositories/product_repository.dart:72-78` (`streamAll`), `lib/repositories/business_repository.dart:54-58`
- **Why bad:** `streamAll()` streams every active product to every customer device.
- **User impact:** Cost scales with directory size; cold-load on home will get slower.
- **Fix:** Add `.limit(100)` server-side, paginate further with `startAfter`.
- **Priority:** P2

### 3.2 `firebase_options.dart` is committed; `windows` reuses web's appId
- **File:** `lib/firebase_options.dart:82-89`
- **Why bad:** Windows app ID matches web's web appId; not a security issue (FlutterFire generates this), but worth noting if Windows is a release target.
- **User impact:** Analytics / messaging may misattribute on Windows.
- **Fix:** If shipping desktop, regenerate via `flutterfire configure` and pick a real Windows appId.
- **Priority:** P2

### 3.3 `unused_local_variable` warning in `manage_products_screen.dart:113`
- **File:** `lib/features/business/screens/manage_products_screen.dart:113`
- **Why bad:** Lint warning. Pre-existing.
- **User impact:** None at runtime.
- **Fix:** Delete the unused `theme` line.
- **Priority:** P2

### 3.4 Mapbox deprecated APIs
- **File:** `lib/features/customer/screens/map_screen.dart:87, 350`
- **Why bad:** `addOnPointAnnotationClickListener` / `OnPointAnnotationClickListener` will be removed; Mapbox flutter SDK 3.x uses `tapEvents`.
- **User impact:** Map will break when the package is bumped past current major.
- **Fix:** Migrate to `tapEvents` API.
- **Priority:** P2

### 3.5 Material Radio deprecated API
- **File:** `lib/features/customer/screens/product_detail_screen.dart:642-643`
- **Why bad:** `groupValue` + `onChanged` on `Radio` deprecated; new API expects `RadioGroup` ancestor.
- **User impact:** Will break on future Flutter.
- **Fix:** Wrap reasons list in `RadioGroup`.
- **Priority:** P2

### 3.6 `recentlyViewedProductsProvider` is not autoDispose
- **File:** `lib/core/providers/providers.dart:57`
- **Why bad:** Holds resolved Product list across navigation forever.
- **User impact:** Slight memory bloat in long sessions.
- **Fix:** Make it `FutureProvider.autoDispose`.
- **Priority:** P2

### 3.7 Sign-in "Continue browsing as guest" leaves auth screen state
- **File:** `lib/features/auth/screens/sign_in_screen.dart:182-185`
- **Why bad:** Plain `context.go('/home')`. Combined with router redirect logic, fine — but no analytics event for the guest funnel.
- **User impact:** Minor product hygiene.
- **Fix:** Add analytics; not critical.
- **Priority:** P3

### 3.8 65 outdated package warnings; Riverpod 2.x in use while 3.x is GA
- **File:** `pubspec.yaml`
- **Why bad:** Long-term tech debt; Riverpod 2 → 3 migration is non-trivial.
- **User impact:** None now; harder upgrade later.
- **Fix:** Plan a Riverpod 3 migration sprint after launch.
- **Priority:** P3

### 3.9 `unnecessary_underscores` info lints (62×)
- **Files:** Various.
- **Why bad:** Style only — lint introduced after this project's code was written.
- **User impact:** None.
- **Fix:** One-shot codemod when convenient.
- **Priority:** P3

---

## 4. UI / UX Flaws

### 4.1 Settings screen uses `theme.colorScheme.primary` while the rest of the app uses `AppColors.teal`
- **File:** `lib/features/customer/screens/settings_screen.dart`
- **Why bad:** Inconsistent with the new Nunito/DM Sans, AppColors-based design. Also still uses dummy `Color(0xFF6366F1)`, `Color(0xFF22C55E)`, `Color(0xFFF59E0B)` icon colours that don't match the brand teal/orange palette.
- **User impact:** Settings screen looks like a different app.
- **Fix:** Rebuild with `AppColors` + GoogleFonts to match `business_settings_screen.dart`.
- **Priority:** P2

### 4.2 `business_settings_screen.dart` and `settings_screen.dart` have divergent layouts for the same job
- **Files:** Both.
- **Why bad:** Business settings uses card-grouped sections; customer settings uses raw `ListTile`s.
- **User impact:** App feels incoherent.
- **Fix:** Unify on the `_SectionCard` pattern from business settings.
- **Priority:** P2

### 4.3 No empty state on `/profile` when guest goes via tab tap (only on /favorites and /notifications)
- **File:** `lib/features/customer/screens/profile_screen.dart` (not deeply inspected — flag for review).
- **Why bad:** Sign-in CTA pattern should be consistent.
- **User impact:** Mild confusion for guests.
- **Fix:** Add `SignInRequired` empty state in the guest branch of profile.
- **Priority:** P2

### 4.4 Onboarding slide 1's lost-shopper map mock is dense at small heights
- **File:** `lib/features/auth/screens/onboarding_screen.dart` (`_MapMockCard`)
- **Why bad:** Hard-coded positioned chips will overlap on phones below ~640dp height.
- **User impact:** Looks busy on small Androids (e.g. older Samsung A series).
- **Fix:** Use `LayoutBuilder` to scale chip positions, or simplify on small screens.
- **Priority:** P2

### 4.5 No skeleton on home recently-viewed
- **File:** `lib/features/customer/screens/home_screen.dart`
- **Why bad:** While `recentlyViewedProductsProvider` resolves N round trips (see 2.3), there's no skeleton row.
- **User impact:** Visible blank space on slow networks.
- **Fix:** Render `ShimmerBox` placeholders during `loading`.
- **Priority:** P3

---

## 5. Security Risks

### 5.1 `ratingAvg` / `ratingCount` writable by any signed-in user — see **1.1**
- **Priority:** P0

### 5.2 No email verification — see **1.4**
- **Priority:** P0

### 5.3 No rate limiting on reviews / reports / favorites
- **Files:** `firebase/firestore.rules` (reviews / reports / favorites blocks)
- **Why bad:** A signed-in user can hammer create endpoints. No App Check, no per-user quotas.
- **User impact:** DoS / spam vector.
- **Fix:** Enable Firebase App Check (Play Integrity / DeviceCheck) and add Firestore rule guards on `request.time` deltas where feasible. Long term: Cloud Functions with rate limiting.
- **Priority:** P1

### 5.4 No App Check enforced
- **File:** `lib/main.dart`
- **Why bad:** Any HTTP client with the public API key can read public collections (intended) and create write requests up to rule limits (also currently abusable per 1.1, 5.3).
- **User impact:** Anyone with the apk can poke the backend.
- **Fix:** Add `firebase_app_check` package, initialise in `main()`, enforce in console.
- **Priority:** P1

### 5.5 `flutter_secure_storage` is in dependencies but not used in repo
- **File:** `pubspec.yaml:44`
- **Why bad:** Suggests a removed feature; dead dep.
- **User impact:** Slightly larger build.
- **Fix:** Remove if truly unused, or wire it for token storage.
- **Priority:** P3

### 5.6 No client-side enforcement of password complexity beyond what `Validators.password` provides
- **File:** `lib/utils/validators.dart` (not opened — verify)
- **Why bad:** If the validator is loose, weak passwords get through.
- **User impact:** Accounts compromised easier.
- **Fix:** Confirm validator enforces ≥8 chars and a mix; otherwise tighten.
- **Priority:** P2

---

## 6. Firebase / Rules Risks

### 6.1 Rating rule abuse — see **1.1**.
### 6.2 Notifications create disabled with no Functions backend — see **1.2**.
### 6.3 Reviews create lacks business-existence check — see **2.6**.
### 6.4 Reports have no rate limit — see **5.3**.
### 6.5 No `firestore.indexes.json` entry for `notifications.read + userId` (mark-all-read query)
- **File:** `firebase/firestore.indexes.json`, `lib/repositories/notification_repository.dart:27-37`
- **Why bad:** `markAllAsRead` does `where('userId').where('read', false)`. This needs a composite index that's not in the file. First production call will throw with a "create index" link.
- **User impact:** "Mark all read" button errors on prod (until manual index creation).
- **Fix:** Add `[userId asc, read asc]` index.
- **Priority:** P1

### 6.6 `categories.isActive + name` index exists but the repo doesn't seem to query it
- **File:** `firebase/firestore.indexes.json:3-10`
- **Why bad:** Dead index — minor cost.
- **User impact:** None.
- **Fix:** Delete if unused.
- **Priority:** P3

### 6.7 Storage path comment vs reality — see **2.8**.

---

## 7. Performance Risks

### 7.1 Unbounded search & list streams — see **1.3**, **3.1**.
### 7.2 Serial recently-viewed resolution — see **2.3**.
### 7.3 Admin dashboard in-build provider creation — see **2.1**.
### 7.4 Map screen streams every business unbounded
- **File:** `lib/features/customer/screens/map_screen.dart:37-40`
- **Why bad:** `streamAll()` again — see 3.1. Map may render hundreds of markers, hammer Mapbox.
- **User impact:** Map laggy with many businesses.
- **Fix:** Bound by viewport bounds query (geohash) or limit + paginate.
- **Priority:** P2

### 7.5 No image dimension cap on upload (Storage rule only checks size)
- **File:** `firebase/storage.rules:23-26`, `lib/features/business/screens/add_edit_product_screen.dart`
- **Why bad:** `imageQuality: 80, maxWidth: 1600` is set in image_picker, but a determined client can bypass and upload anything ≤5 MB.
- **User impact:** Heavy product images bloat the catalog.
- **Fix:** Add a Cloud Function that resizes on upload (`firebase-resize-images` extension).
- **Priority:** P2

### 7.6 Cached image widget without preferred-size hints (verify)
- **File:** `lib/widgets/cached_image.dart` (not deeply read in this audit)
- **Why bad:** If `cacheHeight`/`cacheWidth` aren't set, decoded image stays at full res in memory.
- **User impact:** Memory bloat on grid screens.
- **Fix:** Pass `memCacheHeight: ~targetSize * dpr`.
- **Priority:** P2

---

## 8. Release Readiness Checklist

| Item | Status | Notes |
|---|---|---|
| `flutter analyze` clean (no errors) | OK | 1 warning, 65 info |
| Firestore rules cover all collections | OK | But abuse paths exist (1.1, 2.6, 5.3) |
| Storage rules cover all paths | OK | Default deny in place |
| Email verification | Missing | See 1.4 |
| App Check | Missing | See 5.4 |
| Cloud Functions for notifications & rating aggregation | Missing | See 1.1, 1.2 |
| Composite indexes for all queries | Partial | See 6.5 |
| Mapbox token wiring documented | OK | `--dart-define=MAPBOX_ACCESS_TOKEN=...` |
| Onboarding gating once-per-install | OK | See 2.7 edge |
| Brand consistency (Nunito/DM Sans + AppColors) | Partial | Customer settings drifts (4.1) |
| Tests | Missing | No `test/` directory |
| CI | Missing | No workflow files |
| Privacy Policy / ToS / Listing Agreement / Prohibited Listings | OK | All routes wired (`/legal/...`) |
| Account deletion path | Missing | Privacy Policy promises it; not implemented |
| Crashlytics wired | Unknown | `firebase_messaging` is in deps; Crashlytics is not |
| Outdated packages | 65 | Plan post-launch upgrade |

---

## 9. Recommended Fix Order

1. **P0 — Security correctness (must ship before public release)**
   1. Fix rating-write abuse (1.1) — disable client writes, plan Cloud Function.
   2. Decide notifications (1.2) — either ship a Cloud Function or hide the surface.
   3. Send email verification + gate sign-in (1.4).
   4. Type and invalidate `currentUserBusinessProvider` (1.5).
   5. Bound search + add `keywordsLower` array or Algolia (1.3).

2. **P1 — Stability + correctness**
   1. Lift admin dashboard providers (2.1).
   2. Make favorites toggle deterministic (2.2).
   3. Enable App Check (5.4).
   4. Add notifications composite index (6.5).
   5. Splash timeout race fix (2.4).
   6. Reviews business-existence check (2.6).
   7. Settings dead buttons → coming-soon snackbars (2.5).

3. **P2 — Performance + polish**
   1. Limit + paginate `streamAll` queries (3.1, 7.4).
   2. Migrate Mapbox + Radio deprecated APIs (3.4, 3.5).
   3. Brand-align customer settings screen (4.1, 4.2).
   4. autoDispose recently-viewed; batch reads (3.6, 2.3).
   5. Image resize Cloud Function (7.5).

4. **P3 — Cleanup**
   1. Codemod the 62 underscore lints.
   2. Drop unused dep `flutter_secure_storage` (or wire it).
   3. Remove dead category index (6.6).
   4. Plan Riverpod 3 + outdated-package bump.

---

*End of report.*
