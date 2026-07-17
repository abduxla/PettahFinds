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
const {onSchedule} = require("firebase-functions/v2/scheduler");
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
    if (!biz) return;
    const bizId = event.params.bizId;
    const resend = new Resend(RESEND_API_KEY.value());

    // ---- 0. Founding-50 stamp: the first 50 businesses to ever join get
    // a permanent "Founding Business" badge. Transactional against
    // counters/founding so concurrent signups can't both take rank #50,
    // and re-checked against the doc so a trigger retry can't stamp (or
    // count) the same business twice. Clients can never write this field
    // (rules block it on create AND update) — this is the only mint path.
    const FOUNDING_LIMIT = 50;
    try {
      await db.runTransaction(async (txn) => {
        const counterRef = db.collection("counters").doc("founding");
        const [counterSnap, bizSnap] = await Promise.all([
          txn.get(counterRef),
          txn.get(event.data.ref),
        ]);
        if (!bizSnap.exists) return;
        if ((bizSnap.data() || {}).foundingMember === true) return;
        const count = counterSnap.exists ?
          ((counterSnap.data() || {}).count || 0) : 0;
        if (count >= FOUNDING_LIMIT) return;
        txn.set(counterRef, {count: count + 1}, {merge: true});
        txn.update(event.data.ref, {
          foundingMember: true,
          foundingRank: count + 1,
        });
        logger.info("[founding] stamped", bizId, "rank", count + 1);
      });
    } catch (err) {
      logger.error("[founding] stamp failed for", bizId, err);
    }

    // ---- 1. Internal alert to the PetaFinds team (fires for EVERY new
    // business, whether it came from app self-signup or admin onboarding;
    // independent of the merchant email below). Recipient is configurable
    // in portalConfig/notifications.newBusinessEmail. ----
    try {
      let teamEmail = "support@petafinds.lk";
      try {
        const cfg = await db.collection("portalConfig")
            .doc("notifications").get();
        const configured = cfg.exists ?
          String((cfg.data() || {}).newBusinessEmail || "").trim() : "";
        if (configured) teamEmail = configured;
      } catch (err) {
        logger.warn("[alert] notifications config read failed", err);
      }
      await resend.emails.send({
        from: "PetaFinds <info@petafinds.lk>",
        to: teamEmail,
        subject: `New business registered: ${
          (biz.businessName || "Unnamed").substring(0, 80)}`,
        html: _newBusinessAlertHtml({
          businessName: escapeHtml(biz.businessName || "—"),
          category: escapeHtml(biz.category || "—"),
          location: escapeHtml(biz.location || "—"),
          ownerName: escapeHtml(biz.ownerName || "—"),
          ownerPhone: escapeHtml(biz.ownerPhone || biz.phone || "—"),
          email: escapeHtml(biz.email || "—"),
          source: biz.createdByAdminUid ?
            "Admin onboarding" : "Self signup (app)",
          reviewUrl: `${PORTAL_URL}/admin/business/?id=${
            encodeURIComponent(bizId)}`,
        }),
      });
      logger.info("[alert] new-business alert sent to", teamEmail);
    } catch (err) {
      logger.error("[alert] new-business alert failed", err);
    }

    // ---- 2. "Under review" email to the merchant. ----
    if (!biz.ownerUid) return;
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

/**
 * Internal team alert for a new business registration.
 * @param {object} v Pre-escaped display values.
 * @return {string} HTML body.
 */
function _newBusinessAlertHtml(v) {
  const row = (label, value) => `
    <tr>
      <td style="padding: 8px 14px; font-size: 13px; color: #777;
        border-bottom: 1px solid #EFEFEF; white-space: nowrap;">${label}</td>
      <td style="padding: 8px 14px; font-size: 13px; color: #1A1A1A;
        font-weight: 600; border-bottom: 1px solid #EFEFEF;">${value}</td>
    </tr>`;
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 540px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 24px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 20px; font-weight: 800;">
          🏪 New business registration
        </h1>
      </div>
      <div style="padding: 28px 24px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8; border-top: none;">
        <table style="width: 100%; border-collapse: collapse; background: #fff;
          border: 1px solid #E8E8E8; border-radius: 8px; margin-bottom: 20px;">
          ${row("Business", v.businessName)}
          ${row("Category", v.category)}
          ${row("Location", v.location)}
          ${row("Owner", v.ownerName)}
          ${row("Phone", v.ownerPhone)}
          ${row("Email", v.email)}
          ${row("Source", v.source)}
        </table>
        <p style="text-align: center; margin: 0;">
          <a href="${v.reviewUrl}"
            style="display: inline-block; background: #E8821A; color: #fff;
            text-decoration: none; font-weight: 700; font-size: 14px;
            padding: 11px 24px; border-radius: 10px;">
            Review in Admin Portal
          </a>
        </p>
      </div>
    </div>
  `;
}

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

  // Daily rollups (Analytics Phase A): every event ALSO lands in a
  // per-day bucket so the portal BI module can answer time-filtered
  // questions (Today / 7d / 30d / trends). The lifetime counters above
  // remain the app dashboard's source of truth.
  const day = colomboDayKey();
  const bizDayRef =
    db.collection("stats_daily").doc(`${businessId}_${day}`);
  const prodDayRef = prodRef ?
    db.collection("product_stats_daily").doc(`${productId}_${day}`) :
    null;
  const bizDaily = (fields) => writes.push(bizDayRef.set(
      {businessId, date: day, ...fields, updatedAt: now}, {merge: true}));
  const prodDaily = (fields) => {
    if (prodDayRef) {
      writes.push(prodDayRef.set(
          {productId, businessId, date: day, ...fields, updatedAt: now},
          {merge: true}));
    }
  };

  // Total-exposure counting with a light abuse guard. Every genuine
  // repeat view counts (the counter represents exposure, not unique
  // visitors), but the same viewer hammering one product is bounded:
  // a counted view per (viewer, product) at most every 20 seconds and
  // at most 30 per day. App Check already blocks scripted callers
  // outside the genuine app; this bounds what one real device can
  // inflate. Uncounted calls still return ok so browsing never breaks.
  if (type === "productView" && prodRef) {
    const guardRef = db.collection("engagement_guard")
        .doc(`${request.auth.uid}_${productId}`);
    const guardSnap = await guardRef.get();
    const g = guardSnap.exists ? (guardSnap.data() || {}) : {};
    const nowMs = Date.now();
    const dayCount = g.date === day ? (g.count || 0) : 0;
    if ((g.lastAtMs && nowMs - g.lastAtMs < 20000) || dayCount >= 30) {
      return {ok: true, counted: false};
    }
    writes.push(guardRef.set(
        {date: day, count: dayCount + 1, lastAtMs: nowMs}));
  }

  switch (type) {
    case "profileView":
      writes.push(bizRef.set(
        {profileViews: inc(1), updatedAt: now}, {merge: true}));
      bizDaily({profileViews: inc(1)});
      break;
    case "productView":
      writes.push(bizRef.set(
        {productViews: inc(1), updatedAt: now}, {merge: true}));
      bizDaily({productViews: inc(1)});
      if (prodRef) {
        writes.push(prodRef.set(
          {businessId, views: inc(1), updatedAt: now}, {merge: true}));
        prodDaily({views: inc(1)});
      }
      break;
    case "chatStarted":
      writes.push(bizRef.set(
        {chatsStarted: inc(1), updatedAt: now}, {merge: true}));
      bizDaily({chatsStarted: inc(1)});
      if (prodRef) {
        writes.push(prodRef.set(
          {businessId, chats: inc(1), updatedAt: now}, {merge: true}));
        prodDaily({chats: inc(1)});
      }
      break;
    case "save":
    case "unsave": {
      const d = type === "save" ? 1 : -1;
      writes.push(bizRef.set({saves: inc(d), updatedAt: now}, {merge: true}));
      bizDaily({saves: inc(d)});
      if (prodRef) {
        writes.push(prodRef.set(
          {businessId, saves: inc(d), updatedAt: now}, {merge: true}));
        prodDaily({saves: inc(d)});
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
  // Guard all user-generated upload paths (see storage.rules). Receipts
  // additionally accept PDF; everything else must be a real image.
  const isReceipt = /^receipts\//.test(name);
  if (!isReceipt && !/^(users|businesses|products)\//.test(name)) return;

  const bucket = admin.storage().bucket(obj.bucket);
  const file = bucket.file(name);

  const contentType = obj.contentType || "";
  const typeAllowed = contentType.startsWith("image/") ||
    (isReceipt && contentType === "application/pdf");
  if (!typeAllowed) {
    logger.warn("[upload] bad contentType, deleting", name, contentType);
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

  const headerOk = isRealImage(header) || (isReceipt && isRealPdf(header));
  if (!headerOk) {
    logger.warn("[upload] magic-byte mismatch, deleting", name, contentType);
    await file.delete().catch(() => {});
  }
});

/**
 * True when the leading bytes are a PDF header ("%PDF").
 * @param {Buffer} b First bytes of the object.
 * @return {boolean} Whether the header is a PDF.
 */
function isRealPdf(b) {
  return !!b && b.length >= 4 &&
    b[0] === 0x25 && b[1] === 0x50 && b[2] === 0x44 && b[3] === 0x46;
}

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

/** Public URL of the deployed portal — served by Netlify under the
 *  marketing site (source: abduxla/PetaFinds-Web repo, portal/). */
const PORTAL_URL = "https://petafinds.lk/portal";

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

    // Abuse guard: caps credential emails even from a compromised admin
    // session (each call rotates a password + sends mail).
    await enforceRateLimit(
        `provisionPortalAccess:${request.auth.uid}`, 20, 3600);

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

// ============================================================================
// PORTAL M2 — Payments (manual bank-transfer verification flow)
// ============================================================================

/** Server-owned tier pricing (LKR/month) — the client NEVER supplies an
 *  amount. portalConfig/tiers {prices: {tierId: number}} overrides these
 *  compiled defaults when present. */
const DEFAULT_TIER_PRICES_LKR = {
  spotlight: 5490,
  prime: 9999,
  elite: 24999,
};

const PAYMENT_METHODS = [
  "bank_transfer", "cash_deposit", "online_transfer", "qr",
];

/**
 * Resolve the monthly price for a paid tier, preferring the admin-editable
 * portalConfig/tiers doc over compiled defaults.
 * @param {string} tierId one of spotlight|prime|elite.
 * @return {Promise<number>} monthly price in LKR.
 */
async function tierMonthlyPriceLkr(tierId) {
  try {
    const snap = await db.collection("portalConfig").doc("tiers").get();
    const prices = snap.exists ? (snap.data() || {}).prices : null;
    if (prices && typeof prices[tierId] === "number" && prices[tierId] > 0) {
      return prices[tierId];
    }
  } catch (err) {
    logger.warn("[payments] portalConfig/tiers read failed, using defaults",
        err);
  }
  return DEFAULT_TIER_PRICES_LKR[tierId];
}

/**
 * Deterministic duplicate key for a payment: same reference number +
 * amount + paid-on date can be submitted only once across ALL businesses
 * (catches both accidental double-submits and receipt reuse by another
 * account). Used as the doc id of an atomic lock in /payment_dupes.
 * @param {string} referenceNumber raw user-entered reference.
 * @param {number} amountLkr server-computed amount.
 * @param {string} paidOnYmd normalized YYYY-MM-DD.
 * @return {string} hex lock id.
 */
function paymentDupeKey(referenceNumber, amountLkr, paidOnYmd) {
  const normalized =
    `${referenceNumber.trim().toLowerCase()}|${amountLkr}|${paidOnYmd}`;
  return crypto.createHash("sha256").update(normalized).digest("hex");
}

/** Mint an in-app inbox notification (server-side; bypasses rules). */
async function mintNotification(userId, title, body, type) {
  try {
    await db.collection("notifications").add({
      userId,
      title,
      body,
      type,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("[notify] mint failed for", userId, err);
  }
}

// --------------------------------------------------------------------------
// submitPayment — business-owner callable.
//
// The client supplies WHAT it paid for (tier, months) and the evidence
// (method, reference number, paid-on date, receipt path). The server owns
// the price, the duplicate check, and the status machine:
//   • amount = price(tier) × months — client-sent amounts are ignored;
//   • /payment_dupes/{dupeKey} is create()d in the same transaction as the
//     payment doc, so the same reference+amount+date can never enter the
//     queue twice (txn.create throws ALREADY_EXISTS);
//   • receiptPath must live under the caller's own receipts/ prefix and
//     actually exist in Storage;
//   • status is pinned to pending_verification.
// --------------------------------------------------------------------------
exports.submitPayment = onCall(
  {enforceAppCheck: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const uid = request.auth.uid;
    const data = request.data || {};

    // ---- pure input validation (no reads) ----
    const tierRequested = String(data.tierRequested || "");
    if (!(tierRequested in DEFAULT_TIER_PRICES_LKR)) {
      throw new HttpsError(
          "invalid-argument", "tierRequested must be a paid tier.");
    }
    const months = Number(data.months);
    if (!Number.isInteger(months) || months < 1 || months > 12) {
      throw new HttpsError(
          "invalid-argument", "months must be a whole number from 1 to 12.");
    }
    const method = String(data.method || "");
    if (!PAYMENT_METHODS.includes(method)) {
      throw new HttpsError("invalid-argument", "Unknown payment method.");
    }
    const referenceNumber = String(data.referenceNumber || "").trim();
    if (referenceNumber.length < 3 || referenceNumber.length > 64) {
      throw new HttpsError(
          "invalid-argument",
          "referenceNumber must be 3–64 characters.");
    }
    const paidOnYmd = String(data.paidOn || "");
    if (!/^\d{4}-\d{2}-\d{2}$/.test(paidOnYmd)) {
      throw new HttpsError(
          "invalid-argument", "paidOn must be a YYYY-MM-DD date.");
    }
    const paidOn = new Date(`${paidOnYmd}T00:00:00Z`);
    const now = Date.now();
    if (isNaN(paidOn.getTime()) ||
        paidOn.getTime() > now + 24 * 3600 * 1000 ||
        paidOn.getTime() < now - 366 * 24 * 3600 * 1000) {
      throw new HttpsError(
          "invalid-argument",
          "paidOn must be within the last year and not in the future.");
    }
    const notes = String(data.notes || "").slice(0, 500);
    const receiptPath = String(data.receiptPath || "");

    // Abuse guard AFTER pure validation: malformed junk is rejected for
    // free above; only well-formed requests spend rate-limit budget (and
    // Firestore writes).
    await enforceRateLimit(`submitPayment:${uid}`, 5, 3600);

    // ---- caller must be the owner of a real business ----
    const userSnap = await db.collection("users").doc(uid).get();
    const user = userSnap.exists ? userSnap.data() : null;
    const businessId = user && user.businessId;
    if (!businessId) {
      throw new HttpsError(
          "failed-precondition", "No business linked to this account.");
    }
    const bizSnap = await db.collection("businesses").doc(businessId).get();
    if (!bizSnap.exists || (bizSnap.data() || {}).ownerUid !== uid) {
      throw new HttpsError(
          "permission-denied", "You do not own this business.");
    }

    // ---- receipt must be the caller's own uploaded evidence ----
    if (!receiptPath.startsWith(`receipts/${businessId}/`) ||
        receiptPath.includes("..")) {
      throw new HttpsError(
          "invalid-argument",
          "receiptPath must be under your receipts folder.");
    }
    const [receiptExists] =
      await admin.storage().bucket().file(receiptPath).exists();
    if (!receiptExists) {
      throw new HttpsError(
          "failed-precondition",
          "Receipt upload not found — upload the receipt first.");
    }

    // ---- server-owned amount ----
    const unitPrice = await tierMonthlyPriceLkr(tierRequested);
    const amountLkr = unitPrice * months;

    // ---- atomic create: payment + duplicate lock ----
    const dupeKey = paymentDupeKey(referenceNumber, amountLkr, paidOnYmd);
    const dupeRef = db.collection("payment_dupes").doc(dupeKey);
    const paymentRef = db.collection("payments").doc();
    try {
      await db.runTransaction(async (txn) => {
        txn.create(dupeRef, {
          paymentId: paymentRef.id,
          businessId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        txn.create(paymentRef, {
          businessId,
          submittedByUid: uid,
          tierRequested,
          months,
          amountLkr,
          method,
          referenceNumber,
          paidOn: admin.firestore.Timestamp.fromDate(paidOn),
          receiptPath,
          notes,
          status: "pending_verification",
          dupeKey,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (err) {
      if (err && err.code === 6) { // ALREADY_EXISTS
        throw new HttpsError(
            "already-exists",
            "A payment with this reference number, amount and date has " +
            "already been submitted.");
      }
      logger.error("[payments] submit txn failed", err);
      throw new HttpsError("internal", "Could not record the payment.");
    }

    await writeAudit({
      action: "payment_submitted",
      actorUid: uid,
      targetType: "payment",
      targetId: paymentRef.id,
      details: {businessId, tierRequested, months, amountLkr, method},
    });

    return {ok: true, paymentId: paymentRef.id, amountLkr};
  },
);

// --------------------------------------------------------------------------
// reviewPayment — admin callable. decision: approve | reject | resubmit.
//
// Runs in a transaction keyed on the payment still being
// pending_verification, so two admins can never double-approve (the
// second transaction sees the flipped status and aborts). Firestore
// transactions require ALL reads before ANY write, so the payment,
// business and invoice counter are read up front.
//
// Approval — atomically, in one transaction:
//   • business tier is set and tierValidUntil extends from
//     max(now, current expiry) by the paid months (early renewals stack);
//   • a sequential invoice (INV-YYYY-NNNN, counter in /counters/invoices)
//     is created with status "paid";
//   • the payment doc records the decision + invoice linkage.
// Reject/resubmit releases the duplicate lock so the merchant can
// resubmit corrected details.
// --------------------------------------------------------------------------

/** Commercial tier names for merchant-facing copy (portal display map). */
const TIER_DISPLAY = {spotlight: "Gold", prime: "Platinum", elite: "Vibranium"};

exports.reviewPayment = onCall(
  {enforceAppCheck: true, secrets: [RESEND_API_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    if (!(await callerIsAdmin(request.auth))) {
      throw new HttpsError("permission-denied", "Administrators only.");
    }

    const paymentId = String((request.data || {}).paymentId || "");
    const decision = String((request.data || {}).decision || "");
    const note = String((request.data || {}).note || "").slice(0, 500);
    if (!paymentId) {
      throw new HttpsError("invalid-argument", "paymentId is required.");
    }
    if (!["approve", "reject", "resubmit"].includes(decision)) {
      throw new HttpsError(
          "invalid-argument",
          "decision must be approve, reject or resubmit.");
    }

    const paymentRef = db.collection("payments").doc(paymentId);
    const counterRef = db.collection("counters").doc("invoices");
    let outcome;
    try {
      outcome = await db.runTransaction(async (txn) => {
        // ---- reads (all before any write) ----
        const paySnap = await txn.get(paymentRef);
        if (!paySnap.exists) {
          throw new HttpsError("not-found", "Payment not found.");
        }
        const pay = paySnap.data();
        if (pay.status !== "pending_verification") {
          throw new HttpsError(
              "failed-precondition",
              `This payment was already ${pay.status.replace(/_/g, " ")}.`);
        }
        const bizRef = db.collection("businesses").doc(pay.businessId);
        const bizSnap = await txn.get(bizRef);
        const biz = bizSnap.exists ? (bizSnap.data() || {}) : null;
        let counterSnap = null;
        if (decision === "approve") {
          if (!biz) {
            throw new HttpsError(
                "failed-precondition", "The business no longer exists.");
          }
          counterSnap = await txn.get(counterRef);
        }

        const stamp = {
          reviewedBy: request.auth.uid,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewNote: note,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // ---- writes ----
        if (decision === "approve") {
          // Extend from whichever is later: today, or the current expiry.
          const current = biz.tierValidUntil &&
            typeof biz.tierValidUntil.toDate === "function" ?
            biz.tierValidUntil.toDate() : null;
          const base = current && current.getTime() > Date.now() ?
            current : new Date();
          const validUntil = new Date(base.getTime());
          validUntil.setMonth(validUntil.getMonth() + pay.months);

          // Sequential, year-scoped invoice number.
          const year = new Date().getFullYear();
          const counter = counterSnap.exists ? (counterSnap.data() || {}) : {};
          const seq = (counter.year === year ? (counter.seq || 0) : 0) + 1;
          const invoiceNumber = `INV-${year}-${String(seq).padStart(4, "0")}`;
          const invoiceRef = db.collection("invoices").doc();

          txn.set(counterRef, {year, seq}, {merge: true});
          txn.update(bizRef, {
            tier: pay.tierRequested,
            tierValidUntil: admin.firestore.Timestamp.fromDate(validUntil),
          });
          txn.update(paymentRef, {
            ...stamp,
            status: "approved",
            invoiceId: invoiceRef.id,
            invoiceNumber,
          });
          txn.create(invoiceRef, {
            invoiceNumber,
            businessId: pay.businessId,
            businessName: biz.businessName || "",
            paymentId,
            tier: pay.tierRequested,
            months: pay.months,
            amountLkr: pay.amountLkr,
            method: pay.method,
            referenceNumber: pay.referenceNumber,
            periodStart: admin.firestore.Timestamp.fromDate(base),
            periodEnd: admin.firestore.Timestamp.fromDate(validUntil),
            status: "paid",
            issuedAt: admin.firestore.FieldValue.serverTimestamp(),
            issuedBy: request.auth.uid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return {
            status: "approved",
            ownerUid: biz.ownerUid,
            businessId: pay.businessId,
            businessName: biz.businessName || "",
            businessEmail: (biz.email || "").trim().toLowerCase() || null,
            tier: pay.tierRequested,
            months: pay.months,
            amountLkr: pay.amountLkr,
            validUntil,
            periodStart: base,
            invoiceId: invoiceRef.id,
            invoiceNumber,
          };
        }

        // reject / resubmit — free the duplicate lock for a retry.
        const newStatus = decision === "reject" ?
          "rejected" : "resubmission_requested";
        txn.update(paymentRef, {...stamp, status: newStatus});
        if (pay.dupeKey) {
          txn.delete(db.collection("payment_dupes").doc(pay.dupeKey));
        }
        return {
          status: newStatus,
          ownerUid: biz ? biz.ownerUid : null,
          businessId: pay.businessId,
          tier: pay.tierRequested,
          months: pay.months,
        };
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[payments] review txn failed", paymentId, err);
      throw new HttpsError("internal", "Could not update the payment.");
    }

    // ---- post-transaction side effects (best-effort) ----
    const tierLabel = TIER_DISPLAY[outcome.tier] || outcome.tier;
    if (outcome.ownerUid) {
      if (outcome.status === "approved") {
        await mintNotification(
            outcome.ownerUid,
            "Payment approved 🎉",
            `Your ${tierLabel} membership is active until ` +
            `${outcome.validUntil.toISOString().slice(0, 10)}. ` +
            `Invoice ${outcome.invoiceNumber} is in your Invoice Centre.`,
            "payment");
      } else if (outcome.status === "rejected") {
        await mintNotification(
            outcome.ownerUid,
            "Payment could not be verified",
            note || "Contact support for details.",
            "payment");
      } else {
        await mintNotification(
            outcome.ownerUid,
            "Payment needs resubmission",
            note || "Please re-check the details and submit again.",
            "payment");
      }
    }

    // Invoice email on approval.
    if (outcome.status === "approved" && outcome.businessEmail) {
      try {
        const resend = new Resend(RESEND_API_KEY.value());
        await resend.emails.send({
          from: "PetaFinds <info@petafinds.lk>",
          to: outcome.businessEmail,
          subject:
            `Invoice ${outcome.invoiceNumber} — ${tierLabel} membership ` +
            "activated",
          html: _invoiceEmailHtml({
            invoiceNumber: escapeHtml(outcome.invoiceNumber),
            businessName: escapeHtml(outcome.businessName),
            tierLabel: escapeHtml(tierLabel),
            months: outcome.months,
            amountLkr: outcome.amountLkr,
            periodStart: outcome.periodStart.toISOString().slice(0, 10),
            periodEnd: outcome.validUntil.toISOString().slice(0, 10),
          }),
        });
      } catch (err) {
        logger.error("[invoices] email failed for",
            outcome.businessEmail, err);
      }
    }

    await writeAudit({
      action: `payment_${outcome.status}`,
      actorUid: request.auth.uid,
      targetType: "payment",
      targetId: paymentId,
      details: {
        businessId: outcome.businessId,
        tier: outcome.tier,
        months: outcome.months,
        note,
        ...(outcome.invoiceNumber ? {invoice: outcome.invoiceNumber} : {}),
      },
    });

    return {
      ok: true,
      status: outcome.status,
      ...(outcome.invoiceNumber ? {invoiceNumber: outcome.invoiceNumber} : {}),
    };
  },
);

// --------------------------------------------------------------------------
// manageInvoice — invoice lifecycle callable.
//   action: "email"    → re-send the invoice email (admin or owning business)
//   action: "void"     → mark void (admin only; note recommended)
//   action: "markPaid" → restore a voided invoice to paid (admin only)
// Invoices are otherwise immutable — rules deny every client write.
// --------------------------------------------------------------------------
exports.manageInvoice = onCall(
  {enforceAppCheck: true, secrets: [RESEND_API_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const invoiceId = String((request.data || {}).invoiceId || "");
    const action = String((request.data || {}).action || "");
    const note = String((request.data || {}).note || "").slice(0, 300);
    if (!invoiceId) {
      throw new HttpsError("invalid-argument", "invoiceId is required.");
    }
    if (!["email", "void", "markPaid"].includes(action)) {
      throw new HttpsError(
          "invalid-argument", "action must be email, void or markPaid.");
    }

    const invoiceRef = db.collection("invoices").doc(invoiceId);
    const invSnap = await invoiceRef.get();
    if (!invSnap.exists) {
      throw new HttpsError("not-found", "Invoice not found.");
    }
    const inv = invSnap.data() || {};

    // AuthZ: admins may do anything; the owning business may only re-email.
    const isAdminCaller = await callerIsAdmin(request.auth);
    if (!isAdminCaller) {
      if (action !== "email") {
        throw new HttpsError("permission-denied", "Administrators only.");
      }
      const userSnap =
        await db.collection("users").doc(request.auth.uid).get();
      const businessId = userSnap.exists ?
        (userSnap.data() || {}).businessId : null;
      if (!businessId || businessId !== inv.businessId) {
        throw new HttpsError(
            "permission-denied", "This is not your invoice.");
      }
    }

    if (action === "void" || action === "markPaid") {
      const newStatus = action === "void" ? "void" : "paid";
      if (inv.status === newStatus) {
        throw new HttpsError(
            "failed-precondition", `Invoice is already ${newStatus}.`);
      }
      await invoiceRef.update({
        status: newStatus,
        statusNote: note,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await writeAudit({
        action: `invoice_${newStatus === "void" ? "voided" : "restored"}`,
        actorUid: request.auth.uid,
        targetType: "invoice",
        targetId: invoiceId,
        details: {invoiceNumber: inv.invoiceNumber, note},
      });
      return {ok: true, status: newStatus};
    }

    // action === "email"
    // Abuse guard: stops the re-send button being used as an email cannon.
    await enforceRateLimit(`invoiceEmail:${request.auth.uid}`, 10, 3600);
    const bizSnap =
      await db.collection("businesses").doc(inv.businessId).get();
    const email = bizSnap.exists ?
      String((bizSnap.data() || {}).email || "").trim().toLowerCase() : "";
    if (!email) {
      throw new HttpsError(
          "failed-precondition",
          "The business has no email address on file.");
    }
    const tierLabel = TIER_DISPLAY[inv.tier] || inv.tier;
    const resend = new Resend(RESEND_API_KEY.value());
    try {
      await resend.emails.send({
        from: "PetaFinds <info@petafinds.lk>",
        to: email,
        subject: `Invoice ${inv.invoiceNumber} — PetaFinds membership`,
        html: _invoiceEmailHtml({
          invoiceNumber: escapeHtml(inv.invoiceNumber || ""),
          businessName: escapeHtml(inv.businessName || ""),
          tierLabel: escapeHtml(tierLabel),
          months: inv.months || 1,
          amountLkr: inv.amountLkr || 0,
          periodStart: inv.periodStart &&
            typeof inv.periodStart.toDate === "function" ?
            inv.periodStart.toDate().toISOString().slice(0, 10) : "",
          periodEnd: inv.periodEnd &&
            typeof inv.periodEnd.toDate === "function" ?
            inv.periodEnd.toDate().toISOString().slice(0, 10) : "",
        }),
      });
    } catch (err) {
      logger.error("[invoices] re-email failed for", email, err);
      throw new HttpsError("internal", "Email failed to send — try again.");
    }
    await writeAudit({
      action: "invoice_emailed",
      actorUid: request.auth.uid,
      targetType: "invoice",
      targetId: invoiceId,
      details: {invoiceNumber: inv.invoiceNumber, to: email},
    });
    return {ok: true, status: "emailed"};
  },
);

/**
 * Invoice email — house template style.
 * @param {object} v Pre-escaped display values.
 * @return {string} HTML body.
 */
function _invoiceEmailHtml(v) {
  const amount = `LKR ${Number(v.amountLkr).toLocaleString("en-LK")}`;
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
          Invoice ${v.invoiceNumber}
        </h2>
        <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 20px;">
          Thank you, <strong>${v.businessName}</strong> — your payment has
          been received and your membership is active.
        </p>
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px;
          background: #fff; border: 1px solid #E8E8E8; border-radius: 8px;">
          <tr>
            <td style="padding: 12px 16px; font-size: 14px; color: #555;
              border-bottom: 1px solid #EFEFEF;">
              ${v.tierLabel} membership × ${v.months} month${v.months > 1 ? "s" : ""}
            </td>
            <td style="padding: 12px 16px; font-size: 14px; font-weight: 700;
              text-align: right; border-bottom: 1px solid #EFEFEF;">
              ${amount}
            </td>
          </tr>
          <tr>
            <td style="padding: 12px 16px; font-size: 13px; color: #777;">
              Coverage period
            </td>
            <td style="padding: 12px 16px; font-size: 13px; color: #777;
              text-align: right;">
              ${v.periodStart} → ${v.periodEnd}
            </td>
          </tr>
          <tr>
            <td style="padding: 12px 16px; font-size: 14px; font-weight: 800;
              background: #E8F4F4; color: #095858;">
              Total paid
            </td>
            <td style="padding: 12px 16px; font-size: 16px; font-weight: 800;
              text-align: right; background: #E8F4F4; color: #095858;">
              ${amount}
            </td>
          </tr>
        </table>
        <p style="text-align: center; margin: 0 0 24px;">
          <a href="${PORTAL_URL}/invoices/"
            style="display: inline-block; background: #095858; color: #fff;
            text-decoration: none; font-weight: 700; font-size: 15px;
            padding: 12px 28px; border-radius: 10px;">
            View in the Invoice Centre
          </a>
        </p>
        <p style="margin-top: 32px; font-size: 12px; color: #9E9E9E;">
          Keep this email for your records. Questions? support@petafinds.lk
          <br>PetaFinds · Bringing Pettah online · Colombo 11
        </p>
      </div>
    </div>
  `;
}

// ============================================================================
// PORTAL M4 — Upgrades, renewals (7-day warning, 7-day grace) + hardening
// ============================================================================

/** Grace window after tierValidUntil before the hard downgrade to free. */
const GRACE_DAYS = 7;
/** How far ahead the sweep warns about an upcoming expiry. */
const REMINDER_DAYS = 7;

/**
 * Sliding-window rate limiter backed by /rateLimits (no client access).
 * Throws resource-exhausted when the caller exceeds `max` actions per
 * `windowSeconds`. Fails OPEN on infrastructure errors (logged) — a
 * limiter outage must not take the product down; the callables' auth and
 * validation guards still stand on their own.
 * @param {string} key e.g. "submitPayment:<uid>"
 * @param {number} max allowed actions inside the window.
 * @param {number} windowSeconds window length.
 */
async function enforceRateLimit(key, max, windowSeconds) {
  const ref = db.collection("rateLimits").doc(key);
  const now = Date.now();
  const windowStart = now - windowSeconds * 1000;
  try {
    await db.runTransaction(async (txn) => {
      const snap = await txn.get(ref);
      const prev = snap.exists && Array.isArray(snap.data().stamps) ?
        snap.data().stamps : [];
      const stamps = prev.filter((t) => typeof t === "number" &&
        t > windowStart);
      if (stamps.length >= max) {
        throw new HttpsError(
            "resource-exhausted",
            "Too many requests — please wait a while and try again.");
      }
      stamps.push(now);
      txn.set(ref, {
        stamps,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    logger.warn("[ratelimit] degraded (failing open)", key, err);
  }
}

// --------------------------------------------------------------------------
// requestUpgrade — business-owner callable.
//
// One OPEN request per business, enforced atomically: the request doc id
// IS the businessId, and the transaction refuses to replace a doc that is
// still pending. Approval does not change the tier — money does: an
// approved request tells the merchant to submit payment, and the existing
// payment-verification flow activates the membership.
// --------------------------------------------------------------------------
exports.requestUpgrade = onCall(
  {enforceAppCheck: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const uid = request.auth.uid;

    const targetTier = String((request.data || {}).targetTier || "");
    if (!(targetTier in DEFAULT_TIER_PRICES_LKR)) {
      throw new HttpsError(
          "invalid-argument", "targetTier must be a paid tier.");
    }
    const notes = String((request.data || {}).notes || "").slice(0, 300);

    await enforceRateLimit(`requestUpgrade:${uid}`, 3, 3600);

    // Caller must own a real business.
    const userSnap = await db.collection("users").doc(uid).get();
    const businessId = userSnap.exists ?
      (userSnap.data() || {}).businessId : null;
    if (!businessId) {
      throw new HttpsError(
          "failed-precondition", "No business linked to this account.");
    }
    const bizSnap = await db.collection("businesses").doc(businessId).get();
    if (!bizSnap.exists || (bizSnap.data() || {}).ownerUid !== uid) {
      throw new HttpsError(
          "permission-denied", "You do not own this business.");
    }
    const biz = bizSnap.data();
    const currentTier = biz.tier || "listed";
    if (currentTier === targetTier) {
      throw new HttpsError(
          "failed-precondition", "You are already on this plan.");
    }

    const reqRef = db.collection("upgradeRequests").doc(businessId);
    try {
      await db.runTransaction(async (txn) => {
        const existing = await txn.get(reqRef);
        if (existing.exists &&
            (existing.data() || {}).status === "pending") {
          throw new HttpsError(
              "already-exists",
              "You already have an upgrade request awaiting review.");
        }
        txn.set(reqRef, {
          businessId,
          businessName: biz.businessName || "",
          requestedByUid: uid,
          currentTier,
          targetTier,
          currentMonthlyLkr: DEFAULT_TIER_PRICES_LKR[currentTier] || 0,
          targetMonthlyLkr: DEFAULT_TIER_PRICES_LKR[targetTier],
          notes,
          status: "pending",
          decidedBy: null,
          decidedAt: null,
          decisionNote: "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[upgrade] request txn failed", businessId, err);
      throw new HttpsError("internal", "Could not submit the request.");
    }

    await writeAudit({
      action: "upgrade_requested",
      actorUid: uid,
      targetType: "business",
      targetId: businessId,
      details: {currentTier, targetTier},
    });
    return {ok: true};
  },
);

// --------------------------------------------------------------------------
// decideUpgrade — admin callable. decision: approve | decline.
// --------------------------------------------------------------------------
exports.decideUpgrade = onCall(
  {enforceAppCheck: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const businessId = String((request.data || {}).businessId || "");
    const decision = String((request.data || {}).decision || "");
    const note = String((request.data || {}).note || "").slice(0, 300);
    if (!businessId) {
      throw new HttpsError("invalid-argument", "businessId is required.");
    }
    if (!["approve", "decline"].includes(decision)) {
      throw new HttpsError(
          "invalid-argument", "decision must be approve or decline.");
    }
    if (!(await callerIsAdmin(request.auth))) {
      throw new HttpsError("permission-denied", "Administrators only.");
    }

    const reqRef = db.collection("upgradeRequests").doc(businessId);
    let outcome;
    try {
      outcome = await db.runTransaction(async (txn) => {
        const snap = await txn.get(reqRef);
        if (!snap.exists) {
          throw new HttpsError("not-found", "Upgrade request not found.");
        }
        const r = snap.data();
        if (r.status !== "pending") {
          throw new HttpsError(
              "failed-precondition", `Request was already ${r.status}.`);
        }
        const status = decision === "approve" ? "approved" : "declined";
        txn.update(reqRef, {
          status,
          decidedBy: request.auth.uid,
          decidedAt: admin.firestore.FieldValue.serverTimestamp(),
          decisionNote: note,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {status, requestedByUid: r.requestedByUid,
          targetTier: r.targetTier};
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[upgrade] decide txn failed", businessId, err);
      throw new HttpsError("internal", "Could not update the request.");
    }

    const tierLabel = TIER_DISPLAY[outcome.targetTier] || outcome.targetTier;
    if (outcome.requestedByUid) {
      await mintNotification(
          outcome.requestedByUid,
          outcome.status === "approved" ?
            `Upgrade to ${tierLabel} approved` :
            `Upgrade request declined`,
          outcome.status === "approved" ?
            "Head to Payments and submit your payment — your new plan " +
            "activates as soon as it's verified." :
            (note || "Contact support for details."),
          "membership");
    }
    await writeAudit({
      action: `upgrade_${outcome.status}`,
      actorUid: request.auth.uid,
      targetType: "business",
      targetId: businessId,
      details: {targetTier: outcome.targetTier, note},
    });
    return {ok: true, status: outcome.status};
  },
);

// --------------------------------------------------------------------------
// dailyMembershipSweep — scheduled (03:00 Asia/Colombo, daily).
//
// One pass over every business whose tierValidUntil is within the horizon:
//   • expires in ≤7 days  → ONE renewal warning (in-app + email);
//   • past expiry, in the 7-day grace window → ONE grace notice;
//   • grace exhausted → hard server-side downgrade to the free tier
//     (tier field cleared — until now expiry was only computed
//     client-side; this makes it authoritative), notice + audit.
// Idempotent: notices are stamped on the business doc keyed by the exact
// expiry timestamp (renewalReminderFor / graceNotifiedFor), so scheduler
// retries and overlapping runs can never double-send.
// --------------------------------------------------------------------------
exports.dailyMembershipSweep = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "Asia/Colombo",
    secrets: [RESEND_API_KEY],
  },
  async () => {
    const now = new Date();
    const horizon = new Date(
        now.getTime() + REMINDER_DAYS * 86400000);
    const graceCut = new Date(now.getTime() - GRACE_DAYS * 86400000);

    const snap = await db.collection("businesses")
        .where("tierValidUntil", "<=",
            admin.firestore.Timestamp.fromDate(horizon))
        .get();
    logger.info("[sweep] candidates:", snap.size);

    const resend = new Resend(RESEND_API_KEY.value());
    for (const docSnap of snap.docs) {
      const b = docSnap.data() || {};
      if (!b.tierValidUntil || !b.tier || b.tier === "listed") continue;
      const vu = b.tierValidUntil.toDate();
      const vuKey = vu.getTime();
      const tierLabel = TIER_DISPLAY[b.tier] || b.tier;
      const email = String(b.email || "").trim().toLowerCase();
      const dateStr = vu.toISOString().slice(0, 10);

      try {
        if (vu > now) {
          // ---- expiring within 7 days: one warning per expiry date ----
          if (b.renewalReminderFor === vuKey) continue;
          await docSnap.ref.update({renewalReminderFor: vuKey});
          if (b.ownerUid) {
            await mintNotification(
                b.ownerUid,
                `Your ${tierLabel} membership expires soon`,
                `It ends on ${dateStr}. Renew in the Business Portal to ` +
                "keep your benefits without interruption.",
                "membership");
          }
          if (email) {
            await resend.emails.send({
              from: "PetaFinds <info@petafinds.lk>",
              to: email,
              subject:
                `Your ${tierLabel} membership expires on ${dateStr}`,
              html: _membershipNoticeHtml(
                  escapeHtml(b.businessName || "your business"),
                  `Your <strong>${escapeHtml(tierLabel)}</strong> ` +
                  `membership ends on <strong>${dateStr}</strong>.`,
                  "Renew now to keep your visibility, product slots and " +
                  "benefits without interruption.",
                  "Renew membership"),
            });
          }
        } else if (vu > graceCut) {
          // ---- inside the 7-day grace window: one notice ----
          if (b.graceNotifiedFor === vuKey) continue;
          await docSnap.ref.update({graceNotifiedFor: vuKey});
          if (b.ownerUid) {
            await mintNotification(
                b.ownerUid,
                `Your ${tierLabel} membership has expired`,
                `You have ${GRACE_DAYS} days to renew before your account ` +
                "moves to the free plan.",
                "membership");
          }
          if (email) {
            await resend.emails.send({
              from: "PetaFinds <info@petafinds.lk>",
              to: email,
              subject:
                `Action needed — your ${tierLabel} membership has expired`,
              html: _membershipNoticeHtml(
                  escapeHtml(b.businessName || "your business"),
                  `Your <strong>${escapeHtml(tierLabel)}</strong> ` +
                  `membership expired on <strong>${dateStr}</strong>.`,
                  `Renew within ${GRACE_DAYS} days to restore your plan — ` +
                  "after that your account moves to the free Silver plan.",
                  "Renew now"),
            });
          }
        } else {
          // ---- grace exhausted: authoritative downgrade ----
          await docSnap.ref.update({
            tier: "listed",
            tierValidUntil: admin.firestore.FieldValue.delete(),
            downgradedAt: admin.firestore.FieldValue.serverTimestamp(),
            downgradedFrom: b.tier,
          });
          if (b.ownerUid) {
            await mintNotification(
                b.ownerUid,
                "Your membership has ended",
                `The ${GRACE_DAYS}-day grace period is over and your ` +
                "account is now on the free Silver plan. You can upgrade " +
                "again anytime from the Business Portal.",
                "membership");
          }
          await writeAudit({
            action: "membership_downgraded",
            actorUid: "system:dailyMembershipSweep",
            targetType: "business",
            targetId: docSnap.id,
            details: {from: b.tier, expiredOn: dateStr},
          });
        }
      } catch (err) {
        // Never let one business abort the sweep for everyone else.
        logger.error("[sweep] failed for", docSnap.id, err);
      }
    }
  },
);

/**
 * Membership notice email — house template style.
 * @param {string} businessName escaped.
 * @param {string} headlineHtml escaped-and-marked-up first line.
 * @param {string} bodyText escaped body line.
 * @param {string} cta button label.
 * @return {string} HTML body.
 */
function _membershipNoticeHtml(businessName, headlineHtml, bodyText, cta) {
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
          Membership renewal
        </h2>
        <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 12px;">
          Hi <strong>${businessName}</strong> — ${headlineHtml}
        </p>
        <div style="background: #FFF8F0; border-left: 4px solid #E8821A;
          padding: 16px 20px; border-radius: 8px; margin-bottom: 24px;">
          <p style="margin: 0; font-size: 14px; color: #7A4A00;">
            ${bodyText}
          </p>
        </div>
        <p style="text-align: center; margin: 0 0 24px;">
          <a href="${PORTAL_URL}/payments/"
            style="display: inline-block; background: #095858; color: #fff;
            text-decoration: none; font-weight: 700; font-size: 15px;
            padding: 12px 28px; border-radius: 10px;">
            ${cta}
          </a>
        </p>
        <p style="margin-top: 32px; font-size: 12px; color: #9E9E9E;">
          Questions? support@petafinds.lk
          <br>PetaFinds · Bringing Pettah online · Colombo 11
        </p>
      </div>
    </div>
  `;
}

// --------------------------------------------------------------------------
// broadcastNotification — admin callable (portal M5).
//
// Mints in-app inbox notifications (and best-effort FCM pushes) for:
//   audience: "single"  → one business (businessId required)
//   audience: "tier"    → every business on a stored tier id
//   audience: "all"     → every business with an owner
// Content is length-capped, recipients are deduped by owner uid, writes go
// in batched commits, and the whole action is rate-limited + audited.
// --------------------------------------------------------------------------
exports.broadcastNotification = onCall(
  {enforceAppCheck: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    if (!(await callerIsAdmin(request.auth))) {
      throw new HttpsError("permission-denied", "Administrators only.");
    }

    const data = request.data || {};
    const audience = String(data.audience || "");
    const tierId = String(data.tierId || "");
    const businessId = String(data.businessId || "").trim();
    const title = String(data.title || "").trim();
    const body = String(data.body || "").trim();

    if (!["single", "tier", "all"].includes(audience)) {
      throw new HttpsError(
          "invalid-argument", "audience must be single, tier or all.");
    }
    if (title.length < 3 || title.length > 120) {
      throw new HttpsError(
          "invalid-argument", "title must be 3–120 characters.");
    }
    if (body.length < 3 || body.length > 500) {
      throw new HttpsError(
          "invalid-argument", "body must be 3–500 characters.");
    }
    if (audience === "single" && !businessId) {
      throw new HttpsError(
          "invalid-argument", "businessId is required for a single send.");
    }
    if (audience === "tier" &&
        !["listed", "spotlight", "prime", "elite"].includes(tierId)) {
      throw new HttpsError(
          "invalid-argument", "tierId must be a valid stored tier id.");
    }

    // 10 broadcasts/hour per admin — a compromised session can't spam
    // every merchant inbox.
    await enforceRateLimit(`broadcast:${request.auth.uid}`, 10, 3600);

    // Resolve recipient owner uids.
    let ownerUids = [];
    if (audience === "single") {
      const snap = await db.collection("businesses").doc(businessId).get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }
      const uid = (snap.data() || {}).ownerUid;
      if (uid) ownerUids = [uid];
    } else {
      let q = db.collection("businesses");
      if (audience === "tier") q = q.where("tier", "==", tierId);
      const snap = await q.select("ownerUid").get();
      ownerUids = [...new Set(
          snap.docs.map((d) => (d.data() || {}).ownerUid).filter(Boolean),
      )];
    }
    if (ownerUids.length === 0) {
      throw new HttpsError(
          "failed-precondition", "No recipients match this audience.");
    }

    // Inbox docs in batched commits (500 writes per batch).
    let batch = db.batch();
    let inBatch = 0;
    for (const uid of ownerUids) {
      batch.set(db.collection("notifications").doc(), {
        userId: uid,
        title,
        body,
        type: "announcement",
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      inBatch++;
      if (inBatch === 450) {
        await batch.commit();
        batch = db.batch();
        inBatch = 0;
      }
    }
    if (inBatch > 0) await batch.commit();

    // Best-effort push to devices (sequential; fine at directory scale).
    for (const uid of ownerUids) {
      const token = await getUserToken(uid);
      await sendPush(uid, token, title, truncate(body, 120),
          {type: "announcement", id: ""});
    }

    await writeAudit({
      action: "notification_broadcast",
      actorUid: request.auth.uid,
      targetType: "audience",
      targetId: audience === "single" ? businessId :
        audience === "tier" ? `tier:${tierId}` : "all-businesses",
      details: {recipients: ownerUids.length, title},
    });

    return {ok: true, recipients: ownerUids.length};
  },
);

// --------------------------------------------------------------------------
// monthlyBusinessReport — scheduled: 06:00 on the 1st, Asia/Colombo.
//
// The "Monthly Business Report" every paid tier is promised (Gold's main
// analytics surface; Platinum/Vibranium get it on top of the live
// dashboard). For each paid business:
//   • reads lifetime counters from business_stats,
//   • subtracts the snapshot taken at the previous report to get THIS
//     month's numbers (first report = activity to date),
//   • pulls the top 3 products by views from product_stats,
//   • emails a branded summary to the business email,
//   • stores the new snapshot with the month stamp (idempotent — a retry
//     in the same month is a no-op per business).
// --------------------------------------------------------------------------
exports.monthlyBusinessReport = onSchedule(
  {
    schedule: "0 6 1 * *",
    timeZone: "Asia/Colombo",
    secrets: [RESEND_API_KEY],
  },
  async () => {
    const month = new Date().toISOString().slice(0, 7); // YYYY-MM
    const prevMonthName = new Date(Date.now() - 5 * 86400000)
        .toLocaleString("en-US", {month: "long", year: "numeric"});
    const resend = new Resend(RESEND_API_KEY.value());

    const paid = await db.collection("businesses")
        .where("tier", "in", ["spotlight", "prime", "elite"])
        .get();
    logger.info("[report] monthly run", month, "candidates:", paid.size);

    let sent = 0;
    for (const bizSnap of paid.docs) {
      try {
        const biz = bizSnap.data() || {};
        const email = String(biz.email || "").trim().toLowerCase();
        if (!email) continue;

        const snapRef =
          db.collection("reportSnapshots").doc(bizSnap.id);
        const prevSnap = await snapRef.get();
        const prev = prevSnap.exists ? (prevSnap.data() || {}) : {};
        if (prev.lastSentMonth === month) continue; // idempotency

        const statsSnap =
          await db.collection("business_stats").doc(bizSnap.id).get();
        const s = statsSnap.exists ? (statsSnap.data() || {}) : {};
        const cur = {
          profileViews: s.profileViews || 0,
          productViews: s.productViews || 0,
          chatsStarted: s.chatsStarted || 0,
          saves: s.saves || 0,
        };
        const delta = {
          profileViews: Math.max(0, cur.profileViews -
            (prev.profileViews || 0)),
          productViews: Math.max(0, cur.productViews -
            (prev.productViews || 0)),
          chatsStarted: Math.max(0, cur.chatsStarted -
            (prev.chatsStarted || 0)),
          saves: Math.max(0, cur.saves - (prev.saves || 0)),
        };

        // Top products by lifetime views (titles joined from /products).
        const topStats = await db.collection("product_stats")
            .where("businessId", "==", bizSnap.id)
            .orderBy("views", "desc")
            .limit(3)
            .get();
        const topProducts = [];
        for (const t of topStats.docs) {
          const p = await db.collection("products").doc(t.id).get();
          if (p.exists) {
            topProducts.push({
              title: (p.data() || {}).title || "Product",
              views: (t.data() || {}).views || 0,
              chats: (t.data() || {}).chats || 0,
            });
          }
        }

        await resend.emails.send({
          from: "PetaFinds <info@petafinds.lk>",
          to: email,
          subject:
            `Your ${prevMonthName} business report — ` +
            `${biz.businessName || "your shop"}`,
          html: _monthlyReportHtml({
            businessName: escapeHtml(biz.businessName || "Your shop"),
            monthName: escapeHtml(prevMonthName),
            firstReport: !prevSnap.exists,
            delta,
            topProducts: topProducts.map((p) => ({
              title: escapeHtml(p.title),
              views: p.views,
              chats: p.chats,
            })),
          }),
        });

        await snapRef.set({
          ...cur,
          lastSentMonth: month,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        sent++;
      } catch (err) {
        logger.error("[report] failed for", bizSnap.id, err);
      }
    }
    logger.info("[report] monthly reports sent:", sent);
  },
);

/**
 * Monthly report email — house template style.
 * @param {object} v Pre-escaped display values.
 * @return {string} HTML body.
 */
function _monthlyReportHtml(v) {
  const tile = (label, value) => `
    <td style="width: 25%; padding: 14px 6px; text-align: center;
      background: #fff; border: 1px solid #EFEFEF;">
      <div style="font-size: 22px; font-weight: 800; color: #095858;">
        ${value}
      </div>
      <div style="font-size: 11px; color: #777; margin-top: 2px;">
        ${label}
      </div>
    </td>`;
  const productRows = v.topProducts.length === 0 ? "" : `
    <h3 style="font-size: 15px; margin: 24px 0 10px;">Top products</h3>
    <table style="width: 100%; border-collapse: collapse; background: #fff;
      border: 1px solid #E8E8E8; border-radius: 8px;">
      ${v.topProducts.map((p) => `
        <tr>
          <td style="padding: 10px 14px; font-size: 13px; font-weight: 600;
            border-bottom: 1px solid #EFEFEF;">${p.title}</td>
          <td style="padding: 10px 14px; font-size: 13px; color: #777;
            text-align: right; border-bottom: 1px solid #EFEFEF;
            white-space: nowrap;">
            ${p.views} views · ${p.chats} chats
          </td>
        </tr>`).join("")}
    </table>`;
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 540px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 28px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 22px; font-weight: 800;">
          📈 ${v.monthName} report
        </h1>
        <p style="color: #A8D5D5; margin: 6px 0 0; font-size: 14px;">
          ${v.businessName}
        </p>
      </div>
      <div style="padding: 28px 24px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8; border-top: none;">
        ${v.firstReport ? `
        <p style="font-size: 13px; color: #777; margin: 0 0 16px;">
          This is your first report, so it covers all activity to date.
          From next month it shows that month only.
        </p>` : ""}
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            ${tile("Profile views", v.delta.profileViews)}
            ${tile("Product views", v.delta.productViews)}
            ${tile("Chats started", v.delta.chatsStarted)}
            ${tile("Saves", v.delta.saves)}
          </tr>
        </table>
        ${productRows}
        <p style="text-align: center; margin: 26px 0 0;">
          <a href="${PORTAL_URL}/dashboard/"
            style="display: inline-block; background: #095858; color: #fff;
            text-decoration: none; font-weight: 700; font-size: 14px;
            padding: 11px 26px; border-radius: 10px;">
            Open your Business Portal
          </a>
        </p>
        <p style="margin: 26px 0 0; font-size: 11px; color: #9E9E9E;">
          You receive this because your shop has a paid PetaFinds membership.
          <br>PetaFinds · Bringing Pettah online · Colombo 11
        </p>
      </div>
    </div>
  `;
}

// ============================================================================
// ANALYTICS PHASE A — time-bucketed capture (BI foundation)
//
// The lifetime counters in business_stats / product_stats stay untouched
// (the app's live dashboard keeps reading them). Phase A adds DAILY
// buckets so the portal BI module can answer time-filtered questions
// (Today / 7d / 30d / trends), plus a search-event pipeline (impressions,
// clicks, positions, terms) that never existed before. All docs are
// backend-owned; clients only read their own business's buckets.
// ============================================================================

/** Calendar day key in Asia/Colombo (+05:30, no DST) — the marketplace's
 * home timezone, matching the daily sweep and monthly report.
 * @param {Date} [d] moment to bucket (default now).
 * @return {string} YYYY-MM-DD.
 */
function colomboDayKey(d = new Date()) {
  return new Date(d.getTime() + 5.5 * 3600 * 1000)
      .toISOString().slice(0, 10);
}

/** Sanitize a search term into a doc-id-safe slug (lowercased, dashed,
 * capped); falls back to a hash for terms with no safe characters.
 * @param {string} term raw user query (already trimmed/lowercased).
 * @return {string} slug safe for use inside a Firestore doc id.
 */
function termSlug(term) {
  const slug = term.toLowerCase().replace(/\s+/g, "-")
      .replace(/[^a-z0-9-]/g, "").slice(0, 40);
  if (slug) return slug;
  return crypto.createHash("sha1").update(term).digest("hex").slice(0, 12);
}

// --------------------------------------------------------------------------
// recordSearchEvent — search analytics capture (App Check enforced).
//
//   kind: "impressions" — fired once per executed search; `items` lists
//         the top results shown (max 10) with their 1-based positions.
//   kind: "click"       — fired when a result is opened from search.
//
// Per event this increments three families of daily docs:
//   search_terms_daily/{day}__{slug}         market-wide term demand
//   search_daily/{businessId}_{day}          per-business visibility
//   product_search_daily/{productId}_{day}   per-product visibility
// positionSum / impressions give average position; top10 counts
// first-page appearances. Rate-limited per user so a hostile client
// can't grind Firestore writes.
// --------------------------------------------------------------------------
exports.recordSearchEvent = onCall(
    {enforceAppCheck: true},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required.");
      }
      const data = request.data || {};
      const kind = String(data.kind || "");
      if (!["impressions", "click"].includes(kind)) {
        throw new HttpsError(
            "invalid-argument", "kind must be impressions or click.");
      }
      const term = String(data.term || "").trim().toLowerCase();
      if (term.length < 1 || term.length > 60) {
        throw new HttpsError(
            "invalid-argument", "term must be 1-60 characters.");
      }

      const posOf = (v) => {
        const p = Number(v);
        return Number.isInteger(p) && p >= 1 && p <= 50 ? p : null;
      };
      const idOk = (s) =>
        typeof s === "string" && s.length > 0 && s.length <= 128;

      /** @type {{productId:string,businessId:string,position:number}[]} */
      let items = [];
      if (kind === "impressions") {
        if (!Array.isArray(data.items) || data.items.length === 0 ||
            data.items.length > 10) {
          throw new HttpsError(
              "invalid-argument", "items must contain 1-10 results.");
        }
        for (const raw of data.items) {
          const position = posOf(raw && raw.position);
          if (!raw || !idOk(raw.productId) || !idOk(raw.businessId) ||
              position === null) {
            throw new HttpsError(
                "invalid-argument", "each item needs productId, " +
                "businessId and a 1-50 position.");
          }
          items.push({
            productId: raw.productId,
            businessId: raw.businessId,
            position,
          });
        }
      } else {
        const position = posOf(data.position);
        if (!idOk(data.productId) || !idOk(data.businessId) ||
            position === null) {
          throw new HttpsError(
              "invalid-argument", "click needs productId, businessId " +
              "and a 1-50 position.");
        }
        items = [{
          productId: data.productId,
          businessId: data.businessId,
          position,
        }];
      }

      // 120 search events per user per hour — generous for a human,
      // hostile for a write-grinder.
      await enforceRateLimit(`search:${request.auth.uid}`, 120, 3600);

      const day = colomboDayKey();
      const inc = admin.firestore.FieldValue.increment;
      const now = admin.firestore.FieldValue.serverTimestamp();
      const writes = [];

      // Market-wide term demand (backend/aggregation reads only).
      writes.push(db.collection("search_terms_daily")
          .doc(`${day}__${termSlug(term)}`)
          .set({
            term,
            date: day,
            searches: inc(kind === "impressions" ? 1 : 0),
            clicks: inc(kind === "click" ? 1 : 0),
            updatedAt: now,
          }, {merge: true}));

      // Group impressions per business so each business doc gets ONE write.
      const byBusiness = new Map();
      for (const it of items) {
        const agg = byBusiness.get(it.businessId) ||
          {impressions: 0, clicks: 0, positionSum: 0, top10: 0};
        agg.impressions += kind === "impressions" ? 1 : 0;
        agg.clicks += kind === "click" ? 1 : 0;
        agg.positionSum += it.position;
        agg.top10 += (kind === "impressions" && it.position <= 10) ? 1 : 0;
        byBusiness.set(it.businessId, agg);
      }
      for (const [businessId, agg] of byBusiness) {
        writes.push(db.collection("search_daily")
            .doc(`${businessId}_${day}`)
            .set({
              businessId,
              date: day,
              impressions: inc(agg.impressions),
              clicks: inc(agg.clicks),
              positionSum: inc(agg.positionSum),
              top10: inc(agg.top10),
              updatedAt: now,
            }, {merge: true}));
      }

      for (const it of items) {
        writes.push(db.collection("product_search_daily")
            .doc(`${it.productId}_${day}`)
            .set({
              productId: it.productId,
              businessId: it.businessId,
              date: day,
              impressions: inc(kind === "impressions" ? 1 : 0),
              clicks: inc(kind === "click" ? 1 : 0),
              positionSum: inc(it.position),
              top10: inc(
                  kind === "impressions" && it.position <= 10 ? 1 : 0),
              updatedAt: now,
            }, {merge: true}));
      }

      await Promise.all(writes);
      return {ok: true};
    },
);

// ============================================================================
// ANALYTICS PHASE B — nightly aggregation engine.
//
// One O(marketplace) pass at 03:30 Asia/Colombo computes everything the
// tiered BI module displays, so portal pages are cheap single-doc reads
// and NO merchant query ever touches another merchant's raw data:
//
//   bizInsights/{businessId}   PRIVATE per-business insights (owner+admin
//                              read): marketplace/membership/category
//                              positions + movement vs the previous run,
//                              percentile band, per-product positions,
//                              category benchmark deltas.
//
//   marketAggregates/latest    ANONYMOUS marketplace intelligence (any
//   marketAggregates/{date}    signed-in read): category demand share,
//                              category averages, tier averages, top /
//                              trending / declining search terms. No
//                              business or product identities inside.
//
// Rerunning is a pure overwrite of derived state — fully idempotent.
// ============================================================================
exports.nightlyMarketAggregation = onSchedule(
    {
      schedule: "30 3 * * *",
      timeZone: "Asia/Colombo",
      memory: "512MiB",
      timeoutSeconds: 540,
    },
    async () => {
      const today = colomboDayKey();
      const dayKeyAgo = (n) =>
        colomboDayKey(new Date(Date.now() - n * 86400000));

      // ---------- load the marketplace ----------
      const [bizSnap, bizStatsSnap, prodSnap, prodStatsSnap] =
        await Promise.all([
          db.collection("businesses").get(),
          db.collection("business_stats").get(),
          db.collection("products").where("isActive", "==", true)
              .select("businessId", "category", "title", "rankViews").get(),
          db.collection("product_stats").get(),
        ]);

      const businesses = new Map(); // id → {tier, category, ownerUid}
      for (const d of bizSnap.docs) {
        const b = d.data() || {};
        businesses.set(d.id, {
          tier: b.tier || "listed",
          category: b.category || "Other",
          suspended: b.suspended === true,
        });
      }
      const bizStats = new Map(); // id → {profileViews,...}
      for (const d of bizStatsSnap.docs) bizStats.set(d.id, d.data() || {});
      const prodStats = new Map(); // id → {views, chats, saves}
      for (const d of prodStatsSnap.docs) prodStats.set(d.id, d.data() || {});

      // products joined with owner tier/category + engagement
      const products = [];
      for (const d of prodSnap.docs) {
        const p = d.data() || {};
        const owner = businesses.get(p.businessId);
        if (!owner || owner.suspended) continue;
        const s = prodStats.get(d.id) || {};
        products.push({
          id: d.id,
          businessId: p.businessId,
          category: p.category || owner.category || "Other",
          tier: owner.tier,
          views: s.views || 0,
          chats: s.chats || 0,
          saves: s.saves || 0,
        });
      }

      // ---------- product rankings ----------
      // Marketplace position = rank by lifetime views (ties broken by
      // chats then saves so the order is stable night to night).
      const byEngagement = (a, b) =>
        (b.views - a.views) || (b.chats - a.chats) || (b.saves - a.saves);
      products.sort(byEngagement);
      const totalProducts = products.length;
      const tierTotals = {};
      const tierSeen = {};
      const catTotals = {};
      const catSeen = {};
      for (const p of products) {
        tierTotals[p.tier] = (tierTotals[p.tier] || 0) + 1;
        catTotals[p.category] = (catTotals[p.category] || 0) + 1;
      }
      products.forEach((p, i) => {
        p.marketplacePosition = i + 1;
        tierSeen[p.tier] = (tierSeen[p.tier] || 0) + 1;
        p.tierPosition = tierSeen[p.tier];
        catSeen[p.category] = (catSeen[p.category] || 0) + 1;
        p.categoryPosition = catSeen[p.category];
      });

      // ---------- denormalize rankViews onto product docs ----------
      // Discovery surfaces rank client-side (tier band first, views as
      // the within-band refinement — utils/marketplace_rank.dart) but
      // product_stats is owner-readable only. A nightly changed-docs-only
      // copy of the lifetime view count onto the public product doc gives
      // every surface the signal at zero per-view write cost, without
      // churning customer product streams during the day. rankViews is
      // backend-owned (blocked in the products update rule).
      {
        const currentRank = new Map();
        for (const d of prodSnap.docs) {
          currentRank.set(d.id, (d.data() || {}).rankViews || 0);
        }
        let rb = db.batch();
        let rn = 0;
        let rankWrites = 0;
        for (const p of products) {
          if ((currentRank.get(p.id) || 0) === p.views) continue;
          rb.update(
              db.collection("products").doc(p.id), {rankViews: p.views});
          rankWrites++;
          if (++rn === 400) {
            await rb.commit();
            rb = db.batch();
            rn = 0;
          }
        }
        if (rn > 0) await rb.commit();
        logger.info("[aggregation] rankViews refreshed on",
            rankWrites, "products");
      }

      // ---------- business rankings ----------
      const bizRows = [];
      for (const [id, meta] of businesses) {
        if (meta.suspended) continue;
        const s = bizStats.get(id) || {};
        bizRows.push({
          id,
          tier: meta.tier,
          category: meta.category,
          engagement: (s.profileViews || 0) + (s.productViews || 0) +
            (s.chatsStarted || 0) + (s.saves || 0),
          views: s.productViews || 0,
          saves: s.saves || 0,
          chats: s.chatsStarted || 0,
        });
      }
      bizRows.sort((a, b) => b.engagement - a.engagement);
      const totalBusinesses = bizRows.length;
      const bTierTotals = {};
      const bTierSeen = {};
      for (const r of bizRows) {
        bTierTotals[r.tier] = (bTierTotals[r.tier] || 0) + 1;
      }
      bizRows.forEach((r, i) => {
        r.marketplacePosition = i + 1;
        bTierSeen[r.tier] = (bTierSeen[r.tier] || 0) + 1;
        r.tierPosition = bTierSeen[r.tier];
        r.percentile = totalBusinesses > 1 ?
          Math.ceil((r.marketplacePosition / totalBusinesses) * 100) : 100;
      });
      /** Human percentile band ("Top 5%") from a 1-100 percentile.
       * @param {number} p percentile (lower = better).
       * @return {string} display band. */
      const band = (p) => {
        for (const b of [1, 2, 5, 10, 25, 50]) {
          if (p <= b) return `Top ${b}%`;
        }
        return "Growing";
      };

      // ---------- category benchmarks (anonymous averages) ----------
      const catAgg = {}; // category → sums across businesses
      for (const r of bizRows) {
        const c = catAgg[r.category] ||
          {businesses: 0, views: 0, saves: 0, chats: 0};
        c.businesses++;
        c.views += r.views;
        c.saves += r.saves;
        c.chats += r.chats;
        catAgg[r.category] = c;
      }
      let marketViews = 0;
      for (const c of Object.values(catAgg)) marketViews += c.views;
      const categoryStats = {};
      for (const [name, c] of Object.entries(catAgg)) {
        categoryStats[name] = {
          businesses: c.businesses,
          products: catTotals[name] || 0,
          avgViews: Math.round(c.views / c.businesses),
          avgSaves: Math.round(c.saves / c.businesses),
          avgChats: Math.round(c.chats / c.businesses),
          demandSharePct: marketViews > 0 ?
            Math.round((c.views / marketViews) * 1000) / 10 : 0,
        };
      }

      // ---------- tier averages (incl. 7-day search visibility) ----------
      const searchSnap = await db.collection("search_daily")
          .where("date", ">=", dayKeyAgo(7)).get();
      const bizSearch7 = new Map(); // businessId → {impressions, clicks}
      for (const d of searchSnap.docs) {
        const s = d.data() || {};
        const cur = bizSearch7.get(s.businessId) ||
          {impressions: 0, clicks: 0};
        cur.impressions += s.impressions || 0;
        cur.clicks += s.clicks || 0;
        bizSearch7.set(s.businessId, cur);
      }
      const tierAverages = {};
      for (const tier of ["listed", "spotlight", "prime", "elite"]) {
        const rows = bizRows.filter((r) => r.tier === tier);
        if (rows.length === 0) continue;
        let imp = 0;
        for (const r of rows) {
          imp += (bizSearch7.get(r.id) || {}).impressions || 0;
        }
        tierAverages[tier] = {
          businesses: rows.length,
          avgEngagement: Math.round(
              rows.reduce((a, r) => a + r.engagement, 0) / rows.length),
          avgViews: Math.round(
              rows.reduce((a, r) => a + r.views, 0) / rows.length),
          avgSearchImpressions7d: Math.round(imp / rows.length),
        };
      }

      // ---------- search-term intelligence (anonymized) ----------
      const termsSnap = await db.collection("search_terms_daily")
          .where("date", ">=", dayKeyAgo(30)).get();
      const termAgg = new Map(); // term → {d1, d7, d30, prev7, clicks30}
      for (const d of termsSnap.docs) {
        const t = d.data() || {};
        if (!t.term) continue;
        const cur = termAgg.get(t.term) ||
          {d1: 0, d7: 0, d30: 0, prev7: 0, clicks30: 0};
        const searches = t.searches || 0;
        cur.d30 += searches;
        cur.clicks30 += t.clicks || 0;
        if (t.date >= dayKeyAgo(1)) cur.d1 += searches;
        if (t.date >= dayKeyAgo(7)) cur.d7 += searches;
        else if (t.date >= dayKeyAgo(14)) cur.prev7 += searches;
        termAgg.set(t.term, cur);
      }
      const termRows = [...termAgg.entries()].map(([term, v]) => ({
        term, ...v,
        growthPct: v.prev7 > 0 ?
          Math.round(((v.d7 - v.prev7) / v.prev7) * 100) :
          (v.d7 > 0 ? 100 : 0),
      }));
      const top = (key, n = 100) => [...termRows]
          .sort((a, b) => b[key] - a[key])
          .slice(0, n)
          .filter((t) => t[key] > 0)
          .map((t) => ({term: t.term, searches: t[key],
            clicks: t.clicks30, growthPct: t.growthPct}));
      const trending = [...termRows]
          .filter((t) => t.d7 >= 3)
          .sort((a, b) => b.growthPct - a.growthPct).slice(0, 25)
          .map((t) => ({term: t.term, searches: t.d7,
            growthPct: t.growthPct}));
      const declining = [...termRows]
          .filter((t) => t.prev7 >= 3)
          .sort((a, b) => a.growthPct - b.growthPct).slice(0, 25)
          .map((t) => ({term: t.term, searches: t.d7,
            growthPct: t.growthPct}));

      // ---------- write: anonymous market aggregates ----------
      const aggregate = {
        date: today,
        totals: {
          businesses: totalBusinesses,
          products: totalProducts,
          categories: Object.keys(categoryStats).length,
        },
        categoryStats,
        tierAverages,
        topTermsToday: top("d1"),
        topTermsWeek: top("d7"),
        topTermsMonth: top("d30"),
        trendingTerms: trending,
        decliningTerms: declining,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await db.collection("marketAggregates").doc("latest").set(aggregate);
      await db.collection("marketAggregates").doc(today).set(aggregate);

      // ---------- write: private per-business insights ----------
      // Previous positions are read in bulk first so movement indicators
      // compare against the prior run without N extra reads at write time.
      const prevSnap = await db.collection("bizInsights").get();
      const prev = new Map();
      for (const d of prevSnap.docs) prev.set(d.id, d.data() || {});

      const prodByBiz = new Map();
      for (const p of products) {
        const list = prodByBiz.get(p.businessId) || [];
        list.push(p);
        prodByBiz.set(p.businessId, list);
      }

      let batch = db.batch();
      let inBatch = 0;
      // Milestone notifications (Vibranium): collected during the loop,
      // minted AFTER the batch commits so a write failure can't spam.
      const milestones = [];
      const bizOwner = new Map();
      for (const d of bizSnap.docs) {
        bizOwner.set(d.id, (d.data() || {}).ownerUid || null);
      }
      for (const r of bizRows) {
        const p = prev.get(r.id) || {};
        const cat = categoryStats[r.category] || null;
        // Previous per-product positions → movement arrows in the portal.
        const prevProd = new Map((p.productPositions || [])
            .map((x) => [x.productId, x.marketplacePosition]));
        const myProducts = (prodByBiz.get(r.id) || [])
            .sort(byEngagement)
            .slice(0, 100) // doc-size guard; covers every current cap tier
            .map((x) => ({
              productId: x.id,
              views: x.views,
              chats: x.chats,
              saves: x.saves,
              marketplacePosition: x.marketplacePosition,
              tierPosition: x.tierPosition,
              categoryPosition: x.categoryPosition,
              prevMarketplacePosition: prevProd.get(x.id) || null,
            }));
        batch.set(db.collection("bizInsights").doc(r.id), {
          businessId: r.id,
          date: today,
          tier: r.tier,
          category: r.category,
          marketplacePosition: r.marketplacePosition,
          totalBusinesses,
          tierPosition: r.tierPosition,
          tierTotal: bTierTotals[r.tier] || 0,
          percentile: r.percentile,
          percentileBand: band(r.percentile),
          prevMarketplacePosition: p.marketplacePosition || null,
          prevTierPosition: p.tierPosition || null,
          categoryBenchmark: cat ? {
            category: r.category,
            avgViews: cat.avgViews,
            avgSaves: cat.avgSaves,
            avgChats: cat.avgChats,
            myViews: r.views,
            mySaves: r.saves,
            myChats: r.chats,
            viewsVsAvgPct: cat.avgViews > 0 ?
              Math.round(((r.views - cat.avgViews) / cat.avgViews) * 100) :
              0,
          } : null,
          search7d: bizSearch7.get(r.id) || {impressions: 0, clicks: 0},
          totalProducts: (prodByBiz.get(r.id) || []).length,
          marketplaceProductTotal: totalProducts,
          tierProductTotal: tierTotals[r.tier] || 0,
          productPositions: myProducts,
          lifetimeViews: r.views,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        inBatch++;
        if (inBatch === 400) {
          await batch.commit();
          batch = db.batch();
          inBatch = 0;
        }

        // ---- Vibranium milestone detection (skip a business's first
        // run: no baseline means every check would fire spuriously). ----
        if (r.tier === "elite" && prev.has(r.id)) {
          const owner = bizOwner.get(r.id);
          if (owner) {
            const newBand = band(r.percentile);
            const oldBand = p.percentileBand;
            if (oldBand && newBand !== oldBand &&
                r.percentile < (p.percentile || 100) &&
                newBand.startsWith("Top")) {
              milestones.push([owner, "You entered the " + newBand + " 🚀",
                `Your business now ranks #${r.marketplacePosition} of ` +
                `${totalBusinesses} on PetaFinds.`]);
            }
            if (p.marketplacePosition &&
                r.marketplacePosition < p.marketplacePosition &&
                (p.marketplacePosition - r.marketplacePosition >= 3 ||
                 (r.marketplacePosition <= 10 &&
                  p.marketplacePosition > 10))) {
              milestones.push([owner, "Marketplace position up ▲",
                `#${p.marketplacePosition} → #${r.marketplacePosition} ` +
                "overnight. Keep it going!"]);
            }
            const prevViews = typeof p.lifetimeViews === "number" ?
              p.lifetimeViews : null;
            if (prevViews !== null) {
              for (const t of [1000, 5000, 10000, 50000, 100000]) {
                if (prevViews < t && r.views >= t) {
                  milestones.push([owner,
                    `Your products passed ${t.toLocaleString()} views 🎉`,
                    "A new all-time record for your shop."]);
                  break;
                }
              }
            }
            const prevProdPos = new Map((p.productPositions || [])
                .map((x) => [x.productId, x.marketplacePosition]));
            for (const mp of myProducts) {
              const was = prevProdPos.get(mp.productId);
              if (mp.marketplacePosition <= 10 && was && was > 10) {
                milestones.push([owner,
                  "A product reached the marketplace Top 10 🏆",
                  `It now sits at #${mp.marketplacePosition} of ` +
                  `${totalProducts} products.`]);
                break;
              }
            }
          }
        }
      }
      if (inBatch > 0) await batch.commit();

      // Cap per night so a volatile ranking day can't flood an inbox.
      for (const [uid, title, body] of milestones.slice(0, 60)) {
        await mintNotification(uid, title, body, "membership");
      }

      logger.info("[aggregation] nightly run complete:", totalBusinesses,
          "businesses,", totalProducts, "products,", termAgg.size, "terms");
    },
);

// --------------------------------------------------------------------------
// executivePeriodicReports — Vibranium executive reports by email.
//
// Runs daily 07:00 Colombo and decides what is due:
//   Monday          → weekly report  (last 7 full days vs the 7 before)
//   1st of quarter  → quarterly report (previous quarter vs the one before)
//   January 1st     → yearly report  (previous year vs the year before)
// Monthly reports for ALL paid tiers are handled separately by
// monthlyBusinessReport. Idempotent per business+period via markers in
// execReports/{businessId} (a retry or double-fire never re-sends).
// --------------------------------------------------------------------------
exports.executivePeriodicReports = onSchedule(
    {
      schedule: "0 7 * * *",
      timeZone: "Asia/Colombo",
      secrets: [RESEND_API_KEY],
      timeoutSeconds: 540,
    },
    async () => {
      // "Now" in Colombo civil time.
      const nowCo = new Date(Date.now() + 5.5 * 3600 * 1000);
      const y = nowCo.getUTCFullYear();
      const m = nowCo.getUTCMonth(); // 0-based
      const dom = nowCo.getUTCDate();
      const dow = nowCo.getUTCDay(); // 1 = Monday

      /** @type {{type:string,key:string,from:string,to:string,
       *          prevFrom:string,prevTo:string,label:string}[]} */
      const due = [];
      const dayKeyAgo = (n) =>
        colomboDayKey(new Date(Date.now() - n * 86400000));
      if (dow === 1) {
        due.push({
          type: "weekly",
          key: `weekly_${dayKeyAgo(7)}`,
          from: dayKeyAgo(7), to: dayKeyAgo(1),
          prevFrom: dayKeyAgo(14), prevTo: dayKeyAgo(8),
          label: "Weekly report",
        });
      }
      if (dom === 1 && [0, 3, 6, 9].includes(m)) {
        const qEndY = m === 0 ? y - 1 : y;
        const qStartM = m === 0 ? 9 : m - 3;
        const pad = (n) => String(n + 1).padStart(2, "0");
        const lastDay = new Date(Date.UTC(qEndY, qStartM + 3, 0))
            .getUTCDate();
        due.push({
          type: "quarterly",
          key: `quarterly_${qEndY}-Q${Math.floor(qStartM / 3) + 1}`,
          from: `${qEndY}-${pad(qStartM)}-01`,
          to: `${qEndY}-${pad(qStartM + 2)}-${lastDay}`,
          prevFrom: "", prevTo: "", // growth omitted for quarters v1
          label: "Quarterly business report",
        });
      }
      if (dom === 1 && m === 0) {
        due.push({
          type: "yearly",
          key: `yearly_${y - 1}`,
          from: `${y - 1}-01-01`, to: `${y - 1}-12-31`,
          prevFrom: `${y - 2}-01-01`, prevTo: `${y - 2}-12-31`,
          label: "Yearly business report",
        });
      }
      if (due.length === 0) return;

      const elite = await db.collection("businesses")
          .where("tier", "==", "elite").get();
      if (elite.empty) return;
      const resend = new Resend(RESEND_API_KEY.value());

      /** Sum a business's day-buckets over an inclusive key range.
       * @param {string} col collection name.
       * @param {string} bizId business id.
       * @param {string} from from key.
       * @param {string} to to key.
       * @return {Promise<object>} summed numeric fields. */
      const sumRange = async (col, bizId, from, to) => {
        if (!from) return {};
        const snap = await db.collection(col)
            .where("businessId", "==", bizId)
            .where("date", ">=", from)
            .where("date", "<=", to)
            .get();
        const out = {};
        for (const d of snap.docs) {
          for (const [k, v] of Object.entries(d.data() || {})) {
            if (typeof v === "number") out[k] = (out[k] || 0) + v;
          }
        }
        return out;
      };
      /** Growth percentage, null when no baseline.
       * @param {number} cur current value.
       * @param {number} prevV previous value.
       * @return {number|null} rounded percent. */
      const growth = (cur, prevV) => prevV > 0 ?
        Math.round(((cur - prevV) / prevV) * 100) : null;

      for (const bizDoc of elite.docs) {
        const biz = bizDoc.data() || {};
        const email = String(biz.email || "").trim().toLowerCase();
        if (!email) continue;
        const markerRef = db.collection("execReports").doc(bizDoc.id);
        const marker = (await markerRef.get()).data() || {};

        for (const r of due) {
          try {
            if (marker[`last_${r.type}`] === r.key) continue;
            const [cur, prevP, curS, insightsSnap] = await Promise.all([
              sumRange("stats_daily", bizDoc.id, r.from, r.to),
              sumRange("stats_daily", bizDoc.id, r.prevFrom, r.prevTo),
              sumRange("search_daily", bizDoc.id, r.from, r.to),
              db.collection("bizInsights").doc(bizDoc.id).get(),
            ]);
            const ins = insightsSnap.exists ?
              (insightsSnap.data() || {}) : {};
            const views = cur.productViews || 0;
            const impressions = curS.impressions || 0;
            const clicks = curS.clicks || 0;
            const recs = [];
            if (impressions > 0 && views / impressions < 0.05) {
              recs.push("Search visibility is strong but clicks lag — " +
                "sharper photos and titles usually lift CTR fastest.");
            }
            if ((cur.saves || 0) > 0 && (cur.chatsStarted || 0) === 0) {
              recs.push("Customers are saving products but not chatting " +
                "— check that your WhatsApp and phone are current.");
            }
            if (recs.length === 0) {
              recs.push("Keep listings fresh — recently added products " +
                "get a discovery boost.");
            }
            await resend.emails.send({
              from: "PetaFinds <info@petafinds.lk>",
              to: email,
              subject: `${r.label} — ${biz.businessName || "your shop"}`,
              html: _executiveReportHtml({
                businessName: escapeHtml(biz.businessName || "Your shop"),
                label: escapeHtml(r.label),
                period: `${r.from} → ${r.to}`,
                kpis: [
                  ["Product views", views, growth(views,
                      prevP.productViews || 0)],
                  ["Profile views", cur.profileViews || 0,
                    growth(cur.profileViews || 0,
                        prevP.profileViews || 0)],
                  ["Saves", cur.saves || 0,
                    growth(cur.saves || 0, prevP.saves || 0)],
                  ["Chats", cur.chatsStarted || 0,
                    growth(cur.chatsStarted || 0,
                        prevP.chatsStarted || 0)],
                  ["Search impressions", impressions, null],
                  ["Search CTR", impressions > 0 ?
                    `${((clicks / impressions) * 100).toFixed(1)}%` : "—",
                  null],
                ],
                standing: ins.percentileBand ?
                  `${ins.percentileBand} — #${ins.marketplacePosition} ` +
                  `of ${ins.totalBusinesses} businesses` : "",
                recommendations: recs.map((x) => escapeHtml(x)),
              }),
            });
            await markerRef.set(
                {[`last_${r.type}`]: r.key}, {merge: true});
          } catch (err) {
            logger.error("[exec-report]", r.type, "failed for",
                bizDoc.id, err);
          }
        }
      }
    },
);

/**
 * Executive report email — house template style.
 * @param {object} v Pre-escaped display values.
 * @return {string} HTML body.
 */
function _executiveReportHtml(v) {
  const kpiCell = ([label, value, g]) => `
    <td style="width: 33%; padding: 12px 6px; text-align: center;
      background: #fff; border: 1px solid #EFEFEF;">
      <div style="font-size: 20px; font-weight: 800; color: #095858;">
        ${typeof value === "number" ? value.toLocaleString() : value}
      </div>
      <div style="font-size: 11px; color: #777;">${label}</div>
      ${g === null || g === undefined ? "" : `
      <div style="font-size: 11px; font-weight: 700;
        color: ${g >= 0 ? "#1a7f4e" : "#d63b3b"};">
        ${g >= 0 ? "▲" : "▼"} ${Math.abs(g)}%
      </div>`}
    </td>`;
  const rows = [];
  for (let i = 0; i < v.kpis.length; i += 3) {
    rows.push(`<tr>${v.kpis.slice(i, i + 3).map(kpiCell).join("")}</tr>`);
  }
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 540px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 28px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 22px; font-weight: 800;">
          👑 ${v.label}
        </h1>
        <p style="color: #A8D5D5; margin: 6px 0 0; font-size: 14px;">
          ${v.businessName} · ${v.period}
        </p>
      </div>
      <div style="padding: 28px 24px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8; border-top: none;">
        <table style="width: 100%; border-collapse: collapse;">
          ${rows.join("")}
        </table>
        ${v.standing ? `
        <p style="margin: 20px 0 0; padding: 12px 16px; background: #E8F4F4;
          border-radius: 8px; font-size: 14px; font-weight: 700; color: #095858;">
          Marketplace standing: ${v.standing}
        </p>` : ""}
        <h3 style="font-size: 14px; margin: 22px 0 8px;">Recommendations</h3>
        <ul style="margin: 0; padding-left: 18px; font-size: 13px;
          color: #555; line-height: 1.7;">
          ${v.recommendations.map((r) => `<li>${r}</li>`).join("")}
        </ul>
        <p style="text-align: center; margin: 24px 0 0;">
          <a href="${PORTAL_URL}/analytics/"
            style="display: inline-block; background: #095858; color: #fff;
            text-decoration: none; font-weight: 700; font-size: 14px;
            padding: 11px 26px; border-radius: 10px;">
            Open the full dashboard
          </a>
        </p>
        <p style="margin: 24px 0 0; font-size: 11px; color: #9E9E9E;">
          Vibranium executive reporting · PetaFinds · Colombo 11
        </p>
      </div>
    </div>
  `;
}

// --------------------------------------------------------------------------
// monthlyLeadsReport — Vibranium leads export by email.
//
// Runs 06:30 on the 1st (Colombo), after monthlyBusinessReport. For every
// Vibranium (elite) business it collects the chat threads OPENED during
// the previous month — each thread is one customer lead against one
// product — and emails the owner a summary plus a CSV attachment
// (Date, Product, Customer) for shops that track sales outside the app.
//
// Reads use a single equality query per business (no composite index);
// the month window is filtered in memory. Month boundaries are computed
// in UTC — ±5.5h skew vs Colombo at the month edge is acceptable for a
// lead-count report and keeps this consistent with the other reports.
// Idempotent via leadsReports/{businessId}.lastSentMonth, so a retry or
// double-fire never re-sends. Businesses with zero leads are skipped
// (marker still written so retries don't re-scan them).
// --------------------------------------------------------------------------
exports.monthlyLeadsReport = onSchedule(
    {
      schedule: "30 6 1 * *",
      timeZone: "Asia/Colombo",
      secrets: [RESEND_API_KEY],
    },
    async () => {
      const anchor = new Date(Date.now() - 5 * 86400000); // inside prev month
      const y = anchor.getUTCFullYear();
      const m = anchor.getUTCMonth();
      const monthKey =
        `${y}-${String(m + 1).padStart(2, "0")}`; // YYYY-MM
      const monthName = anchor.toLocaleString("en-US",
          {month: "long", year: "numeric", timeZone: "UTC"});
      const start = Date.UTC(y, m, 1);
      const end = Date.UTC(y, m + 1, 1);
      const resend = new Resend(RESEND_API_KEY.value());

      const elite = await db.collection("businesses")
          .where("tier", "==", "elite").get();
      logger.info("[leads] monthly run", monthKey,
          "candidates:", elite.size);

      /** CSV-escape one field (quote + double internal quotes).
       * @param {string} s raw value.
       * @return {string} safe CSV field. */
      const csvField = (s) => `"${String(s).replace(/"/g, "\"\"")}"`;

      let sent = 0;
      for (const bizDoc of elite.docs) {
        try {
          const biz = bizDoc.data() || {};
          const email = String(biz.email || "").trim().toLowerCase();
          if (!email) continue;

          const markerRef =
            db.collection("leadsReports").doc(bizDoc.id);
          const marker = await markerRef.get();
          if (marker.exists &&
              (marker.data() || {}).lastSentMonth === monthKey) {
            continue; // already sent this period
          }

          const convs = await db.collection("conversations")
              .where("businessId", "==", bizDoc.id).get();
          const leads = [];
          for (const c of convs.docs) {
            const v = c.data() || {};
            const created = v.createdAt && v.createdAt.toMillis ?
              v.createdAt.toMillis() : null;
            if (created === null || created < start || created >= end) {
              continue;
            }
            leads.push({
              date: new Date(created).toISOString().slice(0, 10),
              product: v.productTitle || "Product",
              customer: v.customerName || "Customer",
            });
          }

          if (leads.length === 0) {
            await markerRef.set({
              lastSentMonth: monthKey,
              leads: 0,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            continue;
          }
          leads.sort((a, b) => a.date.localeCompare(b.date));

          // Per-product totals for the email body (top 5).
          const byProduct = new Map();
          for (const l of leads) {
            byProduct.set(l.product, (byProduct.get(l.product) || 0) + 1);
          }
          const topProducts = [...byProduct.entries()]
              .sort((a, b) => b[1] - a[1]).slice(0, 5);

          const csv = ["Date,Product,Customer",
            ...leads.map((l) =>
              [l.date, l.product, l.customer].map(csvField).join(",")),
          ].join("\r\n");

          await resend.emails.send({
            from: "PetaFinds <info@petafinds.lk>",
            to: email,
            subject:
              `${leads.length} customer lead` +
              `${leads.length === 1 ? "" : "s"} in ${monthName} — ` +
              `${biz.businessName || "your shop"}`,
            html: _leadsReportHtml({
              businessName: escapeHtml(biz.businessName || "Your shop"),
              monthName: escapeHtml(monthName),
              total: leads.length,
              topProducts: topProducts.map(([title, count]) =>
                ({title: escapeHtml(title), count})),
            }),
            attachments: [{
              filename: `petafinds-leads-${monthKey}.csv`,
              content: Buffer.from(csv, "utf8").toString("base64"),
            }],
          });

          await markerRef.set({
            lastSentMonth: monthKey,
            leads: leads.length,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          sent++;
        } catch (err) {
          logger.error("[leads] failed for", bizDoc.id, err);
        }
      }
      logger.info("[leads] monthly leads reports sent:", sent);
    },
);

/**
 * Monthly leads report email — house template style.
 * @param {object} v Pre-escaped display values.
 * @return {string} HTML body.
 */
function _leadsReportHtml(v) {
  const rows = v.topProducts.map((p) => `
    <tr>
      <td style="padding: 8px 12px; border-bottom: 1px solid #EFEFEF;
        font-size: 13px; color: #333;">${p.title}</td>
      <td style="padding: 8px 12px; border-bottom: 1px solid #EFEFEF;
        font-size: 13px; font-weight: 800; color: #095858;
        text-align: right;">${p.count}</td>
    </tr>`).join("");
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 540px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 28px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 22px; font-weight: 800;">
          📋 Your ${v.monthName} leads
        </h1>
        <p style="color: #A8D5D5; margin: 6px 0 0; font-size: 14px;">
          ${v.businessName}
        </p>
      </div>
      <div style="padding: 28px 24px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8; border-top: none;">
        <p style="margin: 0; font-size: 15px; line-height: 1.6;">
          <strong>${v.total}</strong> customer${v.total === 1 ? "" : "s"}
          started a chat about your products in ${v.monthName}.
          The full list is attached as a CSV you can open in Excel.
        </p>
        <h3 style="font-size: 14px; margin: 22px 0 8px;">
          Most-inquired products
        </h3>
        <table style="width: 100%; border-collapse: collapse;
          background: #fff; border: 1px solid #EFEFEF;">
          ${rows}
        </table>
        <p style="margin: 20px 0 0; font-size: 13px; color: #555;
          line-height: 1.6;">
          Reply to every lead while it's warm — buyers in Pettah usually
          message several shops at once, and the first clear answer wins.
        </p>
        <p style="margin: 24px 0 0; font-size: 11px; color: #9E9E9E;">
          Vibranium leads reporting · PetaFinds · Colombo 11
        </p>
      </div>
    </div>
  `;
}
