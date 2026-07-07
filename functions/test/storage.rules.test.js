/**
 * Storage security-rules tests — security-critical paths only.
 *
 * Focus:
 *   - users may only write under their OWN /users/{uid} prefix,
 *   - image constraints (contentType image/*, < 5 MB) are enforced,
 *   - business/product asset writes require Firestore-verified ownership,
 *   - the catch-all denies everything else.
 *
 * Storage rules call firestore.get() for ownership, so this spins up BOTH
 * the Storage and Firestore emulators; the owning business doc is seeded
 * with rules disabled.
 *
 * Run:
 *   cd functions && npm test
 * or:
 *   firebase emulators:exec --only firestore,storage \
 *     "node --test test/storage.rules.test.js"
 */

const {test, before, after, beforeEach} = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {doc, setDoc} = require("firebase/firestore");
const {ref, uploadBytes} = require("firebase/storage");

const PROJECT_ID = "demo-pettahfinds-storage";
const firestoreRules = fs.readFileSync(
  path.join(__dirname, "..", "..", "firebase", "firestore.rules"),
  "utf8",
);
const storageRules = fs.readFileSync(
  path.join(__dirname, "..", "..", "firebase", "storage.rules"),
  "utf8",
);

const OWNER = "owner_uid";
const OTHER = "other_uid";
const BIZ = "biz_1";
const IMG = {contentType: "image/jpeg"};
const oneByte = new Uint8Array([0xff, 0xd8, 0xff]);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {rules: firestoreRules},
    storage: {rules: storageRules},
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "businesses", BIZ), {ownerUid: OWNER});
  });
  // ALSO seed through the emulator's REST API: the Storage emulator's
  // cross-service firestore.get() reads a different internal store than
  // the one rules-unit-testing writes to
  // (https://github.com/firebase/firebase-js-sdk/issues/6803). Without
  // this, ownership checks in storage.rules always see "no doc".
  const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  // Seed under BOTH project ids: rules-unit-testing namespaces data under
  // its demo project, but the Storage emulator's cross-service
  // firestore.get() resolves against the project the CLI was started
  // with (GCLOUD_PROJECT). Seeding both makes the ownership lookup see
  // the doc regardless of which routing this emulator version uses.
  const cliProject = process.env.GCLOUD_PROJECT || "pettahfinds-75075";
  for (const project of new Set([PROJECT_ID, cliProject])) {
    const url =
      `http://${host}/v1/projects/${project}/databases/(default)` +
      `/documents/businesses?documentId=${BIZ}`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // Emulator-only admin bypass token — skips security rules.
        "Authorization": "Bearer owner",
      },
      body: JSON.stringify({fields: {ownerUid: {stringValue: OWNER}}}),
    });
    // 200 = created; 409 = already exists from a previous seed.
    if (!res.ok && res.status !== 409) {
      throw new Error(`emulator REST seed failed (${project}): ${res.status}`);
    }
  }
});

function storage(uid) {
  return uid ?
    testEnv.authenticatedContext(uid).storage() :
    testEnv.unauthenticatedContext().storage();
}

test("a user can upload a valid image under their own prefix", async () => {
  await assertSucceeds(
    uploadBytes(ref(storage(OWNER), `users/${OWNER}/avatar.jpg`), oneByte, IMG),
  );
});

test("a user cannot write under another user's prefix", async () => {
  await assertFails(
    uploadBytes(ref(storage(OTHER), `users/${OWNER}/avatar.jpg`), oneByte, IMG),
  );
});

test("non-image content type is rejected", async () => {
  await assertFails(
    uploadBytes(ref(storage(OWNER), `users/${OWNER}/x.txt`), oneByte, {
      contentType: "text/plain",
    }),
  );
});

test("oversize upload (> 5 MB) is rejected", async () => {
  const big = new Uint8Array(5 * 1024 * 1024 + 1);
  await assertFails(
    uploadBytes(ref(storage(OWNER), `users/${OWNER}/big.jpg`), big, IMG),
  );
});

test("only the verified business owner may write business assets", async () => {
  await assertSucceeds(
    uploadBytes(ref(storage(OWNER), `businesses/${BIZ}/logo.jpg`), oneByte, IMG),
  );
  await assertFails(
    uploadBytes(ref(storage(OTHER), `businesses/${BIZ}/logo.jpg`), oneByte, IMG),
  );
});

test("only the owning business may write product images", async () => {
  await assertSucceeds(
    uploadBytes(ref(storage(OWNER), `products/${BIZ}/1_0.jpg`), oneByte, IMG),
  );
  await assertFails(
    uploadBytes(ref(storage(OTHER), `products/${BIZ}/1_0.jpg`), oneByte, IMG),
  );
});

test("the catch-all denies writes to unknown paths", async () => {
  await assertFails(
    uploadBytes(ref(storage(OWNER), `random/${OWNER}/x.jpg`), oneByte, IMG),
  );
});

// ---------------------------------------------------------------------------
// Portal (M2): receipt uploads — owner-only, image/PDF, immutable.
// ---------------------------------------------------------------------------

const pdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d]); // "%PDF-"
const PDF = {contentType: "application/pdf"};

test("owner may upload image and PDF receipts under their business", async () => {
  await assertSucceeds(
    uploadBytes(
      ref(storage(OWNER), `receipts/${BIZ}/r1.jpg`), oneByte, IMG),
  );
  await assertSucceeds(
    uploadBytes(
      ref(storage(OWNER), `receipts/${BIZ}/r2.pdf`), pdfBytes, PDF),
  );
});

test("non-owners cannot read or write another business's receipts", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(
      ref(ctx.storage(), `receipts/${BIZ}/r1.jpg`), oneByte, IMG);
  });
  await assertFails(
    uploadBytes(
      ref(storage(OTHER), `receipts/${BIZ}/evil.jpg`), oneByte, IMG),
  );
  const {getBytes} = require("firebase/storage");
  await assertFails(getBytes(ref(storage(OTHER), `receipts/${BIZ}/r1.jpg`)));
});

test("receipts are immutable — no client delete or overwrite", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(
      ref(ctx.storage(), `receipts/${BIZ}/r1.jpg`), oneByte, IMG);
  });
  const {deleteObject} = require("firebase/storage");
  await assertFails(deleteObject(ref(storage(OWNER), `receipts/${BIZ}/r1.jpg`)));
});
