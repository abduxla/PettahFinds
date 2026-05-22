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

const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

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
// 2. Business approved (isVerified false → true) → push to owner
// --------------------------------------------------------------------------
exports.onBusinessVerified = onDocumentUpdated(
  "businesses/{bizId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (before.isVerified === true) return;
    if (after.isVerified !== true) return;

    const ownerUid = after.ownerUid;
    if (!ownerUid) return;
    const token = await getUserToken(ownerUid);
    await sendPush(
      ownerUid,
      token,
      "🎉 Your listing is approved!",
      `${after.businessName || "Your business"} is now live on PettahFinds.`,
      {type: "approval", id: event.params.bizId},
    );
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
