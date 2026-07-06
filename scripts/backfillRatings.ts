/**
 * PettahFinds — one-time rating backfill / reconciliation migration.
 *
 * Recomputes every business and product rating aggregate
 * (ratingSum / ratingCount / ratingAvg) directly from the underlying
 * review documents, using the SAME math as the live aggregator triggers
 * (onReviewWritten / onProductReviewWritten in functions/index.js):
 *
 *   - each review rating is clamped to the valid [1, 5] range,
 *   - ratingSum   = Σ clamped ratings,
 *   - ratingCount = number of reviews,
 *   - ratingAvg   = round(ratingSum / ratingCount, 1)  (0 when no reviews).
 *
 * Why this exists:
 *   Rating aggregates used to be client-writable and were abused to forge
 *   or pin ratings. They are now backend-owned, but any values written
 *   BEFORE that change (or drifted by an at-least-once trigger redelivery)
 *   may be wrong. This script rebuilds them from ground truth and IGNORES
 *   whatever is currently stored on the aggregate docs — so previously
 *   manipulated values are overwritten, not trusted.
 *
 * Idempotent:
 *   It writes ABSOLUTE values (not deltas) and skips docs already correct,
 *   so it can be run repeatedly and always converges to the same result.
 *
 * Safety — DRY RUN BY DEFAULT:
 *   With no flags it only reports what WOULD change and writes nothing.
 *   Pass --commit to actually write. This script is NOT wired into any
 *   deploy or CI step; it must be invoked manually by an operator.
 *
 * Usage:
 *   # 1. Point at the target project via a service-account key with
 *   #    Firestore write access (Editor / Firebase Admin):
 *   export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/service-account.json
 *
 *   # 2. Run from the functions/ dir so `firebase-admin` resolves:
 *   cd functions
 *   npx tsx ../scripts/backfillRatings.ts                 # dry run (default)
 *   npx tsx ../scripts/backfillRatings.ts --commit        # apply writes
 *   npx tsx ../scripts/backfillRatings.ts --commit --only=businesses
 *   npx tsx ../scripts/backfillRatings.ts --commit --only=products
 *
 * Flags:
 *   --commit            Persist changes (otherwise dry run).
 *   --only=businesses   Only reconcile business ratings (from /reviews).
 *   --only=products     Only reconcile product ratings (from /productReviews).
 *   --verbose           Log every doc, not just changed ones.
 */

import {
  applicationDefault,
  initializeApp,
} from "firebase-admin/app";
import {
  getFirestore,
  Firestore,
  Query,
  QueryDocumentSnapshot,
  DocumentData,
} from "firebase-admin/firestore";

// ---------------------------------------------------------------------------
// Config / CLI
// ---------------------------------------------------------------------------

const args = new Set(process.argv.slice(2));
const COMMIT = args.has("--commit");
const VERBOSE = args.has("--verbose");
const ONLY = [...args]
  .find((a) => a.startsWith("--only="))
  ?.split("=")[1] as "businesses" | "products" | undefined;

const PAGE = 500; // read page size
const BATCH = 400; // writes per batch (500 hard cap, margin for safety)

interface Agg {
  sum: number;
  count: number;
}

/**
 * Clamp a raw review rating to the valid [1, 5] range, or null when it is
 * absent / non-numeric — identical to `ratingOf` in functions/index.js so
 * the backfill and the live trigger never disagree.
 */
function ratingOf(data: DocumentData | undefined): number | null {
  if (!data) return null;
  const r = Number(data.rating);
  if (!Number.isFinite(r)) return null;
  return Math.min(5, Math.max(1, r));
}

/** round(sum / count, 1), matching the trigger's average. */
function avgOf(sum: number, count: number): number {
  return count > 0 ? Math.round((sum / count) * 10) / 10 : 0;
}

/** Iterate every doc of a query in cursor-paged batches (memory-safe). */
async function forEachDoc(
  base: Query,
  cb: (id: string, data: DocumentData) => void,
): Promise<number> {
  let last: QueryDocumentSnapshot | undefined;
  let total = 0;
  for (;;) {
    let q = base.orderBy("__name__").limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      cb(doc.id, doc.data());
      total++;
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }
  return total;
}

/**
 * Reconcile one aggregate collection (businesses|products) against the
 * ratings tallied from its review collection.
 *
 * @param db Firestore handle.
 * @param label Human label for logs.
 * @param aggCollection Collection holding the aggregate docs.
 * @param reviewCollection Collection of review docs.
 * @param foreignKey Field on the review that names its parent doc id.
 */
async function reconcile(
  db: Firestore,
  label: string,
  aggCollection: string,
  reviewCollection: string,
  foreignKey: "businessId" | "productId",
): Promise<{scanned: number; changed: number; reviews: number}> {
  // Pass 1 — tally ratings per parent id from ground-truth reviews.
  const tally = new Map<string, Agg>();
  const reviews = await forEachDoc(
    db.collection(reviewCollection),
    (_id, data) => {
      const parentId = data[foreignKey];
      const r = ratingOf(data);
      if (typeof parentId !== "string" || !parentId || r === null) return;
      const cur = tally.get(parentId) || {sum: 0, count: 0};
      cur.sum += r;
      cur.count += 1;
      tally.set(parentId, cur);
    },
  );

  // Pass 2 — walk every aggregate doc, collecting the ones that need fixing.
  // We collect first (sync scan) then commit in bounded batches, so an
  // arbitrarily large change set never overflows Firestore's 500-write cap.
  interface Update {
    id: string;
    sum: number;
    count: number;
    avg: number;
  }
  const updates: Update[] = [];
  let scanned = 0;

  await forEachDoc(db.collection(aggCollection), (id, data) => {
    scanned++;
    const t = tally.get(id) || {sum: 0, count: 0};
    const sum = t.sum;
    const count = t.count;
    const avg = avgOf(sum, count);

    const same =
      Number(data.ratingSum) === sum &&
      Number(data.ratingCount) === count &&
      Number(data.ratingAvg) === avg;

    if (same) {
      if (VERBOSE) {
        console.log(`  = ${label} ${id} ok (avg=${avg}, n=${count})`);
      }
      return;
    }

    console.log(
      `  ~ ${label} ${id}: ` +
        `avg ${fmt(data.ratingAvg)}→${avg}, ` +
        `count ${fmt(data.ratingCount)}→${count}, ` +
        `sum ${fmt(data.ratingSum)}→${sum}`,
    );
    updates.push({id, sum, count, avg});
  });

  // Commit the change set in batches of BATCH.
  if (COMMIT) {
    for (let i = 0; i < updates.length; i += BATCH) {
      const batch = db.batch();
      for (const u of updates.slice(i, i + BATCH)) {
        batch.set(
          db.collection(aggCollection).doc(u.id),
          {ratingSum: u.sum, ratingCount: u.count, ratingAvg: u.avg},
          {merge: true},
        );
      }
      await batch.commit();
    }
  }

  return {scanned, changed: updates.length, reviews};
}

/** Pretty-print a possibly-undefined stored value. */
function fmt(v: unknown): string {
  return v === undefined || v === null ? "∅" : String(v);
}

async function main(): Promise<void> {
  initializeApp({credential: applicationDefault()});
  const db = getFirestore();

  console.log(
    `\nPettahFinds rating backfill — ${COMMIT ? "COMMIT" : "DRY RUN"}` +
      `${ONLY ? ` (only=${ONLY})` : ""}\n`,
  );

  const totals = {scanned: 0, changed: 0, reviews: 0};

  if (!ONLY || ONLY === "businesses") {
    console.log("Businesses (from /reviews):");
    const r = await reconcile(
      db,
      "business",
      "businesses",
      "reviews",
      "businessId",
    );
    console.log(
      `  → ${r.scanned} scanned, ${r.changed} to update, ` +
        `${r.reviews} reviews tallied\n`,
    );
    totals.scanned += r.scanned;
    totals.changed += r.changed;
    totals.reviews += r.reviews;
  }

  if (!ONLY || ONLY === "products") {
    console.log("Products (from /productReviews):");
    const r = await reconcile(
      db,
      "product",
      "products",
      "productReviews",
      "productId",
    );
    console.log(
      `  → ${r.scanned} scanned, ${r.changed} to update, ` +
        `${r.reviews} reviews tallied\n`,
    );
    totals.scanned += r.scanned;
    totals.changed += r.changed;
    totals.reviews += r.reviews;
  }

  console.log(
    `Done. ${totals.scanned} docs scanned, ${totals.changed} ` +
      `${COMMIT ? "updated" : "would change"}.`,
  );
  if (!COMMIT && totals.changed > 0) {
    console.log("Re-run with --commit to apply.");
  }
}

main().catch((err) => {
  console.error("backfillRatings failed:", err);
  process.exit(1);
});
