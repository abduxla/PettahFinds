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
