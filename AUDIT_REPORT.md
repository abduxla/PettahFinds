# PetaFinds — Project Audit Report (Refresh)

**Date:** 2026-05-03
**Branch:** main (`?? .firebaserc` only — clean otherwise)
**flutter pub get:** OK (67 packages have newer majors, none breaking the resolve)
**flutter analyze:** 65 info-level issues, 0 warnings, 0 errors
**flutter test:** 1 passed (default `widget_test.dart` placeholder)
**flutter build web --release:** built successfully; **wasm warnings** for `flutter_secure_storage_web` (`dart:html`, `dart:js_util`, `package:js`)

This refresh supersedes the prior audit. Items previously flagged that have since been **fixed in the codebase** are listed under §10 for traceability. Open items follow the original severity layout.

---

## 1. Critical Blockers

### 1.1 `flutter_secure_storage` is in pubspec but unused — blocks future wasm web target
- **File:** `pubspec.yaml:44`, `flutter build web --release` output
- **Why bad:** The package's web shim imports `dart:html`, `dart:js`, `dart:js_util` and `package:js`, none of which compile to wasm. Standard JS web build still works today, but any move to wasm (Flutter's default trajectory) is blocked. No code in `lib/` references the package.
- **User impact:** Locks the project out of wasm release builds with no benefit, since the dependency is dead.
- **Fix:** Remove from `pubspec.yaml`, run `flutter pub get`. If it ever comes back, gate it with a non-web import.
- **Priority:** P0 (release correctness)

### 1.2 No producer ever writes notifications — bell + screen permanently empty
- **File:** `lib/repositories/notification_repository.dart`, `firebase/firestore.rules:200-220`, `lib/features/customer/screens/notifications_screen.dart`
- **Why bad:** Rule was loosened to allow self-create (good), but no client code or Cloud Function ever calls `notification_repository.create(...)` (the method doesn't exist either). Bell, "Mark all read", notifications screen all sit on a stream that never emits non-empty.
- **User impact:** Visible feature ships dead. Looks like an outage to the user.
- **Fix:** Either add a `create()` method + a welcome-notification call at signup *and* a Cloud Function for cross-user (review reply, business update, etc.), or hide the bell + screen until backend is shipped.
- **Priority:** P0 (release readiness)

### 1.3 Email verification not enforced anywhere user-visible
- **File:** `lib/repositories/auth_repository.dart:46-55`, `lib/features/auth/screens/sign_in_screen.dart`
- **Why bad:** Sign-up now sends verification email (good), but nothing in the UI surfaces "verify your email" status, nothing nudges, nothing gates write-heavy actions (review create, report, business setup) on `emailVerified`. Spam accounts can still post reviews and reports.
- **User impact:** Account abuse, fake reviews, fake reports — same risk as before, just with a paper trail.
- **Fix:** Add a soft banner on the customer/business shell when `currentUser.emailVerified == false` with a "Resend" button (helper already exists: `resendEmailVerification()`). Optionally hard-gate review create on the AuthRepository.
- **Priority:** P0 (security + trust)

### 1.4 No App Check enforced
- **File:** `lib/main.dart`, `pubspec.yaml`
- **Why bad:** Anyone can hit Firestore + Storage with the public API keys in `firebase_options.dart`. Combined with §1.3, account abuse cost is near-zero.
- **User impact:** DoS, cost spikes, abuse traffic.
- **Fix:** Add `firebase_app_check` package, init in `main()` with debug provider for dev (`AndroidProvider.debug` / `AppleProvider.debug`) and Play Integrity / DeviceCheck for prod, then enforce in console.
- **Priority:** P0 (security)

---

## 2. High Bugs

### 2.1 WhatsApp number cleaner falls through to a broken link for non-LK formats
- **File:** `lib/utils/whatsapp.dart:24` (`return digits;`)
- **Why bad:** When input doesn't match LK heuristics (already-94, leading-0, bare-9-digit), the function returns whatever digits remain. wa.me requires a country code, so a 10-digit number like `1234567890` becomes `https://wa.me/1234567890` and either dials the wrong country or silently fails.
- **User impact:** Customer taps green "Chat on WhatsApp" → WhatsApp opens to nobody / wrong number / errors. Trust dies.
- **Fix:** Return `null` from `cleanWhatsAppNumber` for un-handled lengths and surface a snackbar. Or accept non-LK only if the input started with `+`.
- **Priority:** P1

### 2.2 WhatsApp number not validated on save
- **Files:** `lib/features/business/screens/business_setup_screen.dart`, `lib/features/business/screens/edit_business_profile_screen.dart`
- **Why bad:** The new TextFormField has no validator. A business owner can type "asdf" and save. Later customers tap the CTA and get the snackbar from §2.1.
- **User impact:** Garbage saved to Firestore; broken CTA at runtime.
- **Fix:** Run input through `cleanWhatsAppNumber`; if non-empty and `cleanWhatsAppNumber == null`, show `Validators.required`-style error.
- **Priority:** P1

### 2.3 Splash 8-second fallback can route logged-in customer to /home before role check
- **File:** `lib/features/auth/screens/splash_screen.dart:48-66, 80-94`
- **Why bad:** The hardened `_safeFallbackRoute` reads `appUserProvider.valueOrNull` first (good). But if Firestore is slow, AppUser may still be null at 8s while Firebase user is loaded. We then route to `/home` and rely on the router redirect. The redirect is correct, but it produces visible flicker for admin/business users on cold start.
- **User impact:** Brief customer-home flash before bouncing to admin/business shell on first launch.
- **Fix:** Either extend the timeout to 15s (Firestore cold reads can be slow), or show an in-place "syncing your account..." loader instead of routing.
- **Priority:** P1

### 2.4 `streamAll` / `streamAllByBusiness` / `streamByBusiness` still unbounded
- **Files:** `lib/repositories/product_repository.dart:54-78`, `lib/repositories/business_repository.dart:54-58`
- **Why bad:** Search was capped (good), but home, products list, business detail "all products" still stream every active product / every business. With the Pettah catalog at hundreds it's fine; at thousands it isn't.
- **User impact:** Linear cost & bandwidth in catalog size; slow cold loads when the directory grows.
- **Fix:** `.limit(100)` server-side + paginate with `startAfter`. Or move home + lists to an "infinite scroll" paginator.
- **Priority:** P1

### 2.5 Storage `contentType` regex is trivially spoofable
- **File:** `firebase/storage.rules:23-26`
- **Why bad:** Rule trusts `request.resource.contentType.matches('image/.*')`. A malicious uploader can set any contentType client-side; the bytes don't have to be an image.
- **User impact:** Storage can be used to host arbitrary blobs labelled as image.
- **Fix:** Combine with Firebase Storage extension that re-reads + validates magic bytes, or use Cloud Functions on upload to verify.
- **Priority:** P1

### 2.6 Recently-viewed / favorites can show deleted-soft products
- **Files:** `lib/core/providers/providers.dart:60-78` (recently viewed handles isActive), `lib/repositories/favorite_repository.dart` (does not)
- **Why bad:** Favorites resolves `productId` to a Product without checking `isActive`. Soft-deleted products still appear under "Favorites".
- **User impact:** Customer taps a favorite → opens detail → sees "This product is no longer available".
- **Fix:** When resolving favorite IDs to Product objects, drop entries where `!p.isActive`. Or hide the row.
- **Priority:** P1

---

## 3. Medium Bugs

### 3.1 `recentlyViewedProductsProvider` can issue up to 30 parallel reads with no cap
- **File:** `lib/core/providers/providers.dart:60-78`
- **Why bad:** Now uses `Future.wait` (good) but the underlying `RecentlyViewedService` doesn't trim history. A power user with 100 product views would fan out 100 simultaneous Firestore gets on home open.
- **User impact:** Cold-load spike on home for heavy users.
- **Fix:** Cap the IDs list to the latest 12 in either the service or the provider before fetching.
- **Priority:** P2

### 3.2 Firestore rule on rating writes still trusts review-author count math
- **File:** `firebase/firestore.rules:104-122`
- **Why bad:** Bounds (1.0–5.0, +1) are correct. But a determined attacker who creates one review can drift the average toward their value by re-submitting their own review to bump count by 1 each time. Cloud Function for rating aggregation is still the right fix.
- **User impact:** Slower abuse, but still possible.
- **Fix:** Cloud Function recomputes ratings on review create/update; lock client writes to admin-only.
- **Priority:** P2

### 3.3 Business search is an O(n) scan on full collection (capped at 200)
- **File:** `lib/repositories/business_repository.dart:78-99`
- **Why bad:** Capped (good) but the cap means the 201st-newest business is unsearchable.
- **User impact:** Older businesses become invisible to search as catalog grows.
- **Fix:** Algolia / Typesense for real text search; mentioned in privacy policy already.
- **Priority:** P2

### 3.4 Map screen streams every business unbounded
- **File:** `lib/features/customer/screens/map_screen.dart:37-40`
- **Why bad:** No limit, no viewport bounds query. Renders every business marker.
- **User impact:** Map sluggish at scale.
- **Fix:** Geohash + bounds-based query, or `.limit(500)`.
- **Priority:** P2

### 3.5 `currentUserBusinessProvider` is `FutureProvider` — no live updates when biz doc changes externally
- **File:** `lib/core/providers/providers.dart:96-105`
- **Why bad:** Now properly typed `Business?` and invalidated after edit/setup (good). But if an admin verifies the business or a Cloud Function changes membership tier, the user's dashboard won't update until app restart or manual invalidate.
- **User impact:** Stale state across devices.
- **Fix:** Convert to `StreamProvider<Business?>` driven by `_ref.doc(businessId).snapshots()`.
- **Priority:** P2

### 3.6 Settings "Coming soon" snackbars accumulate stack
- **File:** `lib/features/customer/screens/settings_screen.dart:32-44`
- **Why bad:** Tapping multiple times stacks snackbars instead of replacing.
- **User impact:** Visual stutter; minor.
- **Fix:** `ScaffoldMessenger.of(context).clearSnackBars()` before showing.
- **Priority:** P2

### 3.7 Mapbox deprecated APIs still in use
- **File:** `lib/features/customer/screens/map_screen.dart:87, 350`
- **Why bad:** `addOnPointAnnotationClickListener` / `OnPointAnnotationClickListener` deprecated in mapbox_maps_flutter 2.x.
- **User impact:** Will break when the package bumps.
- **Fix:** Migrate to `tapEvents`.
- **Priority:** P2

### 3.8 Material Radio deprecated API
- **File:** `lib/features/customer/screens/product_detail_screen.dart` (report sheet `RadioListTile` `groupValue` / `onChanged`)
- **Why bad:** Deprecated; future Flutter will need `RadioGroup`.
- **User impact:** Compile break on future SDK bump.
- **Fix:** Wrap reasons list in `RadioGroup`.
- **Priority:** P2

---

## 4. UI Bugs

### 4.1 Customer settings screen still drifts from the rest of the app's brand
- **File:** `lib/features/customer/screens/settings_screen.dart`
- **Why bad:** Uses `theme.colorScheme.primary` and dummy hex colors (`0xFF6366F1`, `0xFF22C55E`, `0xFFF59E0B`) instead of `AppColors.teal/orange`. The rest of the app, including the new business settings, uses `AppColors` + GoogleFonts.
- **User impact:** Settings page looks like a different app.
- **Fix:** Rebuild against `AppColors` + Nunito/DM Sans matching `business_settings_screen.dart` `_SectionCard` pattern.
- **Priority:** P2

### 4.2 Product detail seller card structure changed in WhatsApp work — verify visual
- **File:** `lib/features/customer/screens/product_detail_screen.dart:382-540` (`_SellerCard`)
- **Why bad:** The original `InkWell` wrapping the whole card was replaced with a `Container > Column > InkWell(InkWell only over the row part)`. The chevron icon still points right but the whole card no longer ripples. Needs a visual sanity check on real device — formatter passed, but the brace nesting was hand-edited.
- **User impact:** Possible reduced tap target / off-center ink response.
- **Fix:** Use `Column` and wrap each tappable child in its own `InkWell`. Verify on device.
- **Priority:** P2

### 4.3 Onboarding slide-1 map mock chips can overlap on small Androids
- **File:** `lib/features/auth/screens/onboarding_screen.dart`
- **Why bad:** Hard-coded `Positioned` chips. Below ~640dp height some chips overlap.
- **User impact:** Looks busy / broken on older Samsung A series.
- **Fix:** `LayoutBuilder` to scale, or simplify on small screens.
- **Priority:** P2

### 4.4 Profile screen has no guest sign-in CTA equivalent to favorites/notifications
- **File:** `lib/features/customer/screens/profile_screen.dart`
- **Why bad:** Inconsistent with the rest of the guest-allowed shell.
- **User impact:** Mild confusion for guests.
- **Fix:** Add `SignInRequired` for the guest branch.
- **Priority:** P3

### 4.5 Home recently-viewed has no skeleton during load
- **File:** `lib/features/customer/screens/home_screen.dart`
- **Why bad:** Visible blank gap during the parallel fetch.
- **User impact:** Empty space on slow networks.
- **Fix:** `ShimmerBox` placeholders during loading.
- **Priority:** P3

---

## 5. Security Risks

### 5.1 No App Check — see §1.4.
### 5.2 Email verification not user-visible / not gating writes — see §1.3.
### 5.3 Storage contentType spoofable — see §2.5.
### 5.4 Rating-write abuse partially mitigated, not eliminated — see §3.2.

### 5.5 No rate limiting on review / report / favorite create
- **File:** `firebase/firestore.rules`
- **Why bad:** App Check would mostly fix this; without it, a signed-in user can still hammer create endpoints up to per-second Firestore quotas.
- **User impact:** Spam, cost spikes.
- **Fix:** App Check (P0) + per-user rate limit via Cloud Functions if needed.
- **Priority:** P1

### 5.6 `pubspec.yaml` includes unused `flutter_secure_storage`
- **File:** `pubspec.yaml:44`
- **Why bad:** Unused crypto/secret-store dependency. Larger attack surface for what's bundled.
- **User impact:** Bigger bundle, blocked wasm path (§1.1).
- **Fix:** Remove.
- **Priority:** P1

---

## 6. Firebase / Rules Risks

### 6.1 Notifications create allows self-mint with no body validation
- **File:** `firebase/firestore.rules:200-220`
- **Why bad:** The new `request.resource.data.userId == request.auth.uid` rule lets a user write any shape of notification doc into their own inbox (e.g., gigantic strings, fields the model doesn't expect). Doesn't break anyone else's inbox but pollutes the collection.
- **User impact:** No external impact, but Cloud Function consumers need to defensive-parse.
- **Fix:** Tighten to specific allowed fields and length caps.
- **Priority:** P2

### 6.2 Reviews business-existence check is good but expensive
- **File:** `firebase/firestore.rules:158-167`
- **Why bad:** Each review create now does a Firestore `exists()` lookup at rule-eval time. That's billed.
- **User impact:** Slightly more cost per review.
- **Fix:** Acceptable — leave as is; cost is bounded by per-user write rate.
- **Priority:** P3

### 6.3 Storage rules path comment now matches reality (fixed)
- See §10.

### 6.4 No security event logging
- **File:** N/A
- **Why bad:** Failed signs-ins, suspicious activity, denied writes — none observable.
- **User impact:** Hard to tell during an attack.
- **Fix:** Cloud Functions on `auth.user().onSignIn` etc., write to a `securityEvents/` log.
- **Priority:** P2

### 6.5 Unused `categories.isActive + name` index
- **File:** `firebase/firestore.indexes.json:3-10`
- **Why bad:** Dead index, minor cost.
- **Fix:** Remove if no query uses it.
- **Priority:** P3

---

## 7. Performance Risks

### 7.1 Unbounded list streams — see §2.4, §3.4.
### 7.2 No pagination on home — same.

### 7.3 Cached image not given size hints
- **File:** `lib/widgets/cached_image.dart` (verify)
- **Why bad:** Without `cacheHeight` / `cacheWidth` / `memCacheHeight`, decoded bitmaps stay full-resolution in memory.
- **User impact:** Memory bloat on grid screens.
- **Fix:** Pass `memCacheHeight: ~targetSize * dpr`.
- **Priority:** P2

### 7.4 Image upload size cap (5 MB) but no dimension cap
- **File:** `firebase/storage.rules:23-26`, `lib/features/business/screens/add_edit_product_screen.dart:99-101`
- **Why bad:** Picker uses `imageQuality:80, maxWidth:1600` (good) but is bypassable. Storage allows up to 5 MB of any shape image.
- **User impact:** Heavy images slow grids and waste CDN bandwidth.
- **Fix:** Cloud Function or `firebase-resize-images` extension to resize on upload.
- **Priority:** P2

### 7.5 Recently-viewed history not capped
- See §3.1.

---

## 8. Release Checklist

| Item | Status | Notes |
|---|---|---|
| `flutter analyze` clean (no errors/warnings) | OK | 65 info-level only |
| `flutter test` passes | OK | 1 placeholder test |
| `flutter build web --release` succeeds | OK | wasm dry-run warns (§1.1) |
| Email verification visible to user | Missing | §1.3 |
| App Check | Missing | §1.4 |
| Notifications producer (welcome msg / Cloud Functions) | Missing | §1.2 |
| Cloud Functions for rating aggregation | Missing | §3.2 |
| WhatsApp number validation | Missing | §2.1, §2.2 |
| Composite indexes for known queries | OK | Added `[userId, read]` last sprint |
| Firestore rules locked on business profile fields | OK | `whatsappNumber` whitelisted §10 |
| Storage rules path comment matches code | OK | Fixed §10 |
| Brand consistency (Nunito/DM Sans + AppColors) | Partial | Customer settings drifts (§4.1) |
| Account deletion path (privacy promise) | Missing | Privacy Policy promises this; not implemented |
| Crashlytics wired | Unknown | `firebase_messaging` present; Crashlytics not |
| CI workflow | Missing | None in repo |
| Tests beyond placeholder | Missing | Only `widget_test.dart` placeholder |
| `flutter_secure_storage` removed | Pending | §1.1, §5.6 |
| Outdated packages | 67 | Plan post-launch upgrade |

---

## 9. Recommended Fix Order

1. **P0 — must ship before public launch**
   1. Drop unused `flutter_secure_storage` (§1.1, §5.6).
   2. Decide notifications direction — implement welcome-notif self-mint at signup *or* hide bell + screen until backend exists (§1.2).
   3. Add an "Unverified email" banner + soft gate on review/report create (§1.3).
   4. Wire Firebase App Check (§1.4).

2. **P1 — security + correctness**
   1. WhatsApp validator on save + `null` return for unknown formats (§2.1, §2.2).
   2. Splash timeout: extend or replace with in-place loader (§2.3).
   3. Pagination / `.limit(100)` on home & list streams (§2.4).
   4. Image content validation Cloud Function or extension (§2.5).
   5. Drop soft-deleted favorites (§2.6).
   6. App Check rate-limits → §1.4.

3. **P2 — performance + polish**
   1. Cap recently-viewed history (§3.1).
   2. Cloud Function for rating aggregation (§3.2).
   3. Algolia/Typesense for search (§3.3).
   4. Map viewport-bounds query (§3.4).
   5. Convert `currentUserBusinessProvider` to `StreamProvider` (§3.5).
   6. Mapbox + Radio deprecated API migration (§3.7, §3.8).
   7. Brand-align customer settings (§4.1).
   8. CachedImage memCacheHeight (§7.3).
   9. Storage upload resize Cloud Function (§7.4).

4. **P3 — cleanup**
   1. Profile guest CTA (§4.4).
   2. Recently-viewed skeleton (§4.5).
   3. Tighten notif rule schema (§6.1).
   4. Drop dead category index (§6.5).
   5. Codemod the 65 info lints.
   6. Plan Riverpod 3 + outdated bump.

---

## 10. Verified-Fixed Since Prior Audit (informational)

These were P0/P1 in the prior report and are confirmed fixed in the current code:

- ✅ **Rating writes** bounded to [1.0, 5.0] and `+1` count delta — `firestore.rules:104-122`.
- ✅ **Notifications create** allows self (admin still allowed) — `firestore.rules:200-220`. (See §1.2 — rule is unblocked but still no producer.)
- ✅ **Search** capped at 200 newest — `product_repository.dart:89-105`, `business_repository.dart:78-99`.
- ✅ **Email verification email sent on signup** + helper `resendEmailVerification()` — `auth_repository.dart:42-60`. (See §1.3 — still not surfaced in UI.)
- ✅ **`currentUserBusinessProvider` typed `Business?`** + invalidated after setup/edit — `providers.dart`, callers cleaned.
- ✅ **Admin dashboard providers lifted** to top-level — `providers.dart`, `admin_dashboard_screen.dart`.
- ✅ **Favorite toggle deterministic + transactional** — `favorite_repository.dart`.
- ✅ **Recently-viewed parallelized** — `providers.dart` (`Future.wait`).
- ✅ **Splash 8s timeout reads auth state first** — `splash_screen.dart` (`_safeFallbackRoute`). (Edge in §2.3 remains.)
- ✅ **Settings dead buttons** → "Coming soon" snackbars — `settings_screen.dart`.
- ✅ **Reviews business-existence check** — `firestore.rules:158-167`.
- ✅ **Onboarding flag cached in initState** — `splash_screen.dart`.
- ✅ **Storage rules path comment** updated to match upload code — `storage.rules`.
- ✅ **Notifications composite index** `[userId, read]` — `firestore.indexes.json`.
- ✅ **WhatsApp** model field, helper, setup form, edit form, product detail CTA, business detail row — Business model + 5 screens + new util.

---

*End of report.*
