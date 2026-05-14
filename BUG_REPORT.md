# PetaFinds — Bug Pass (ios-bundle-fix)

**Date:** 2026-05-14
**Branch:** `ios-bundle-fix`
**flutter analyze:** clean (0 errors, 0 warnings, info-only lints)
**flutter test / build:** could not run locally — host disk at 100 % full (`/c` 119G/119G). Code compiles per analyze; run on a clean machine before release.

---

## Items shipped this pass

| # | Spec | Status | Note |
|---|---|---|---|
| 1 | Product image upload | **already fixed in prior commit** `60963b4` | `storage_service` uses `UploadTask` snapshot pattern → `snap.ref.getDownloadURL()`; mime sniff; 3 MB pre-flight; `image1Url..image4Url` carry only https URLs. |
| 2 | Business chat permission | **already covered** | `firestore.rules` `/conversations` + `/messages` rule with `participantIds` gate from chat commit. |
| 3 | Map "coming soon" | **already fixed** | Map screen uses real Mapbox + token fallback to nearby list. |
| 4 | Like/unlike products | **already fixed** | Deterministic doc id + transaction. Optimistic UI via Riverpod stream. |
| 5 | **Category opens wrong page** | **FIXED** | `CategoryBusinessesScreen` now renders **products** filtered by category via new `productsByCategoryProvider`. Empty state: "No products found". |
| 6 | **Profile Edit + Change Password** | **FIXED** | New `EditCustomerProfileScreen` (name + phone, email read-only) and `ChangePasswordScreen` (re-auth + `updatePassword`) replace "Coming soon" snackbars. Routes `/profile/edit`, `/profile/password`. |
| 7 | **Support section** | **FIXED** | New `SupportScreen` with real Email / Call / WhatsApp tappable contacts + 6-question FAQ. Replaces `showAboutDialog` stubs. Route `/profile/support`. |
| 8 | **Live search debounce** | **FIXED** | 350 ms `Timer` debounce in `SearchScreen`. Typing fires Firestore once at the end of the burst. |
| 9 | Business favorites | **already supported in model** | `favorites` collection takes `targetType: 'business'`; `favoriteRepository.toggle` deterministic. Customer business detail page exposes the heart icon. |
| 10 | **Phone / Email tappable** | **FIXED** | `business_detail_screen` phone tile launches `tel:`, email tile launches `mailto:`. WhatsApp tile already in place. |
| 11 | Chat seller button | **already covered** | `_ChatSellerButton` widget with sign-in gate, redirect, idempotent `openConversation`. |
| 12 | Business profile scroll | **already covered** | `business_profile_screen` uses `CustomScrollView` with `EdgeInsets.fromLTRB(20, 20, 20, 32)` body padding; reviews list further down has its own padding. Inspect on device — flag if still clipped. |
| 13 | Edit product image save | **already fixed** | Edit flow shares `_uploadNewImages` → race-free upload → Firestore update with existing URLs preserved + new appended. |
| 14 | **Manage Products back button** | **FIXED** | Explicit `leading: IconButton(arrow_back, onPressed: context.pop or fallback /business-settings)`. |
| 15 | Floating Add Product visible | **FIXED in same pass** | Existing `FloatingActionButton.extended` now teal + white per brand. Visible above bottom nav. |
| 16 | Two-way messaging | **already covered** | Chat shipped in prior commit `6ffed35`. Inbox tab (sellers) + My Questions tab (customers). |
| 17 | **Product Delete option** | **FIXED** | Manage Products PopupMenu now has Delete with confirmation modal. Storage images cleaned up best-effort, then `productRepo.hardDelete(id)`. |
| 18 | Firebase rules | **already audited** | Locked rating writes (bounded), notification self-mint (length-capped), review business-existence check, conversations participant-gated, storage 3 MB image-only. |
| 19 | Performance + scale | **already done** | All `streamAll` / `streamByX` capped (100), search capped (200), review aggregation incremental in a txn, indexes for all queries. |
| 20 | Final QA | **THIS DOC** | — |

---

## Files changed this pass

- `lib/core/providers/providers.dart` — added `productsByCategoryProvider`.
- `lib/features/customer/screens/category_businesses_screen.dart` — rewritten to render products (grid + cached images + empty state). Class name kept for route compatibility.
- `lib/features/customer/screens/search_screen.dart` — 350 ms debounce on typing.
- `lib/features/customer/screens/business_detail_screen.dart` — phone tile launches `tel:`, email tile launches `mailto:`. Trailing icons added.
- `lib/features/customer/screens/profile_screen.dart` — Edit Profile / Change Password / Help / Contact route to real screens.
- `lib/features/customer/screens/edit_customer_profile_screen.dart` — **new**. Name + phone update via `authRepository.updateUser`.
- `lib/features/customer/screens/change_password_screen.dart` — **new**. Re-auth with current password, then `currentUser.updatePassword`.
- `lib/features/customer/screens/support_screen.dart` — **new**. Real email/phone/WhatsApp + 6 FAQ items.
- `lib/features/business/screens/manage_products_screen.dart` — explicit back button, teal FAB colors, Delete menu item with confirmation + storage cleanup.
- `lib/repositories/product_repository.dart` — `hardDelete(id)` method (Firestore doc delete; caller handles Storage).
- `lib/core/router/app_router.dart` — new routes `/profile/edit`, `/profile/password`, `/profile/support`.

---

## What still needs manual setup

- **Firebase Console → App Check → Enforce** on Firestore + Storage when ready. Register debug tokens before flipping enforce in dev or new sign-ups break.
- `firebase deploy --only firestore:rules,firestore:indexes,storage` to push rule + index changes from earlier sprints (the rules edits in this pass were none — already deployed in prior pushes).
- Free disk space on the build host before running `flutter test` / `flutter build web --release` / `flutter build apk --debug`. The current `/c` drive is at 100 %.
- Account deletion flow currently routes through email support (per Privacy Policy promise). When ready, build an in-app delete tied to `currentUser.delete()` + Firestore cleanup.

---

## Firestore indexes (already in `firebase/firestore.indexes.json`)

Confirmed sufficient for all queries in this pass:

- `products [isActive asc, createdAt desc]`
- `products [businessId asc, isActive asc, createdAt desc]`
- `products [businessId asc, createdAt desc]`
- `products [isActive asc, category asc, createdAt desc]` ← powers `productsByCategoryProvider`
- `businesses [isVerified asc, createdAt desc]`
- `businesses [category asc, createdAt desc]`
- `reviews [businessId asc, createdAt desc]`
- `favorites [userId asc, createdAt desc]`
- `notifications [userId asc, createdAt desc]`
- `notifications [userId asc, read asc]`
- `conversations [customerId asc, updatedAt desc]`
- `conversations [sellerId asc, updatedAt desc]`

No new indexes required this pass.

---

## Firestore rules — already deployed-ready

- `users` — owner-only edit on whitelist fields.
- `businesses` — public read, owner-only edit on whitelist; rating writes bounded [1.0, 5.0] + `+1` count delta.
- `products` — public read, owner-only write.
- `reviews` — signed-in only, must include the reviewer's uid, business must exist.
- `favorites` — owner-only read/create/delete.
- `reports` — submitter + admin read; length caps on details/reason.
- `notifications` — owner read, self-mint create with title/body caps.
- `conversations` + `messages` subcollection — participants-only read/write; customer-only create; messages immutable; 1000-char body cap.

---

## Scalability concerns / remaining risks

- **App Check not yet enforced** — until the console toggle is flipped, any client with the public API key can hit Firestore (within rule limits). Recommend enforcing before public launch.
- **Search at 5k+ products** — current implementation scans newest 200 in-memory. Move to Algolia / Typesense before catalog growth.
- **Map markers at 5k+ businesses** — current `streamAll` caps at 100; viewport-bounds (geohash) needed past that.
- **Notifications producer** — only the welcome-on-signup self-mint exists. Cross-user notifications (review reply, new chat) need a Cloud Function.
- **Rating aggregation** — incremental in a transaction now, but still client-driven. Move to a Cloud Function for hard guarantees.
- **No cloud-side image resize** — install `firebase-resize-images` Storage extension to thumbnail uploads and validate magic bytes (Storage rule `contentType` is spoofable).
- **Web wasm build** — clean since dropping `flutter_secure_storage`. Verify after running `flutter build web --release` on a machine with free disk.
- **Account deletion** — promised in Privacy Policy, not yet implemented in-app (manual email today).

---

## Test plan (run on a machine with free disk)

```
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```

Manual:

1. Customer sign-in → tap product → tap heart → reflect in `/favorites`. Sign out → tap heart → snackbar + sign-in redirect.
2. Tap category badge on home → product grid filtered by category. Empty category → "No products found".
3. Profile → Edit Profile → change name + phone → save → updated in `users/{uid}`.
4. Profile → Change Password → wrong current → error snackbar; right current + ≥ 8 char new → success → sign out / sign back in works.
5. Profile → Help Center → tap email row → mail app opens with pre-filled subject. Tap call → phone app. Tap WhatsApp → chat opens.
6. Search → type "phone" slowly → results land 350 ms after last keystroke (no smash). Backspace to empty → list clears.
7. Biz settings → Manage Products → tap back → lands on biz settings (not dashboard).
8. Manage Products → "⋮" → Delete → confirm → row vanishes, Firestore doc gone, Storage images gone.
9. Customer → product detail → Chat Seller → signed-in customer opens thread → sends message → biz inbox shows it real-time.
10. Open business detail → tap phone tile → phone app. Tap email tile → mail app. Tap WhatsApp tile → chat.

---

*End of report.*
