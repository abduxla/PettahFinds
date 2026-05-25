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
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const {Resend} = require("resend");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// --------------------------------------------------------------------------
// Email — Resend (transactional business emails)
//
//   firebase functions:secrets:set RESEND_API_KEY
//
// Legacy Gmail secrets kept for reference but no longer used for new emails.
// --------------------------------------------------------------------------
const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const EMAIL_USER = defineSecret("EMAIL_USER");
const EMAIL_PASS = defineSecret("EMAIL_PASS");

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
        html: _businessUnderReviewHtml(biz.businessName || "Your business"),
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
        html: _businessApprovedHtml(after.businessName || "Your business"),
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
// 5. User sign-up — no-op for now.
//    Business under-review email is sent by onBusinessCreated.
//    Customer welcome emails are disabled until copy is finalised.
// --------------------------------------------------------------------------
exports.onUserSignUp = onDocumentCreated(
  {
    document: "users/{uid}",
    secrets: [EMAIL_USER, EMAIL_PASS],
  },
  async (_event) => {
    // intentionally empty — see comment above
  },
);

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
