# PetaFinds — Architecture

## Overview

PetaFinds uses a **feature-first** architecture with clear separation of concerns:

```
Screens (UI) → Providers (state) → Repositories (data) → Firebase (backend)
```

## Layers

### 1. Models (`lib/models/`)
Plain Dart classes with `fromFirestore()` / `toMap()` serialization. No code generation — kept simple for a solo-engineer workflow.

### 2. Repositories (`lib/repositories/`)
One repository per Firestore collection. Each encapsulates:
- CRUD operations
- Stream-based real-time queries
- Search (client-side filtering; upgrade to Algolia/Typesense for production scale)

### 3. Providers (`lib/core/providers/`)
Riverpod providers wire repositories to the UI:
- `authStateProvider` — Firebase Auth stream
- `appUserProvider` — Firestore user document stream
- `currentUserBusinessProvider` — Business for logged-in business owner
- Feature-specific providers defined inline near their screens

### 4. Router (`lib/core/router/`)
`go_router` with `StatefulShellRoute.indexedStack` for tab persistence.
Role-based redirect logic in the global `redirect` callback.

### 5. Features (`lib/features/`)
Each feature group (auth, customer, business, admin) has its own `screens/` directory.

### 6. Widgets (`lib/widgets/`)
Reusable components: `LoadingWidget`, `EmptyStateWidget`, `AppErrorWidget`, `CachedImage`.

## Authentication & Authorization Flow

```
App Launch
  → SplashScreen (2s delay, check auth state)
  → If not logged in → OnboardingScreen → SignIn/SignUp
  → If logged in → Check role
    → admin → /admin
    → business (no businessId) → /business/setup
    → business (has businessId) → /business
    → user → /home
```

Authorization enforced at two levels:
1. **Client-side**: Router redirects prevent unauthorized navigation
2. **Server-side**: Firestore Security Rules enforce read/write permissions per role

## Firestore Data Model

### Collections

| Collection | Key Fields | Access |
|-----------|-----------|--------|
| users | uid, email, role, businessId | Owner + Admin |
| businesses | ownerUid, category, isVerified | Public read, owner + admin write |
| categories | name, iconName, isActive | Public read, admin write |
| products | businessId, priceLkr, isActive | Public read, business owner write |
| offers | businessId, productId, dateKey | Public read, business owner write |
| reviews | businessId, userId, rating | Public read, user create |
| favorites | userId, targetType, targetId | Owner only |
| reports | userId, reason, status | Creator + admin |
| notifications | userId, title, read | Owner read, admin create |

## Payments Architecture

### Digital Goods (Memberships, Premium Features)
Per App Store and Play Store policy, digital goods consumed in-app **must** use:
- **iOS**: StoreKit / Apple IAP
- **Android**: Google Play Billing

Implementation approach:
1. Define products in App Store Connect / Google Play Console
2. Use `in_app_purchase` Flutter package
3. Verify receipts server-side via Cloud Functions
4. Update `membershipTier` in Firestore after verification

### Physical Goods / Services
For any future marketplace features involving physical goods:
- Stripe or similar external processor can be used
- Payment processing happens server-side (Cloud Functions)
- Mobile app sends payment intent, server confirms

### Key Principle
Never process payments client-side. Always verify server-side.

## Search Strategy

Current: Client-side filtering via Firestore queries + in-memory keyword matching.

For production scale:
- Integrate Algolia, Typesense, or Meilisearch
- Use Cloud Functions to sync Firestore → search index
- Query search service from client

## Notifications

Firebase Cloud Messaging is scaffolded:
- `firebase_messaging` package included
- `notifications` Firestore collection for in-app notifications
- FCM token registration and push handling should be added in a Cloud Function

## App Check

Not enabled by default. For production:
1. Register app in Firebase Console → App Check
2. Use Play Integrity (Android) and App Attest (iOS)
3. Enforce App Check on Firestore, Storage, and Auth
