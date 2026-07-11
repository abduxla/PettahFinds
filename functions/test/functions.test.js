/**
 * Cloud Function tests — security-critical behavior only.
 *
 * Covers the `recordEngagement` callable's guards, which are the parts an
 * attacker would probe:
 *   - unauthenticated calls are rejected,
 *   - a missing/invalid businessId is rejected,
 *   - an unknown engagement type is rejected.
 *
 * These guards all throw BEFORE any Firestore write, so the tests run in
 * firebase-functions-test *offline* mode — no emulator or credentials needed.
 *
 * App Check enforcement (`enforceAppCheck: true`) is applied by the Functions
 * platform in front of the handler, so it is verified by configuration
 * (see index.js) rather than exercised here; the offline wrapper does not
 * simulate the platform's App Check gate.
 *
 * Run:
 *   cd functions && node --test test/functions.test.js
 */

const {test, before, after} = require("node:test");
const assert = require("node:assert");

const fft = require("firebase-functions-test")();
let fns;
let recordEngagement;

before(() => {
  // Requiring index.js calls admin.initializeApp() once; fft sets up the
  // offline environment first so trigger/callable registration doesn't throw.
  fns = require("../index.js");
  recordEngagement = fft.wrap(fns.recordEngagement);
});

after(() => {
  fft.cleanup();
});

// A valid App Check app is supplied on every request so that — whether or
// not the offline wrapper simulates App Check — we isolate the handler's own
// auth/validation guards under test.
const APP = {appId: "test-app"};

test("rejects unauthenticated callers", async () => {
  await assert.rejects(
    () =>
      recordEngagement({
        data: {type: "profileView", businessId: "biz_1"},
        app: APP,
        // auth intentionally omitted
      }),
    /unauthenticated|Sign in required/i,
  );
});

test("rejects a missing businessId", async () => {
  await assert.rejects(
    () =>
      recordEngagement({
        data: {type: "profileView"},
        auth: {uid: "u1", token: {}},
        app: APP,
      }),
    /businessId required|invalid-argument/i,
  );
});

test("rejects a non-string businessId", async () => {
  await assert.rejects(
    () =>
      recordEngagement({
        data: {type: "profileView", businessId: 123},
        auth: {uid: "u1", token: {}},
        app: APP,
      }),
    /businessId required|invalid-argument/i,
  );
});

test("rejects an unknown engagement type", async () => {
  await assert.rejects(
    () =>
      recordEngagement({
        data: {type: "hackity", businessId: "biz_1"},
        auth: {uid: "u1", token: {}},
        app: APP,
      }),
    /Unknown type|invalid-argument/i,
  );
});

// ---------------------------------------------------------------------------
// Portal (M2): submitPayment / reviewPayment input guards.
// All of these throw before any Firestore access, so they run offline.
// reviewPayment's admin check passes via the custom claim (token.admin),
// which also avoids a Firestore read in offline mode.
// ---------------------------------------------------------------------------

test("submitPayment rejects unauthenticated callers", async () => {
  const submitPayment = fft.wrap(fns.submitPayment);
  await assert.rejects(
    () => submitPayment({data: {}, app: APP}),
    /unauthenticated|Sign in required/i,
  );
});

test("submitPayment rejects a free/unknown tier", async () => {
  const submitPayment = fft.wrap(fns.submitPayment);
  for (const tier of ["listed", "gold", "", undefined]) {
    await assert.rejects(
      () =>
        submitPayment({
          data: {tierRequested: tier, months: 1, method: "bank_transfer",
            referenceNumber: "REF123", paidOn: "2026-07-01"},
          auth: {uid: "u1", token: {}},
          app: APP,
        }),
      /paid tier|invalid-argument/i,
    );
  }
});

test("submitPayment rejects invalid months, method, reference and date", async () => {
  const submitPayment = fft.wrap(fns.submitPayment);
  const base = {
    tierRequested: "spotlight",
    months: 1,
    method: "bank_transfer",
    referenceNumber: "REF123",
    paidOn: "2026-07-01",
  };
  const bad = [
    {...base, months: 0},
    {...base, months: 1.5},
    {...base, months: 13},
    {...base, method: "crypto"},
    {...base, referenceNumber: "xy"},
    {...base, paidOn: "01/07/2026"},
    {...base, paidOn: "2031-01-01"},
  ];
  for (const data of bad) {
    await assert.rejects(
      () => submitPayment({data, auth: {uid: "u1", token: {}}, app: APP}),
      /invalid-argument|must be|unknown/i,
    );
  }
});

test("reviewPayment rejects non-admins and bad decisions", async () => {
  const reviewPayment = fft.wrap(fns.reviewPayment);
  await assert.rejects(
    () => reviewPayment({data: {paymentId: "p", decision: "approve"},
      app: APP}),
    /unauthenticated|Sign in required/i,
  );
  await assert.rejects(
    () =>
      reviewPayment({
        data: {paymentId: "p", decision: "obliterate"},
        auth: {uid: "admin1", token: {admin: true}},
        app: APP,
      }),
    /decision must be|invalid-argument/i,
  );
  await assert.rejects(
    () =>
      reviewPayment({
        data: {decision: "approve"},
        auth: {uid: "admin1", token: {admin: true}},
        app: APP,
      }),
    /paymentId is required|invalid-argument/i,
  );
});

// ---------------------------------------------------------------------------
// Portal (M3): manageInvoice input guards (offline — throw before reads).
// ---------------------------------------------------------------------------

test("manageInvoice rejects unauthenticated callers and bad input", async () => {
  const manageInvoice = fft.wrap(fns.manageInvoice);
  await assert.rejects(
    () => manageInvoice({data: {invoiceId: "i", action: "email"}, app: APP}),
    /unauthenticated|Sign in required/i,
  );
  await assert.rejects(
    () =>
      manageInvoice({
        data: {action: "email"},
        auth: {uid: "u1", token: {}},
        app: APP,
      }),
    /invoiceId is required|invalid-argument/i,
  );
  await assert.rejects(
    () =>
      manageInvoice({
        data: {invoiceId: "i", action: "shred"},
        auth: {uid: "u1", token: {}},
        app: APP,
      }),
    /action must be|invalid-argument/i,
  );
});

// ---------------------------------------------------------------------------
// Portal (M4): requestUpgrade / decideUpgrade input guards (offline).
// ---------------------------------------------------------------------------

test("requestUpgrade rejects unauthenticated and free/unknown tiers", async () => {
  const requestUpgrade = fft.wrap(fns.requestUpgrade);
  await assert.rejects(
    () => requestUpgrade({data: {targetTier: "prime"}, app: APP}),
    /unauthenticated|Sign in required/i,
  );
  for (const tier of ["listed", "diamond", "", undefined]) {
    await assert.rejects(
      () =>
        requestUpgrade({
          data: {targetTier: tier},
          auth: {uid: "u1", token: {}},
          app: APP,
        }),
      /paid tier|invalid-argument/i,
    );
  }
});

test("decideUpgrade validates decision and required businessId", async () => {
  const decideUpgrade = fft.wrap(fns.decideUpgrade);
  await assert.rejects(
    () => decideUpgrade({data: {businessId: "b", decision: "approve"},
      app: APP}),
    /unauthenticated|Sign in required/i,
  );
  await assert.rejects(
    () =>
      decideUpgrade({
        data: {decision: "approve"},
        auth: {uid: "a", token: {admin: true}},
        app: APP,
      }),
    /businessId is required|invalid-argument/i,
  );
  await assert.rejects(
    () =>
      decideUpgrade({
        data: {businessId: "b", decision: "yeet"},
        auth: {uid: "a", token: {admin: true}},
        app: APP,
      }),
    /decision must be|invalid-argument/i,
  );
});

// ---------------------------------------------------------------------------
// Portal (M5): broadcastNotification input guards.
// ---------------------------------------------------------------------------

test("broadcastNotification rejects unauth, bad audience and bad content", async () => {
  const broadcast = fft.wrap(fns.broadcastNotification);
  await assert.rejects(
    () => broadcast({data: {audience: "all", title: "Hi all", body: "News"},
      app: APP}),
    /unauthenticated|Sign in required/i,
  );
  const admin1 = {uid: "admin1", token: {admin: true}};
  await assert.rejects(
    () => broadcast({data: {audience: "everyone", title: "Hi all",
      body: "News body"}, auth: admin1, app: APP}),
    /audience must be|invalid-argument/i,
  );
  await assert.rejects(
    () => broadcast({data: {audience: "all", title: "Hi",
      body: "x".repeat(501)}, auth: admin1, app: APP}),
    /must be|invalid-argument/i,
  );
  await assert.rejects(
    () => broadcast({data: {audience: "tier", tierId: "gold",
      title: "Hi all", body: "News body"}, auth: admin1, app: APP}),
    /tierId must be|invalid-argument/i,
  );
  await assert.rejects(
    () => broadcast({data: {audience: "single", title: "Hi all",
      body: "News body"}, auth: admin1, app: APP}),
    /businessId is required|invalid-argument/i,
  );
});

// ---------------------------------------------------------------------------
// Analytics Phase A: recordSearchEvent input guards (offline).
// ---------------------------------------------------------------------------

test("recordSearchEvent rejects unauth, bad kinds, terms and items", async () => {
  const rse = fft.wrap(fns.recordSearchEvent);
  const U = {uid: "u1", token: {}};
  await assert.rejects(
    () => rse({data: {kind: "impressions", term: "phone", items: []},
      app: APP}),
    /unauthenticated|Sign in required/i,
  );
  await assert.rejects(
    () => rse({data: {kind: "hover", term: "phone"}, auth: U, app: APP}),
    /kind must be|invalid-argument/i,
  );
  await assert.rejects(
    () => rse({data: {kind: "impressions", term: "x".repeat(61),
      items: [{productId: "p", businessId: "b", position: 1}]},
    auth: U, app: APP}),
    /term must be|invalid-argument/i,
  );
  await assert.rejects(
    () => rse({data: {kind: "impressions", term: "phone", items: []},
      auth: U, app: APP}),
    /items must contain|invalid-argument/i,
  );
  const eleven = Array.from({length: 11}, (_, i) => ({
    productId: `p${i}`, businessId: "b", position: i + 1,
  }));
  await assert.rejects(
    () => rse({data: {kind: "impressions", term: "phone", items: eleven},
      auth: U, app: APP}),
    /items must contain|invalid-argument/i,
  );
  await assert.rejects(
    () => rse({data: {kind: "impressions", term: "phone",
      items: [{productId: "p", businessId: "b", position: 99}]},
    auth: U, app: APP}),
    /each item needs|invalid-argument/i,
  );
  await assert.rejects(
    () => rse({data: {kind: "click", term: "phone", productId: "p",
      position: 3}, auth: U, app: APP}),
    /click needs|invalid-argument/i,
  );
});
