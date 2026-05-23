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

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// --------------------------------------------------------------------------
// Email transport (Gmail SMTP via App Password)
//
// Secrets are set per-environment via:
//   firebase functions:secrets:set EMAIL_USER
//   firebase functions:secrets:set EMAIL_PASS
//
// EMAIL_USER  the Gmail address that sends the welcome mail
// EMAIL_PASS  a Gmail App Password (NOT the account password) — generate
//             at https://myaccount.google.com/apppasswords
//
// The transporter is built fresh inside the onUserSignUp handler because
// (a) defineSecret().value() can only be read at runtime, not module
// load, and (b) lazy construction keeps the cold-start cheaper for any
// other function in this file that doesn't send mail.
// --------------------------------------------------------------------------
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

// --------------------------------------------------------------------------
// 5. Welcome email — fires on /users/{uid} create
//
// Two templates:
//   - role 'user'      → "Welcome to PetaFinds" (browse-Pettah copy)
//   - role 'business'  → "Your PetaFinds Business Account" (under-review copy)
//
// Email goes to whatever Firebase Auth has on file for the new user
// (admin.auth().getUser(uid).email). Silently no-ops when the user
// signed up via Apple with "Hide My Email" turned off + no email
// associated, or in any other no-email edge case.
//
// Idempotent on doc create — Firestore triggers fire once per doc
// version; account deletion + re-create would mail twice but that's
// rare and acceptable.
// --------------------------------------------------------------------------
exports.onUserSignUp = onDocumentCreated(
  {
    document: "users/{uid}",
    secrets: [EMAIL_USER, EMAIL_PASS],
  },
  async (event) => {
    const user = event.data?.data();
    if (!user) return;
    const role = user.role || "user";
    const uid = event.params.uid;

    let email;
    try {
      const authUser = await admin.auth().getUser(uid);
      email = authUser.email;
    } catch (err) {
      logger.warn("[email] no auth user for", uid, err);
      return;
    }
    if (!email) {
      logger.info("[email] no email on file for", uid, "— skipping");
      return;
    }

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: EMAIL_USER.value(),
        pass: EMAIL_PASS.value(),
      },
    });

    try {
      if (role === "business") {
        await transporter.sendMail({
          from: "\"PetaFinds\" <noreply@petafinds.lk>",
          to: email,
          subject: "Your PetaFinds Business Account",
          html: _businessWelcomeHtml(),
        });
      } else {
        await transporter.sendMail({
          from: "\"PetaFinds\" <noreply@petafinds.lk>",
          to: email,
          subject: "Welcome to PetaFinds! 🎉",
          html: _customerWelcomeHtml(),
        });
      }
      logger.info("[email] welcome sent to", email, "role", role);
    } catch (err) {
      logger.error("[email] sendMail failed for", email, err);
    }
  },
);

function _customerWelcomeHtml() {
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 520px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 32px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 800;">
          Welcome to PetaFinds
        </h1>
      </div>
      <div style="padding: 32px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8;">
        <p style="font-size: 16px; line-height: 1.6;">
          You now have access to Pettah's wholesale market from your phone.
          Discover products, find businesses, and explore Sri Lanka's busiest
          trade district — all in one place.
        </p>
        <a href="https://petafinds.lk"
          style="display: inline-block; background: #095858; color: white;
          padding: 14px 28px; border-radius: 999px; text-decoration: none;
          font-weight: 600; margin-top: 16px;">
          Start Exploring →
        </a>
        <p style="margin-top: 32px; font-size: 12px; color: #9E9E9E;">
          PetaFinds · Pettah, Colombo 11
        </p>
      </div>
    </div>
  `;
}

function _businessWelcomeHtml() {
  return `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 520px; margin: 0 auto; color: #1A1A1A;">
      <div style="background: #095858; padding: 32px; text-align: center;
        border-radius: 12px 12px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 800;">
          Welcome to PetaFinds
        </h1>
      </div>
      <div style="padding: 32px; background: #FAFAF8;
        border-radius: 0 0 12px 12px; border: 1px solid #E8E8E8;">
        <p style="font-size: 16px; line-height: 1.6;">
          Thank you for registering your business on PetaFinds. Your listing
          is currently under review by our team.
        </p>
        <div style="background: #FFF8F0; border-left: 4px solid #E8821A;
          padding: 16px; border-radius: 8px; margin: 20px 0;">
          <p style="margin: 0; font-size: 14px; color: #E8821A; font-weight: 600;">
            Review Timeline
          </p>
          <p style="margin: 8px 0 0; font-size: 14px; color: #555;">
            A decision will be made within 24–48 hours. You'll receive a
            notification once your listing goes live.
          </p>
        </div>
        <p style="font-size: 14px; color: #555; line-height: 1.6;">
          Once approved, your products will be visible to thousands of buyers
          across Colombo and beyond.
        </p>
        <p style="margin-top: 32px; font-size: 12px; color: #9E9E9E;">
          PetaFinds · Pettah, Colombo 11
        </p>
      </div>
    </div>
  `;
}
