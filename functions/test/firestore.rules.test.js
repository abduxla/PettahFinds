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

// ---------------------------------------------------------------------------
// Portal (M1): mustChangePassword transitions + auditLogs lockdown.
// ---------------------------------------------------------------------------

test("owner may clear mustChangePassword but never set it", async () => {
  // Seed a provisioned user (as the backend would, bypassing rules).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "users", OWNER), {
      role: "business",
      businessId: BIZ,
      mustChangePassword: true,
    });
  });
  // Clearing the flag after the forced change: allowed.
  await assertSucceeds(
    updateDoc(doc(db(OWNER), "users", OWNER), {mustChangePassword: false}),
  );
  // Re-arming it client-side: denied (Admin SDK / admins only).
  await assertFails(
    updateDoc(doc(db(OWNER), "users", OWNER), {mustChangePassword: true}),
  );
});

test("auditLogs reject every client write, including from the subject", async () => {
  await assertFails(
    setDoc(doc(db(OWNER), "auditLogs", "forged"), {
      action: "portal_password_reset",
      actorUid: OWNER,
    }),
  );
  await assertFails(
    setDoc(doc(db(ATTACKER), "auditLogs", "forged2"), {action: "x"}),
  );
  // Non-admins cannot read the trail either.
  const snap = getDoc(doc(db(ATTACKER), "auditLogs", "any"));
  await assertFails(snap);
});

// ---------------------------------------------------------------------------
// Portal (M2): payments are backend-owned; portalConfig is admin-write.
// ---------------------------------------------------------------------------

test("payments cannot be created or mutated by any client", async () => {
  // Even the legitimate owner cannot fabricate a payment doc client-side.
  await assertFails(
    setDoc(doc(db(OWNER), "payments", "forged"), {
      businessId: BIZ,
      amountLkr: 1,
      status: "approved",
    }),
  );
  // Seed a real payment (as the backend would), then try to self-approve.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "businesses", BIZ), {ownerUid: OWNER});
    await setDoc(doc(ctx.firestore(), "payments", "pay_1"), {
      businessId: BIZ,
      amountLkr: 5490,
      status: "pending_verification",
    });
  });
  await assertFails(
    updateDoc(doc(db(OWNER), "payments", "pay_1"), {status: "approved"}),
  );
  await assertFails(deleteDoc(doc(db(OWNER), "payments", "pay_1")));
});

test("a business reads only its own payments", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "businesses", BIZ), {ownerUid: OWNER});
    await setDoc(doc(ctx.firestore(), "payments", "pay_1"), {
      businessId: BIZ,
      amountLkr: 5490,
      status: "pending_verification",
    });
  });
  await assertSucceeds(getDoc(doc(db(OWNER), "payments", "pay_1")));
  await assertFails(getDoc(doc(db(ATTACKER), "payments", "pay_1")));
});

test("payment_dupes locks are invisible to all clients", async () => {
  await assertFails(getDoc(doc(db(OWNER), "payment_dupes", "any")));
  await assertFails(
    setDoc(doc(db(ATTACKER), "payment_dupes", "k"), {paymentId: "x"}),
  );
});

test("portalConfig: signed-in read, admin-only write", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "portalConfig", "payments"), {
      bank: "Test Bank",
    });
  });
  await assertSucceeds(getDoc(doc(db(OWNER), "portalConfig", "payments")));
  await assertFails(
    setDoc(doc(db(OWNER), "portalConfig", "payments"), {bank: "Evil Bank"}),
  );
});

// ---------------------------------------------------------------------------
// Portal (M3): invoices are backend-issued and immutable; counters private.
// ---------------------------------------------------------------------------

test("invoices cannot be created or mutated by any client", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "businesses", BIZ), {ownerUid: OWNER});
    await setDoc(doc(ctx.firestore(), "invoices", "inv_1"), {
      invoiceNumber: "INV-2026-0001",
      businessId: BIZ,
      amountLkr: 5490,
      status: "paid",
    });
  });
  // Owner cannot forge, edit (e.g. self-void or change the amount) or purge.
  await assertFails(
    setDoc(doc(db(OWNER), "invoices", "forged"), {
      invoiceNumber: "INV-9999-9999",
      businessId: BIZ,
      amountLkr: 1,
      status: "paid",
    }),
  );
  await assertFails(
    updateDoc(doc(db(OWNER), "invoices", "inv_1"), {amountLkr: 1}),
  );
  await assertFails(deleteDoc(doc(db(OWNER), "invoices", "inv_1")));
});

test("a business reads only its own invoices; counters are private", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "businesses", BIZ), {ownerUid: OWNER});
    await setDoc(doc(ctx.firestore(), "invoices", "inv_1"), {
      invoiceNumber: "INV-2026-0001",
      businessId: BIZ,
      amountLkr: 5490,
      status: "paid",
    });
    await setDoc(doc(ctx.firestore(), "counters", "invoices"), {
      year: 2026, seq: 1,
    });
  });
  await assertSucceeds(getDoc(doc(db(OWNER), "invoices", "inv_1")));
  await assertFails(getDoc(doc(db(ATTACKER), "invoices", "inv_1")));
  await assertFails(getDoc(doc(db(OWNER), "counters", "invoices")));
  await assertFails(
    setDoc(doc(db(ATTACKER), "counters", "invoices"), {seq: 9999}),
  );
});

// ---------------------------------------------------------------------------
// Portal (M4): upgrade requests backend-owned; rate-limiter state private.
// ---------------------------------------------------------------------------

test("upgradeRequests: owner reads own, nobody writes client-side", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "businesses", BIZ), {ownerUid: OWNER});
    await setDoc(doc(ctx.firestore(), "upgradeRequests", BIZ), {
      businessId: BIZ,
      currentTier: "listed",
      targetTier: "prime",
      status: "pending",
    });
  });
  await assertSucceeds(getDoc(doc(db(OWNER), "upgradeRequests", BIZ)));
  await assertFails(getDoc(doc(db(ATTACKER), "upgradeRequests", BIZ)));
  // Owner cannot self-approve, retarget, or forge a request.
  await assertFails(
    updateDoc(doc(db(OWNER), "upgradeRequests", BIZ), {status: "approved"}),
  );
  await assertFails(
    setDoc(doc(db(ATTACKER), "upgradeRequests", "other_biz"), {
      status: "approved",
    }),
  );
  await assertFails(deleteDoc(doc(db(OWNER), "upgradeRequests", BIZ)));
});

test("rateLimits are fully private", async () => {
  await assertFails(getDoc(doc(db(OWNER), "rateLimits", "submitPayment:x")));
  await assertFails(
    setDoc(doc(db(ATTACKER), "rateLimits", "submitPayment:attacker_uid"), {
      stamps: [],
    }),
  );
});
