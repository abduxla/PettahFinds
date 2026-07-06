# PetaFinds

A Flutter marketplace that brings the shops of Pettah (Colombo 11) online —
customers browse verified businesses and products, chat with sellers, leave
reviews, and save listings; merchants manage a storefront and see engagement
analytics.

The backend is Firebase: Firestore + Storage (locked down by security rules),
Cloud Functions (push, transactional email, backend-owned rating aggregation,
engagement analytics, deletion cascades, upload validation), Auth, and FCM.

> **Live app.** PetaFinds is published on the App Store. Treat every backend
> change as affecting production users and follow the deploy/rollback order
> below.

---

## Repository layout

| Path | What it is |
|------|------------|
| `lib/` | Flutter app source |
| `functions/` | **The** Cloud Functions codebase (Node 22, `codebase: default`) — all triggers, the `recordEngagement` callable, and the transactional emails |
| `firebase/firestore.rules` | Firestore security rules |
| `firebase/storage.rules` | Storage security rules |
| `firebase/firestore.indexes.json` | Firestore composite indexes |
| `scripts/backfillRatings.ts` | One-time rating reconciliation migration (manual) |
| `functions/test/` | Security-critical rules + function tests |

There is a **single** Functions codebase. (An earlier duplicate `emails`
codebase that re-sent the same registration/approval emails has been removed —
the surviving implementation in `functions/index.js` resolves the recipient
from Firebase Auth rather than a client-writable document field.)

---

## Required Firebase services

Enable these in the Firebase Console for the target project
(`pettahfinds-75075`):

1. **Authentication** — Email/Password and Google sign-in.
2. **Cloud Firestore** — production mode; rules are deployed from this repo.
3. **Cloud Storage** — rules are deployed from this repo.
4. **Cloud Functions** — Node 22 runtime (2nd gen).
5. **Cloud Messaging (FCM)** — push notifications.
6. **App Check** — Play Integrity (Android) + DeviceCheck/App Attest (Apple).
7. **Secret Manager** — backs Cloud Functions secrets (below).

---

## Required Secret Manager secrets

Cloud Functions read secrets via `defineSecret` (Google Secret Manager). Set
before deploying functions:

| Secret | Used by | Purpose |
|--------|---------|---------|
| `RESEND_API_KEY` | `onBusinessCreated`, `onBusinessVerified` | Resend API key for the "under review" and "approved" transactional emails |

```bash
firebase functions:secrets:set RESEND_API_KEY
# paste the Resend API key when prompted
```

No `.env` file is used or committed. Client Firebase config lives in the
generated `lib/firebase_options.dart` (public API keys, not secrets).

---

## App Check setup

The client activates App Check in `lib/main.dart`:

- **Release:** Play Integrity (Android) / DeviceCheck (Apple).
- **Debug / CI:** the debug provider (so emulators keep working). Can be forced
  in a release build with `--dart-define=USE_DEBUG_APP_CHECK=true` while Play
  Integrity is being configured — remove once real tokens are confirmed.

Backend enforcement:

- The **`recordEngagement`** callable sets `enforceAppCheck: true`, so only the
  genuine app (with a valid attestation token) can move engagement counters. A
  scripted caller can't inflate its own stats or drive a competitor's saver
  count negative from outside the app.

Console steps:

1. **App Check → Apps** — register the Android and Apple apps with their
   Play Integrity / DeviceCheck providers.
2. **App Check → APIs** — set **Cloud Functions** to *Enforced* (and Firestore
   /Storage to *Enforced* once you have confirmed release traffic is sending
   tokens).
3. Add a debug token for each developer/CI device you want to allow.

---

## Deployment order

Deploy in this order — it keeps the live app consistent during the rollout
(the aggregator functions must exist before the rules lock clients out of the
rating fields, and indexes must exist before the queries that use them run).

```bash
# 0. Select the project
firebase use pettahfinds-75075

# 1. Firestore indexes (queries depend on these)
firebase deploy --only firestore:indexes

# 2. Function secrets (must exist before the functions that read them)
firebase functions:secrets:set RESEND_API_KEY   # first time / on rotation

# 3. Cloud Functions — installs deps from package-lock.json in the cloud.
#    Deploying with the CLI will also prompt to DELETE any orphaned functions
#    (e.g. the removed duplicate email functions) — accept that prompt.
firebase deploy --only functions

# 4. Security rules (Firestore + Storage) — lock clients out of
#    backend-owned fields now that the functions that maintain them are live.
firebase deploy --only firestore:rules,storage

# 5. One-time rating backfill (see Migration steps) — reconcile any ratings
#    written before aggregation became backend-owned.

# 6. Turn on App Check *Enforced* for Cloud Functions in the console.

# 7. Ship the app build.
```

> **Lockfile note:** `functions/package-lock.json` must be in sync with
> `functions/package.json` or the cloud build's `npm ci` fails. After changing
> dependencies, run `npm install` in `functions/` and commit the updated lock.

---

## Migration steps — rating backfill

`scripts/backfillRatings.ts` recomputes every business and product rating
aggregate (`ratingSum` / `ratingCount` / `ratingAvg`) directly from the review
documents, using the same math as the live aggregator triggers. It **ignores**
whatever is currently stored (so pre-hardening manipulated values are
overwritten) and is **idempotent** (absolute writes; safe to re-run).

Run it **once after deploying** the functions + rules:

```bash
# Point at the project with a service-account key that can write Firestore:
export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/service-account.json

cd functions                                     # so firebase-admin resolves
npx tsx ../scripts/backfillRatings.ts            # DRY RUN — reports only
npx tsx ../scripts/backfillRatings.ts --commit   # apply the writes
```

It is **dry-run by default** and is not wired into any deploy or CI step. Flags:
`--commit` (persist), `--only=businesses|products`, `--verbose`.

---

## Rollback procedure

Everything below is a live-safe rollback. Rules and functions are versioned in
git, so rolling back is "redeploy the previous revision."

**Security rules** (fastest to revert; no data change):
```bash
git checkout <previous-good-sha> -- firebase/firestore.rules firebase/storage.rules
firebase deploy --only firestore:rules,storage
```
The Firebase Console (**Firestore → Rules → history**) can also restore a prior
ruleset with one click.

**Cloud Functions:**
```bash
git checkout <previous-good-sha> -- functions/
cd functions && npm install        # restore the matching lockfile/deps
cd .. && firebase deploy --only functions
```
For a single misbehaving function, delete it and redeploy the prior source:
`firebase functions:delete <name>`.

**Secrets:** secret versions are retained in Secret Manager; re-point with
`firebase functions:secrets:set RESEND_API_KEY` (a new version) and redeploy.

**Rating backfill:** no rollback is needed — the aggregates are derived data.
Re-running `backfillRatings.ts --commit` re-converges them to match the reviews.

---

## Tests (security-critical)

`functions/test/` holds Firestore-rules, Storage-rules, and Cloud-Function
tests covering the security boundaries (backend-owned ratings/stats, review
integrity, self-verify/role-escalation blocks, storage ownership, and the
`recordEngagement` auth/validation guards).

```bash
cd functions
npm install
npm test        # boots the Firestore/Storage emulators, then runs node --test
```

The rules tests require the Firebase emulator suite (Java); the function guard
tests run offline. See `docs/setup.md` for first-time local setup.
