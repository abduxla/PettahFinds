/**
 * Firestore security-rules tests — security-critical paths only.
 *
 * Focus: the boundaries the Phase 1–3 hardening put in place —
 *   - rating aggregates are backend-owned (no client write path),
 *   - engagement stats are backend-owned + owner-scoped reads,
 *   - review integrity (no impersonation, pinned doc id, 1..5 bound,
 *     no merchant review-scrubbing),
 *   - business self-signup can't self-verify or seed a fake rating,
 *   - users can't self-assign the admin role.
 *
 * Run (starts the Firestore emulator, loads firebase/firestore.rules):
 *   cd functions && npm test
 * or directly:
 *   firebase emulators:exec --only firestore "node --test test/firestore.rules.test.js"
 */

const {test, before, after, beforeEach} = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  getDoc,
  updateDoc,
  deleteDoc,
} = require("firebase/firestore");

const PROJECT_ID = "demo-pettahfinds-rules";
const RULES = fs.readFileSync(
  path.join(__dirname, "..", "..", "firebase", "firestore.rules"),
  "utf8",
);

let testEnv;

// A signed-in non-admin, non-owner "attacker" and a couple of principals.
const ATTACKER = "attacker_uid";
const OWNER = "owner_uid";
const REVIEWER = "reviewer_uid";
const BIZ = "biz_1";
const PROD = "prod_1";

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {rules: RULES},
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed baseline docs with rules DISABLED (admin-equivalent seed).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "businesses", BIZ), {
      ownerUid: OWNER,
      businessName: "Seed Shop",
      isVerified: true,
      ratingAvg: 4,
      ratingCount: 2,
      ratingSum: 8,
    });
    await setDoc(doc(db, "products", PROD), {
      businessId: BIZ,
      name: "Seed Product",
      ratingAvg: 5,
      ratingCount: 1,
      ratingSum: 5,
    });
    await setDoc(doc(db, "reviews", `${REVIEWER}_${BIZ}`), {
      userId: REVIEWER,
      businessId: BIZ,
      rating: 4,
    });
    await setDoc(doc(db, "business_stats", BIZ), {profileViews: 10});
    await setDoc(doc(db, "product_stats", PROD), {businessId: BIZ, views: 5});
  });
});

function db(uid) {
  return uid ?
    testEnv.authenticatedContext(uid).firestore() :
    testEnv.unauthenticatedContext().firestore();
}

// ---------------------------------------------------------------------------
// Rating aggregates are backend-owned — NO client write path.
// ---------------------------------------------------------------------------

test("business ratingAvg/Count/Sum cannot be written by any client", async () => {
  const d = db(ATTACKER);
  await assertFails(
    updateDoc(doc(d, "businesses", BIZ), {ratingAvg: 1, ratingCount: 999}),
  );
  await assertFails(updateDoc(doc(d, "businesses", BIZ), {ratingSum: 0}));
});

test("owner also cannot edit business rating aggregates", async () => {
  await assertFails(
    updateDoc(doc(db(OWNER), "businesses", BIZ), {ratingAvg: 5}),
  );
});

test("product rating aggregates cannot be written by the owner", async () => {
  await assertFails(
    updateDoc(doc(db(OWNER), "products", PROD), {ratingAvg: 1, ratingCount: 0}),
  );
});

test("business self-signup cannot seed a non-zero rating or self-verify", async () => {
  const d = db(ATTACKER);
  await assertFails(
    setDoc(doc(d, "businesses", "biz_new"), {
      ownerUid: ATTACKER,
      isVerified: true, // self-verify — must fail
    }),
  );
  await assertFails(
    setDoc(doc(d, "businesses", "biz_new2"), {
      ownerUid: ATTACKER,
      isVerified: false,
      ratingAvg: 5, // seeded fake rating — must fail
      ratingCount: 100,
    }),
  );
  // Clean self-signup (no rating, not verified) succeeds.
  await assertSucceeds(
    setDoc(doc(d, "businesses", "biz_ok"), {
      ownerUid: ATTACKER,
      isVerified: false,
    }),
  );
});

// ---------------------------------------------------------------------------
// Engagement stats — backend-owned, owner-scoped reads.
// ---------------------------------------------------------------------------

test("clients cannot create or update business_stats / product_stats", async () => {
  const d = db(OWNER);
  await assertFails(updateDoc(doc(d, "business_stats", BIZ), {profileViews: 0}));
  await assertFails(
    setDoc(doc(d, "business_stats", "biz_x"), {profileViews: 1}),
  );
  await assertFails(updateDoc(doc(d, "product_stats", PROD), {views: 0}));
});

test("only the owning business (or admin) may read its stats", async () => {
  await assertSucceeds(getDoc(doc(db(OWNER), "business_stats", BIZ)));
  await assertFails(getDoc(doc(db(ATTACKER), "business_stats", BIZ)));
  await assertSucceeds(getDoc(doc(db(OWNER), "product_stats", PROD)));
  await assertFails(getDoc(doc(db(ATTACKER), "product_stats", PROD)));
});

// ---------------------------------------------------------------------------
// Review integrity.
// ---------------------------------------------------------------------------

test("cannot create a review impersonating another user", async () => {
  // Attacker tries to write a review as REVIEWER.
  await assertFails(
    setDoc(doc(db(ATTACKER), "reviews", `${REVIEWER}_${BIZ}`), {
      userId: REVIEWER,
      businessId: BIZ,
      rating: 1,
    }),
  );
});

test("review doc id must be pinned to `${uid}_${businessId}`", async () => {
  // Correct author, but a free-form id (spam / duplicate-stacking) must fail.
  await assertFails(
    setDoc(doc(db(REVIEWER), "reviews", "some_random_id"), {
      userId: REVIEWER,
      businessId: BIZ,
      rating: 5,
    }),
  );
});

test("review rating must be within 1..5", async () => {
  const d = db(ATTACKER);
  await assertFails(
    setDoc(doc(d, "reviews", `${ATTACKER}_${BIZ}`), {
      userId: ATTACKER,
      businessId: BIZ,
      rating: 0,
    }),
  );
  await assertFails(
    setDoc(doc(d, "reviews", `${ATTACKER}_${BIZ}`), {
      userId: ATTACKER,
      businessId: BIZ,
      rating: 6,
    }),
  );
});

test("a merchant cannot delete reviews on their own business", async () => {
  // The review-scrubbing hole that was closed: OWNER is not the author.
  await assertFails(deleteDoc(doc(db(OWNER), "reviews", `${REVIEWER}_${BIZ}`)));
  // The author may delete their own.
  await assertSucceeds(
    deleteDoc(doc(db(REVIEWER), "reviews", `${REVIEWER}_${BIZ}`)),
  );
});

// ---------------------------------------------------------------------------
// User role escalation.
// ---------------------------------------------------------------------------

test("a user cannot self-assign the admin role on create or update", async () => {
  await assertFails(
    setDoc(doc(db(ATTACKER), "users", ATTACKER), {role: "admin"}),
  );
  // Create as a normal user, then try to escalate.
  await assertSucceeds(
    setDoc(doc(db(ATTACKER), "users", ATTACKER), {role: "user"}),
  );
  await assertFails(
    updateDoc(doc(db(ATTACKER), "users", ATTACKER), {role: "admin"}),
  );
});
