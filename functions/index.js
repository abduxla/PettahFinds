/**
 * PettahFinds — Cloud Functions for FCM push notifications.
 *
 * Triggers on Firestore writes and sends a single-device push to the
 * recipient. All four functions follow the same shape:
 *   1. Read the doc that triggered the function.
 *   2. Resolve the recipient uid.
 *   3. Load /users/{uid}.fcmToken.
 *   4. Build a payload with `notification` (system tray) + `data`
 *      (deep-link route info used by the client tap handler).
 *
 * Tap routing convention (matches NotificationService._routeFor in
 * lib/services/notification_service.dart):
 *   data.type in { 'message', 'review', 'approval' }
 *   data.id   = entity id the route needs (convId / businessId / etc.)
 *
 * Deploy:
 *   firebase deploy --only functions
 */

const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {Resend} = require("resend");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// --------------------------------------------------------------------------
// Email — Resend (transactional business emails)
//
//   firebase functions:secrets:set RESEND_API_KEY
// --------------------------------------------------------------------------
const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

/** Read a user's currently-registered FCM token, or null. */
async function getUserToken(uid) {
  if (!uid) return null;
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return data.fcmToken || null;
}

/**
 * Send one push. Silently no-ops when the token is missing (the user
 * hasn't installed the app on a device yet, or revoked permissions).
 * Cleans up stale tokens on `unregistered` / `invalid-argument` so we
 * stop wasting Send quota on dead devices.
 */
async function sendPush(uid, token, title, body, data = {}) {
  if (!token) {
    logger.info("[fcm] skipping send — no token for", uid);
    return;
  }
  try {
    await messaging.send({
      token,
      notification: {title, body},
      // FCM requires string values in the data block.
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
      apns: {
        payload: {
          aps: {sound: "default", badge: 1},
        },
      },
      android: {priority: "high"},
    });
  } catch (err) {
    const code = err && err.errorInfo && err.errorInfo.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-argument" ||
      code === "messaging/invalid-registration-token"
    ) {
      // Token rotated or device revoked — strip from the user doc so
      // we don't keep re-trying.
      logger.warn("[fcm] stale token, clearing for", uid, code);
      await db.collection("users").doc(uid).update({
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmUpdatedAt: admin.firestore.FieldValue.delete(),
      }).catch(() => {});
    } else {
      logger.error("[fcm] send failed for", uid, err);
    }
  }
}

function truncate(s, max) {
  if (!s) return "";
  return s.length > max ? `${s.substring(0, max)}…` : s;
}

/**
 * Entity-escape a user-supplied string before interpolating it into
 * email HTML. businessName is merchant-controlled at signup, so an
 * unescaped value could inject markup into mail sent from our domain
 * (phishing vector). Escapes < > & " '.
 * @param {*} s Raw value (coerced to string; null/undefined → "").
 * @return {string} HTML-safe string.
 */
function escapeHtml(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// --------------------------------------------------------------------------
// 1. New chat message → push to the other participant
// --------------------------------------------------------------------------
exports.onNewMessage = onDocumentCreated(
  "conversations/{convId}/messages/{msgId}",
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const convId = event.params.convId;
    const convSnap = await db.collection("conversations").doc(convId).get();
    if (!convSnap.exists) return;
    const conv = convSnap.data() || {};
    const participants = Array.isArray(conv.participantIds) ?
      conv.participantIds :
      [];
    const recipientUid = participants.find((u) => u !== msg.senderId);
    if (!recipientUid) return;

    const senderLabel = msg.senderName || "Someone";
    const token = await getUserToken(recipientUid);
    await sendPush(
      recipientUid,
      token,
      `New message from ${senderLabel}`,
      truncate(msg.text || "", 100),
      {type: "message", id: convId},
    );
  },
);

// --------------------------------------------------------------------------
// 2a. Business submitted → email owner "under review"
// --------------------------------------------------------------------------
exports.onBusinessCreated = onDocumentCreated(
  {
    document: "businesses/{bizId}",
    secrets: [RESEND_API_KEY],
  },
  async (event) => {
    const biz = event.data?.data();
    if (!biz || !biz.ownerUid) return;

    let email;
    try {
      const authUser = await admin.auth().getUser(biz.ownerUid);
      email = authUser.email;
    } catch (err) {
      logger.warn("[resend] no auth user for", biz.ownerUid, err);
      return;
    }
    if (!email) {
      logger.info("[resend] no email for", biz.ownerUid, "— skipping");
      return;
    }

    const resend = new Resend(RESEND_API_KEY.value());
    try {
      await resend.emails.send({
        from: "PetaFinds <info@petafinds.lk>",
        to: email,
        subject: "Your PetaFinds Business Registration Is Under Review",
        html: _businessUnderReviewHtml(
          escapeHtml(biz.businessName || "Your business")),
      });
      logger.info("[resend] under-review email sent to", email);
    } catch (err) {
      logger.error("[resend] onBusinessCreated failed for", email, err);
    }
  },
);

// --------------------------------------------------------------------------
// 2b. Business approved (isVerified false → true) → push + approval email
// --------------------------------------------------------------------------
exports.onBusinessVerified = onDocumentUpdated(
  {
    document: "businesses/{bizId}",
    secrets: [RESEND_API_KEY],
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (before.isVerified === true) return;
    if (after.isVerified !== true) return;

    const ownerUid = after.ownerUid;
    if (!ownerUid) return;

    // Push notification
    const token = await getUserToken(ownerUid);
    await sendPush(
      ownerUid,
      token,
      "🎉 Your listing is approved!",
      `${after.businessName || "Your business"} is now live on PettahFinds.`,
      {type: "approval", id: event.params.bizId},
    );

    // Approval email via Resend
    let email;
    try {
      const authUser = await admin.auth().getUser(ownerUid);
      email = authUser.email;
    } catch (err) {
      logger.warn("[resend] no auth user for", ownerUid, err);
      return;
    }
    if (!email) return;

    const resend = new Resend(RESEND_API_KEY.value());
    try {
      await resend.emails.send({
        from: "PetaFinds <info@petafinds.lk>",
        to: email,
        subject: "Your PetaFinds Business Has Been Approved 🎉",
        html: _businessApprovedHtml(
          escapeHtml(after.businessName || "Your business")),
      });
      logger.info("[resend] approval email sent to", email);
    } catch (err) {
      logger.error("[resend] onBusinessVerified email failed for", email, err);
    }
  },
);

// --------------------------------------------------------------------------
// 3. New business review → push to the business owner
// --------------------------------------------------------------------------
exports.onNewReview = onDocumentCreated(
  "reviews/{reviewId}",
  async (event) => {
    const review = event.data?.data();
    if (!review || !review.businessId) return;
    const bizSnap = await db.collection("businesses")
      .doc(review.businessId).get();
    if (!bizSnap.exists) return;
    const ownerUid = bizSnap.data()?.ownerUid;
    if (!ownerUid) return;
    // Don't notify on self-reviews (shouldn't happen given the rules,
    // but cheap guard).
    if (ownerUid === review.userId) return;

    const token = await getUserToken(ownerUid);
    const rating = review.rating || 0;
    await sendPush(
      ownerUid,
      token,
      "⭐ New review on your shop",
      `Someone rated you ${rating} stars.`,
      {type: "review", id: review.businessId},
    );
  },
);

// --------------------------------------------------------------------------
// 4. New product review → push to the business owner
// --------------------------------------------------------------------------
exports.onNewProductReview = onDocumentCreated(
  "productReviews/{reviewId}",
  async (event) => {
    const review = event.data?.data();
    if (!review || !review.productId) return;
    const prodSnap = await db.collection("products")
      .doc(review.productId).get();
    if (!prodSnap.exists) return;
    const businessId = prodSnap.data()?.businessId;
    if (!businessId) return;
    const bizSnap = await db.collection("businesses").doc(businessId).get();
    if (!bizSnap.exists) return;
    const ownerUid = bizSnap.data()?.ownerUid;
    if (!ownerUid) return;
    if (ownerUid === review.userId) return;

    const token = await getUserToken(ownerUid);
    const rating = review.rating || 0;
    await sendPush(
      ownerUid,
      token,
      "⭐ New product review",
      `Your product got a ${rating}-star review.`,
      {type: "review", id: businessId},
    );
  },
);

// --------------------------------------------------------------------------
// 5. Rating aggregator — business reviews.
//    Ratings are now backend-owned: clients can no longer write ratingAvg /
//    ratingCount (see firestore.rules). This trigger keeps the business doc's
//    aggregate in sync transactionally on every review create/update/delete.
// --------------------------------------------------------------------------
exports.onReviewWritten = onDocumentWritten(
  "reviews/{reviewId}",
  async (event) => {
    const before = event.data && event.data.before && event.data.before.data();
    const after = event.data && event.data.after && event.data.after.data();
    const businessId =
      (after && after.businessId) || (before && before.businessId);
    if (!businessId) return;
    await applyRatingDelta(
      db.collection("businesses").doc(businessId),
      ratingOf(before),
      ratingOf(after),
    );
  },
);

// --------------------------------------------------------------------------
// 6. Rating aggregator — product reviews → parent product doc.
// --------------------------------------------------------------------------
exports.onProductReviewWritten = onDocumentWritten(
  "productReviews/{reviewId}",
  async (event) => {
    const before = event.data && event.data.before && event.data.before.data();
    const after = event.data && event.data.after && event.data.after.data();
    const productId =
      (after && after.productId) || (before && before.productId);
    if (!productId) return;
    await applyRatingDelta(
      db.collection("products").doc(productId),
      ratingOf(before),
      ratingOf(after),
    );
  },
);

/**
 * Read a review's numeric rating clamped to [1,5], or null when absent.
 * @param {*} data Review doc data or undefined.
 * @return {?number} Clamped rating or null.
 */
function ratingOf(data) {
  if (!data) return null;
  const r = Number(data.rating);
  if (!Number.isFinite(r)) return null;
  return Math.min(5, Math.max(1, r));
}

/**
 * Apply a rating change to an aggregate doc transactionally.
 *   create (null→r): count+1, sum+r
 *   delete (r→null): count-1, sum-r
 *   update (a→b):    sum+=(b-a), count unchanged
 * Uses a running ratingSum on the doc so we never scan the whole review
 * collection; falls back to avg*count for docs that predate ratingSum.
 * @param {FirebaseFirestore.DocumentReference} ref Aggregate doc.
 * @param {?number} before Prior rating (null on create).
 * @param {?number} after New rating (null on delete).
 * @return {Promise<void>}
 */
async function applyRatingDelta(ref, before, after) {
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) return;
    const data = snap.data() || {};
    let count = Number(data.ratingCount) || 0;
    let sum = data.ratingSum != null ?
      Number(data.ratingSum) :
      (Number(data.ratingAvg) || 0) * count;

    if (before == null && after != null) {
      count += 1;
      sum += after;
    } else if (before != null && after == null) {
      count -= 1;
      sum -= before;
    } else if (before != null && after != null) {
      sum += after - before;
    } else {
      return;
    }

    if (count <= 0) {
      count = 0;
      sum = 0;
    }
    if (sum < 0) sum = 0;
    const avg = count > 0 ? Math.round((sum / count) * 10) / 10 : 0;
    txn.update(ref, {ratingCount: count, ratingSum: sum, ratingAvg: avg});
  });
}

// --------------------------------------------------------------------------
// 7. Business deletion cascade.
//    Owners can no longer delete reviews via rules (that path was abused to
//    scrub negative reviews). When a business doc is deleted the backend
//    removes everything tied to it — reviews, product reviews, products,
//    offers, analytics — with the Admin SDK bypassing rules.
// --------------------------------------------------------------------------
exports.onBusinessDeleted = onDocumentDeleted(
  "businesses/{bizId}",
  async (event) => {
    const bizId = event.params.bizId;
    const productsSnap = await db.collection("products")
      .where("businessId", "==", bizId).get();

    await Promise.all([
      deleteByQuery(db.collection("reviews").where("businessId", "==", bizId)),
      deleteByQuery(
        db.collection("productReviews").where("businessId", "==", bizId)),
      deleteByQuery(db.collection("offers").where("businessId", "==", bizId)),
      deleteByQuery(
        db.collection("product_stats").where("businessId", "==", bizId)),
      deleteRefs(productsSnap.docs.map((d) => d.ref)),
      db.collection("business_stats").doc(bizId).delete().catch(() => {}),
    ]);

    logger.info("[cascade] business", bizId, "wiped",
      productsSnap.size, "products + associated reviews/offers/stats");
  },
);

/**
 * Delete every doc matched by a query, paged under the batch ceiling.
 * @param {FirebaseFirestore.Query} query Query to drain.
 * @return {Promise<void>}
 */
async function deleteByQuery(query) {
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) break;
    await deleteRefs(snap.docs.map((d) => d.ref));
    if (snap.size < 400) break;
  }
}

/**
 * Batch-delete refs, 450 per batch (500 hard cap, 50-op safety margin).
 * @param {Array<FirebaseFirestore.DocumentReference>} refs Refs to delete.
 * @return {Promise<void>}
 */
async function deleteRefs(refs) {
  let batch = db.batch();
  let ops = 0;
  for (const ref of refs) {
    batch.delete(ref);
    if (++ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();
}

// --------------------------------------------------------------------------
// 8. Engagement analytics — server-authoritative counters.
//    Clients can no longer write business_stats / product_stats directly
//    (rules: allow create, update: if false). They call this callable, which
//    applies bounded FieldValue.increment writes via the Admin SDK — so a
//    competitor's numbers can't be forged or zeroed.
//
//    App Check is ENFORCED: the callable only accepts requests carrying a
//    valid App Check token (Play Integrity / DeviceCheck in release — see
//    lib/main.dart), so an attacker can't script raw calls from outside the
//    genuine app to inflate their own stats or spam `unsave` to drive a
//    competitor's saver count negative. Each increment is a single atomic
//    FieldValue.increment, so concurrent events are race-safe and never
//    double-count on the server side.
// --------------------------------------------------------------------------
exports.recordEngagement = onCall({enforceAppCheck: true}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const {type, businessId, productId} = request.data || {};
  if (typeof businessId !== "string" || !businessId) {
    throw new HttpsError("invalid-argument", "businessId required.");
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const inc = (n) => admin.firestore.FieldValue.increment(n);
  const bizRef = db.collection("business_stats").doc(businessId);
  const prodRef = (typeof productId === "string" && productId) ?
    db.collection("product_stats").doc(productId) :
    null;
  const writes = [];

  switch (type) {
    case "profileView":
      writes.push(bizRef.set(
        {profileViews: inc(1), updatedAt: now}, {merge: true}));
      break;
    case "productView":
      writes.push(bizRef.set(
        {productViews: inc(1), updatedAt: now}, {merge: true}));
      if (prodRef) {
        writes.push(prodRef.set(
          {businessId, views: inc(1), updatedAt: now}, {merge: true}));
      }
      break;
    case "chatStarted":
      writes.push(bizRef.set(
        {chatsStarted: inc(1), updatedAt: now}, {merge: true}));
      if (prodRef) {
        writes.push(prodRef.set(
          {businessId, chats: inc(1), updatedAt: now}, {merge: true}));
      }
      break;
    case "save":
    case "unsave": {
      const d = type === "save" ? 1 : -1;
      writes.push(bizRef.set({saves: inc(d), updatedAt: now}, {merge: true}));
      if (prodRef) {
        writes.push(prodRef.set(
          {businessId, saves: inc(d), updatedAt: now}, {merge: true}));
      }
      break;
    }
    default:
      throw new HttpsError("invalid-argument", `Unknown type: ${type}`);
  }

  await Promise.all(writes);
  return {ok: true};
});

// --------------------------------------------------------------------------
// 9. Upload validation — magic-byte check.
//    Storage rules gate on contentType, which is client-supplied and
//    spoofable. This trigger re-reads the object header after upload and
//    deletes anything whose real bytes don't match a known image format,
//    so a renamed script/HTML/exe can't sit in a public bucket.
// --------------------------------------------------------------------------
exports.validateUpload = onObjectFinalized(async (event) => {
  const obj = event.data;
  const name = obj.name || "";
  // Only guard user-generated image paths (see storage.rules).
  if (!/^(users|businesses|products)\//.test(name)) return;

  const bucket = admin.storage().bucket(obj.bucket);
  const file = bucket.file(name);

  const contentType = obj.contentType || "";
  if (!contentType.startsWith("image/")) {
    logger.warn("[upload] non-image contentType, deleting", name, contentType);
    await file.delete().catch(() => {});
    return;
  }

  let header;
  try {
    const [buf] = await file.download({start: 0, end: 15});
    header = buf;
  } catch (err) {
    logger.error("[upload] header read failed for", name, err);
    return; // don't delete on a transient read error
  }

  if (!isRealImage(header)) {
    logger.warn("[upload] magic-byte mismatch, deleting", name, contentType);
    await file.delete().catch(() => {});
  }
});

/**
 * True when the leading bytes match a known image format
 * (JPEG, PNG, GIF, WebP, HEIC/HEIF).
 * @param {Buffer} b First bytes of the object (>=12 recommended).
 * @return {boolean} Whether the header is a recognised image.
 */
function isRealImage(b) {
  if (!b || b.length < 12) return false;
  // JPEG: FF D8 FF
  if (b[0] === 0xFF && b[1] === 0xD8 && b[2] === 0xFF) return true;
  // PNG: 89 50 4E 47
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4E && b[3] === 0x47) {
    return true;
  }
  // GIF: 47 49 46 38 ("GIF8")
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x38) {
    return true;
  }
  // WebP: "RIFF"...."WEBP"
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 &&
      b[8] === 0x57 && b[9] === 0x45 && b[10] === 0x42 && b[11] === 0x50) {
    return true;
  }
  // HEIC/HEIF (iOS camera): bytes 4-7 == "ftyp"
  if (b[4] === 0x66 && b[5] === 0x74 && b[6] === 0x79 && b[7] === 0x70) {
    return true;
  }
  return false;
}

// --------------------------------------------------------------------------
// Email HTML templates (Resend)
// --------------------------------------------------------------------------

function _businessUnderReviewHtml(businessName) {
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 540px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 32px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 26px; font-weight: 800;
          letter-spacing: -0.5px;">
          PetaFinds
        </h1>
      </div>
      <div style="padding: 36px 32px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8; border-top: none;">
        <h2 style="margin: 0 0 8px; font-size: 22px; font-weight: 800;
          color: #1A1A1A; letter-spacing: -0.3px;">
          Your business is under review
        </h2>
        <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 20px;">
          Hi there! Thank you for registering
          <strong>${businessName}</strong> with PetaFinds.
        </p>
        <div style="background: #FFF8F0; border-left: 4px solid #E8821A;
          padding: 16px 20px; border-radius: 8px; margin-bottom: 24px;">
          <p style="margin: 0; font-size: 14px; color: #E8821A; font-weight: 700;">
            ⏱ Expected review time: 24–48 hours
          </p>
          <p style="margin: 8px 0 0; font-size: 14px; color: #7A4A00;">
            Our team will verify your business information and approve your
            listing shortly.
          </p>
        </div>
        <p style="font-size: 14px; color: #555; line-height: 1.65; margin: 0 0 24px;">
          Once approved, <strong>${businessName}</strong> will become visible
          to thousands of customers searching for products and shops in Pettah.
          You will receive another email when your account is approved.
        </p>
        <p style="font-size: 14px; color: #555; line-height: 1.65; margin: 0 0 24px;">
          In the meantime, you can browse PetaFinds as a customer to get
          familiar with the platform.
        </p>
        <p style="margin-top: 32px; font-size: 12px; color: #9E9E9E;">
          PetaFinds · Bringing Pettah online · Colombo 11
        </p>
      </div>
    </div>
  `;
}

function _businessApprovedHtml(businessName) {
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 540px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 32px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 26px; font-weight: 800;
          letter-spacing: -0.5px;">
          PetaFinds
        </h1>
      </div>
      <div style="padding: 36px 32px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8; border-top: none;">
        <h2 style="margin: 0 0 8px; font-size: 22px; font-weight: 800;
          color: #1A1A1A; letter-spacing: -0.3px;">
          🎉 Your business has been approved!
        </h2>
        <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 20px;">
          Great news! <strong>${businessName}</strong> is now live on PetaFinds
          and visible to customers across Colombo.
        </p>
        <div style="background: #F0FFF8; border-left: 4px solid #095858;
          padding: 16px 20px; border-radius: 8px; margin-bottom: 24px;">
          <p style="margin: 0; font-size: 14px; color: #095858; font-weight: 700;">
            ✅ Your listing is now active
          </p>
          <p style="margin: 8px 0 0; font-size: 14px; color: #1A5C44;">
            Customers can now find your business, browse your products, and
            contact you directly through the app.
          </p>
        </div>
        <p style="font-size: 14px; color: #555; line-height: 1.65; margin: 0 0 24px;">
          Open the PetaFinds app to access your business dashboard, add
          products, and start connecting with customers.
        </p>
        <p style="margin-top: 32px; font-size: 12px; color: #9E9E9E;">
          PetaFinds · Bringing Pettah online · Colombo 11
        </p>
      </div>
    </div>
  `;
}

// ============================================================================
// PORTAL — Business Membership & Administration Portal backend
// ============================================================================

/** Public URL of the deployed portal (Firebase Hosting default site). */
const PORTAL_URL = "https://pettahfinds-75075.web.app";

/**
 * Append an immutable entry to /auditLogs. The collection is server-write
 * only (rules deny all client writes), so entries are tamper-proof.
 * Never throws — auditing must not break the action being audited.
 * @param {object} entry {action, actorUid, targetType, targetId, details}
 */
async function writeAudit(entry) {
  try {
    await db.collection("auditLogs").add({
      ...entry,
      at: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("[audit] write failed", entry.action, err);
  }
}

/**
 * True when the caller is an administrator — same dual check as the
 * Firestore rules isAdmin(): custom claim `admin` OR users-doc role.
 * @param {object} auth request.auth from a callable.
 * @return {Promise<boolean>} whether the caller is an admin.
 */
async function callerIsAdmin(auth) {
  if (!auth) return false;
  if (auth.token && auth.token.admin === true) return true;
  const snap = await db.collection("users").doc(auth.uid).get();
  return snap.exists && (snap.data() || {}).role === "admin";
}

/**
 * Generate a cryptographically-secure temporary password: 14 chars with
 * guaranteed upper/lower/digit/symbol coverage (satisfies common
 * complexity rules), Fisher-Yates shuffled with crypto randomness.
 * @return {string} the generated password.
 */
function generateTempPassword() {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // no I/O (ambiguous)
  const lower = "abcdefghijkmnpqrstuvwxyz"; // no l/o
  const digits = "23456789"; // no 0/1
  const symbols = "!@#$%&*+?";
  const all = upper + lower + digits + symbols;
  const pick = (set) => set[crypto.randomInt(set.length)];
  const chars = [pick(upper), pick(lower), pick(digits), pick(symbols)];
  while (chars.length < 14) chars.push(pick(all));
  for (let i = chars.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join("");
}

// --------------------------------------------------------------------------
// provisionPortalAccess — admin-only callable.
//
// Creates (or resets) the portal sign-in for a business:
//   - no Firebase Auth user for the business email: create one with a
//     temporary password;
//   - existing user: reset their password to a new temporary one
//     (the documented regenerate/reset/resend flow).
// Then upserts /users/{uid} (role=business, businessId, mustChangePassword),
// links businesses.ownerUid when unset, emails the credentials via Resend,
// and writes an audit entry.
//
// The temporary password is delivered ONLY by email — it is never returned
// to the calling client.
// --------------------------------------------------------------------------
exports.provisionPortalAccess = onCall(
  {enforceAppCheck: true, secrets: [RESEND_API_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    if (!(await callerIsAdmin(request.auth))) {
      throw new HttpsError("permission-denied", "Administrators only.");
    }

    const businessId = String((request.data || {}).businessId || "").trim();
    if (!businessId || businessId.length > 128) {
      throw new HttpsError("invalid-argument", "businessId is required.");
    }

    const bizSnap = await db.collection("businesses").doc(businessId).get();
    if (!bizSnap.exists) {
      throw new HttpsError("not-found", "Business not found.");
    }
    const biz = bizSnap.data() || {};
    const email = String(biz.email || "").trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      throw new HttpsError(
          "failed-precondition",
          "The business has no valid email address on file. " +
          "Add one to the business profile first.",
      );
    }

    // Find or create the Firebase Auth identity for this email.
    const tempPassword = generateTempPassword();
    let userRecord;
    let created = false;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (err) {
      if (err && err.code === "auth/user-not-found") {
        userRecord = await admin.auth().createUser({
          email,
          password: tempPassword,
          displayName: biz.ownerName || biz.businessName || undefined,
          emailVerified: false,
        });
        created = true;
      } else {
        throw new HttpsError("internal", "Auth lookup failed.");
      }
    }

    // Ownership guards — never silently re-bind identities:
    //   - business already owned by a DIFFERENT auth user: conflict;
    //   - auth user already linked to a DIFFERENT business: conflict.
    if (biz.ownerUid && biz.ownerUid !== userRecord.uid) {
      throw new HttpsError(
          "failed-precondition",
          "This business is owned by a different account " +
          "(the email on file belongs to someone else). " +
          "Fix the business email or the owner link first.",
      );
    }
    const userDocRef = db.collection("users").doc(userRecord.uid);
    const userDoc = await userDocRef.get();
    const existingBizId = userDoc.exists ?
      (userDoc.data() || {}).businessId : null;
    if (existingBizId && existingBizId !== businessId) {
      throw new HttpsError(
          "failed-precondition",
          "This email's account is already linked to another business.",
      );
    }

    // Existing identity: rotate the password (reset/regenerate flow).
    if (!created) {
      await admin.auth().updateUser(userRecord.uid, {password: tempPassword});
      // Kill existing sessions so anything using the old password dies.
      await admin.auth().revokeRefreshTokens(userRecord.uid);
    }

    // Upsert the profile the portal/app routing relies on.
    await userDocRef.set({
      email,
      displayName: userDoc.exists ?
        ((userDoc.data() || {}).displayName || biz.ownerName || "") :
        (biz.ownerName || ""),
      role: "business",
      businessId,
      onboardingCompleted: true,
      mustChangePassword: true,
      ...(userDoc.exists ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    }, {merge: true});

    // Link the business to its owner when not yet linked.
    if (!biz.ownerUid) {
      await bizSnap.ref.update({ownerUid: userRecord.uid});
    }

    // Deliver credentials — email only, never in the response.
    const resend = new Resend(RESEND_API_KEY.value());
    try {
      await resend.emails.send({
        from: "PetaFinds <info@petafinds.lk>",
        to: email,
        subject: created ?
          "Your PetaFinds Business Portal access" :
          "Your PetaFinds Business Portal password was reset",
        html: _portalCredentialsHtml(
            escapeHtml(biz.businessName || "your business"),
            escapeHtml(email),
            escapeHtml(tempPassword),
            created,
        ),
      });
    } catch (err) {
      logger.error("[portal] credentials email failed for", email, err);
      throw new HttpsError(
          "internal",
          "Account was prepared but the credentials email failed to " +
          "send. Use Resend access to try again.",
      );
    }

    await writeAudit({
      action: created ? "portal_access_provisioned" : "portal_password_reset",
      actorUid: request.auth.uid,
      targetType: "business",
      targetId: businessId,
      details: {email, authUid: userRecord.uid},
    });

    logger.info(
        "[portal]", created ? "provisioned" : "reset", email,
        "for business", businessId, "by", request.auth.uid,
    );
    return {ok: true, email, created};
  },
);

/**
 * Credentials email — matches the house template style above.
 * @param {string} businessName Escaped business name.
 * @param {string} email Escaped sign-in email.
 * @param {string} tempPassword Escaped temporary password.
 * @param {boolean} created True on first provisioning, false on reset.
 * @return {string} HTML body.
 */
function _portalCredentialsHtml(businessName, email, tempPassword, created) {
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 540px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 32px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 26px; font-weight: 800;
          letter-spacing: -0.5px;">
          PetaFinds
        </h1>
      </div>
      <div style="padding: 36px 32px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8; border-top: none;">
        <h2 style="margin: 0 0 8px; font-size: 22px; font-weight: 800;
          color: #1A1A1A; letter-spacing: -0.3px;">
          ${created ? "Your Business Portal access is ready" :
            "Your portal password was reset"}
        </h2>
        <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 20px;">
          Sign in to the PetaFinds Business Portal to manage the membership,
          payments and invoices for <strong>${businessName}</strong>.
        </p>
        <div style="background: #E8F4F4; border-left: 4px solid #095858;
          padding: 16px 20px; border-radius: 8px; margin-bottom: 24px;">
          <p style="margin: 0 0 6px; font-size: 14px; color: #095858;">
            <strong>Sign-in email:</strong> ${email}
          </p>
          <p style="margin: 0; font-size: 14px; color: #095858;">
            <strong>Temporary password:</strong>
            <code style="background: #fff; padding: 2px 8px; border-radius: 4px;
              font-size: 14px;">${tempPassword}</code>
          </p>
        </div>
        <div style="background: #FFF8F0; border-left: 4px solid #E8821A;
          padding: 16px 20px; border-radius: 8px; margin-bottom: 24px;">
          <p style="margin: 0; font-size: 14px; color: #7A4A00;">
            &#128274; You will be asked to choose a new password the first
            time you sign in. This temporary password stops working after
            that.
          </p>
        </div>
        <p style="text-align: center; margin: 0 0 24px;">
          <a href="${PORTAL_URL}/sign-in"
            style="display: inline-block; background: #095858; color: #fff;
            text-decoration: none; font-weight: 700; font-size: 15px;
            padding: 12px 28px; border-radius: 10px;">
            Open the Business Portal
          </a>
        </p>
        <p style="margin-top: 32px; font-size: 12px; color: #9E9E9E;">
          If you did not expect this email, contact support@petafinds.lk.
          <br>PetaFinds · Bringing Pettah online · Colombo 11
        </p>
      </div>
    </div>
  `;
}
