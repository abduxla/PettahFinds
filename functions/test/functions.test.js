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
