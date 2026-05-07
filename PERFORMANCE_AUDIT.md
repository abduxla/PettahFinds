# PetaFinds — Scale & Performance Audit

**Target:** ~500,000 users on the existing UI, no visual changes.
**Date:** 2026-05-03
**Last `flutter analyze`:** clean (0 errors, 0 warnings, info-only lints).

This document is the architecture-level companion to `AUDIT_REPORT.md`. It focuses on cost, latency, and scaling — not feature gaps.

---

## 1. Hotspots fixed in this pass

| Hotspot | Before | After | File |
|---|---|---|---|
| Review aggregation scanned every review per business on every submit (O(n) per write — multi-MB read for popular sellers) | `_updateBusinessRating` reads ALL reviews and recomputes mean | Incremental aggregation in a transaction; reads only the business doc | `lib/repositories/review_repository.dart` |
| Favorites stream unbounded per user | No `limit()` | `.limit(200)` on newest | `lib/repositories/favorite_repository.dart` |
| Notifications stream unbounded per user | No `limit()` | `.limit(100)` on newest | `lib/repositories/notification_repository.dart` |
| Reviews stream unbounded per business | No `limit()` | `.limit(100)` on newest | `lib/repositories/review_repository.dart` |
| `cached_network_image` decoded at full Storage resolution (1600×?) regardless of on-screen size | No mem-cache hint | `memCacheHeight` / `memCacheWidth` derived from layout size × DPR; cuts grid memory by ~5–20× | `lib/widgets/cached_image.dart` |
| Image upload could send up to 5 MB on flaky mobile data | Storage rule capped at 5 MB only after upload | Pre-flight 3 MB check client-side + Storage rule lowered to 3 MB | `lib/features/business/screens/add_edit_product_screen.dart`, `firebase/storage.rules` |
| Free-text fields had no length cap | `comment`, `details`, `reason`, notification `title`/`body` could be any size | Length caps in rules (200–2000 chars) | `firebase/firestore.rules` |

(Already capped in earlier sprints: `streamAll`, `streamByBusiness`, `streamAllByBusiness`, `streamByCategory` for products and businesses; both repos' `search` to 200 newest.)

---

## 2. Current query inventory and cost shape

| Query | Where used | Reads/op | Scaling shape |
|---|---|---|---|
| `productRepo.streamAll()` (`isActive == true ORDER BY createdAt DESC LIMIT 100`) | Home, products list | 100 docs once, then live diffs | Constant. ✅ |
| `productRepo.streamByCategory(c)` | Category list | ≤ 100 | Constant. ✅ |
| `productRepo.streamByBusiness(id)` | Biz detail products | ≤ 100 | Constant per biz. ✅ |
| `productRepo.streamAllByBusiness(id)` | Manage Products | ≤ 100 | Constant per biz. ✅ |
| `productRepo.search(q)` | Search screen | ≤ 200 (then in-memory filter) | Substring filter is the floor; swap to Algolia/Typesense at >5k products. |
| `businessRepo.streamAll()` | Map screen, admin | ≤ 100 | Constant. ✅ Map should later use viewport bounds. |
| `businessRepo.streamByCategory(c)` | Category screen | ≤ 100 | Constant. ✅ |
| `favoriteRepo.streamByUser(uid)` | Favorites tab | ≤ 200 | Constant per user. ✅ |
| `favoriteRepo.toggle(...)` | Heart taps | 1 read + 1 write inside a txn (deterministic doc id) | Constant. ✅ |
| `notificationRepo.streamByUser(uid)` | Bell, notifications screen | ≤ 100 | Constant. ✅ |
| `notificationRepo.markAllAsRead(uid)` | "Mark all read" | 1 query (≤ N docs) + 1 batch | N is bounded by unread count; covered by `[userId, read]` index. ✅ |
| `reviewRepo.streamByBusiness(id)` | Biz detail reviews | ≤ 100 | Constant per biz. ✅ |
| `reviewRepo.add(review)` | Submit review | 1 write + 1 transaction (1 read, 1 write) on biz doc | **Constant** (was O(n) before this pass). ✅ |
| `recentlyViewedProductsProvider` | Home strip | ≤ 10 parallel reads | Constant per user. ✅ |
| `appUserProvider` | Everywhere | 1 doc stream | Constant per session. ✅ |
| `currentUserBusinessProvider` | Business shell | 1 doc read on first hit, cached until invalidated | Constant per session. ✅ — should become a `StreamProvider` post-launch for cross-device updates. |

---

## 3. Caching layer

- Riverpod **autoDispose.family** for per-id streams keeps subscriptions alive only while a screen mounts; revisits re-use the same instance via the family key. Already in place.
- Top-level (non-autoDispose) for **app-wide** providers: `allActiveProductsProvider`, `allBusinessesProvider`, `allReportsProvider`, `appUserProvider`, `authStateProvider`, `currentUserBusinessProvider`. Single subscription per app lifecycle.
- `cached_network_image` now decodes at on-screen size; the disk cache is the package default (≈100 MB, 7-day TTL) which is fine.
- `recently_viewed_service` capped at 10 IDs locally.

---

## 4. Async / loading

- All Firestore writes that could hang are wrapped in `.timeout()` (15s for biz lookup, 20s for create/update, 45s for image upload).
- `_AddEditProductScreen` clears `_saving` on the success path before `pop()` so the spinner cannot get stuck.
- Splash now waits 15s (was 8s) before falling back, then routes by current auth state.
- Search submits on Enter only — no live keystroke storm to debounce.
- Favorites toggle is transactional + deterministic doc id; double-taps are idempotent within a single txn.

---

## 5. Security posture

| Surface | Today | Note |
|---|---|---|
| App Check | Wired in `main.dart` (debug provider in `kDebugMode`, Play Integrity / DeviceCheck in release) | Console must `Enforce` for it to bite. |
| Firestore rules | Self-stamping enforced (uid match), business-owner whitelist, rating bounds, length caps | Rate limiting still relies on App Check. |
| Storage rules | Image-only, ≤ 3 MB, scoped by ownerUid | `contentType` is spoofable; resize Cloud Function is the strict fix. |
| Email verification | Sent on signup; non-blocking banner on home + biz dashboard | Hard gate is a follow-up. |
| Secrets in repo | Mapbox token via `--dart-define`; `.env*` git-ignored; `.env.example` documents the contract | `firebase_options.dart` keys are public Firebase client keys, not secrets. |
| Public client keys | In repo (intended) | Treat them as public; access control lives in rules + App Check. |

---

## 6. Remaining bottlenecks at 500k users

1. **Unbounded older history** — `streamByUser` for favorites/notifications etc. caps at 100/200 newest. Heavy users won't see older items without a "show more" pager. Add `startAfter` pagination when product calls for it; cost is otherwise fine.
2. **Search** still scans the newest 200 in memory. At 5–10k products the older 5% becomes invisible to search. Move to Algolia / Typesense once the catalog crosses ~5k products. Privacy Policy already mentions Algolia.
3. **Map** streams every business (capped at 100). With 500+ active sellers this is OK; for 5k+ sellers add geohash + viewport-bounds query.
4. **Rating aggregation** is now O(1) per write. The remaining attack vector — a malicious user submitting their own review repeatedly to drift the average — is bounded by the rule (ratingCount ≤ old + 1). Cloud Function recompute is the next-level lock.
5. **Notifications producer** mints a single welcome message at signup. Anything richer (review reply, business update) needs a Cloud Function. Rules already permit self-mint, so the cost story is fine — it's a feature, not a perf, gap.
6. **Storage contentType** is client-supplied. `firebase-resize-images` Storage extension covers both content validation and thumbnailing; install when convenient.

---

## 7. Concrete next steps for 500k+ users (in cost order)

1. **Install `firebase-resize-images` Storage extension** — solves the contentType/magic-byte gap and gives free thumbnails. ~10 minutes in console.
2. **Cloud Function for rating aggregation** — onCreate of a review re-derives `ratingAvg` / `ratingCount` from a Firestore counter shard. Eliminates the rating-write rule's "any signed-in user can write" branch entirely.
3. **Cloud Function for cross-user notifications** — onCreate review, onCreate report, etc. mint inbox entries. Tighten the rule to admin-only once Functions ship.
4. **Algolia / Typesense for search** — replace `repo.search(...)` with a single `algolia.query(...)` call returning ranked, paginated, faceted results.
5. **Pagination on home + manage products** — `startAfter(lastDoc)` once the directory crosses ~100 items.
6. **Map viewport-bounds query** — geohash-based; only fetch markers visible in the current camera bounds.
7. **`StreamProvider<Business?>` for `currentUserBusinessProvider`** — picks up admin verification / membership tier flips without an app restart.

---

## 8. Maintenance signals

- The weekly GitHub Action (`.github/workflows/weekly-maintenance.yml`) runs `flutter analyze`, `flutter test`, `flutter build web`, Firebase config presence, and a secret scan every Monday and on demand. Failures open a single de-duped issue.
- The local script (`scripts/maintenance_check.ps1`) writes `MAINTENANCE_REPORT.md` for the same checks.
- The VS Code task **PetaFinds: Maintenance Check** runs the local script in a pinned terminal.

---

*End of audit.*
