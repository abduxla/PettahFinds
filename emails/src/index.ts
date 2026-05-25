import {setGlobalOptions} from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {Resend} from "resend";

setGlobalOptions({maxInstances: 10});

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

// ---------------------------------------------------------------------------
// onBusinessCreated — fires when a new business doc is created.
// Sends "under review" email if isVerified is false or absent.
// ---------------------------------------------------------------------------
export const onBusinessCreated = onDocumentCreated(
  {document: "businesses/{businessId}", secrets: [RESEND_API_KEY]},
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.isVerified === true) return; // admin-created and pre-approved

    const email = data.email as string | undefined;
    if (!email) {
      logger.info("[email] no email field on business doc — skipping");
      return;
    }

    const businessName =
      (data.businessName as string | undefined) ?? "Your business";

    const resend = new Resend(RESEND_API_KEY.value());
    const {error} = await resend.emails.send({
      from: "PetaFinds <info@petafinds.lk>",
      to: email,
      subject: "Your PetaFinds Business Registration Is Under Review",
      html: underReviewHtml(businessName),
    });

    if (error) {
      logger.error("[email] under-review send failed", error);
    } else {
      logger.info("[email] under-review email sent to", email);
    }
  }
);

// ---------------------------------------------------------------------------
// onBusinessVerified — fires on every business doc update.
// Sends "approved" email only when isVerified flips false → true.
// ---------------------------------------------------------------------------
export const onBusinessVerified = onDocumentUpdated(
  {document: "businesses/{businessId}", secrets: [RESEND_API_KEY]},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.isVerified === true) return; // already verified before update
    if (after.isVerified !== true) return; // not being approved now

    const email = after.email as string | undefined;
    if (!email) {
      logger.info("[email] no email field on business doc — skipping");
      return;
    }

    const businessName =
      (after.businessName as string | undefined) ?? "Your business";

    const resend = new Resend(RESEND_API_KEY.value());
    const {error} = await resend.emails.send({
      from: "PetaFinds <info@petafinds.lk>",
      to: email,
      subject: "Your PetaFinds Business Has Been Approved",
      html: approvedHtml(businessName),
    });

    if (error) {
      logger.error("[email] approval send failed", error);
    } else {
      logger.info("[email] approval email sent to", email);
    }
  }
);

// ---------------------------------------------------------------------------
// HTML templates
// ---------------------------------------------------------------------------

/* eslint-disable max-len */

/**
 * Returns the branded under-review email body for a newly submitted business.
 * @param {string} businessName - Display name of the business.
 * @return {string} HTML email body.
 */
function underReviewHtml(businessName: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Business Is Under Review</title>
</head>
<body style="margin:0;padding:0;background:#F5F5F0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
    <tr>
      <td align="center" style="padding:40px 16px;">
        <table width="540" cellpadding="0" cellspacing="0" role="presentation"
          style="max-width:540px;width:100%;">

          <!-- Header -->
          <tr>
            <td style="background:#095858;border-radius:12px 12px 0 0;
              padding:32px;text-align:center;">
              <span style="color:#ffffff;font-size:26px;font-weight:800;
                letter-spacing:-0.5px;">PetaFinds</span>
              <span style="display:inline-block;width:7px;height:7px;
                background:#E8821A;border-radius:50%;
                vertical-align:super;margin-left:2px;"></span>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="background:#FAFAF8;border:1px solid #E8E8E8;
              border-top:none;border-radius:0 0 12px 12px;padding:36px 32px;">

              <h2 style="margin:0 0 8px;font-size:22px;font-weight:800;
                color:#1A1A1A;letter-spacing:-0.3px;">
                Your business is under review
              </h2>

              <p style="font-size:15px;color:#555555;line-height:1.6;
                margin:0 0 24px;">
                Thank you for registering
                <strong>${businessName}</strong> with PetaFinds.
                Our team is reviewing your submission.
              </p>

              <!-- Timeline badge -->
              <table width="100%" cellpadding="0" cellspacing="0"
                role="presentation"
                style="background:#FFF8F0;border-left:4px solid #E8821A;
                border-radius:8px;margin-bottom:24px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="margin:0;font-size:14px;color:#E8821A;
                      font-weight:700;">
                      &#x23F1; Expected review time: 24–48 hours
                    </p>
                    <p style="margin:8px 0 0;font-size:14px;color:#7A4A00;">
                      We will verify your business information and notify you
                      once your listing goes live.
                    </p>
                  </td>
                </tr>
              </table>

              <p style="font-size:14px;color:#555555;line-height:1.65;
                margin:0 0 12px;">
                Once approved, <strong>${businessName}</strong> will be visible
                to thousands of customers searching for products and shops
                in Pettah.
              </p>

              <p style="font-size:14px;color:#555555;line-height:1.65;
                margin:0 0 0;">
                In the meantime, you can browse PetaFinds as a customer to
                get familiar with the platform.
              </p>

              <hr style="border:none;border-top:1px solid #E8E8E8;
                margin:32px 0 16px;">
              <p style="margin:0;font-size:12px;color:#9E9E9E;
                text-align:center;">
                PetaFinds &middot; Bringing Pettah online &middot; Colombo 11
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * Returns the branded approval email body when a business is verified.
 * @param {string} businessName - Display name of the business.
 * @return {string} HTML email body.
 */
function approvedHtml(businessName: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Business Has Been Approved</title>
</head>
<body style="margin:0;padding:0;background:#F5F5F0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
    <tr>
      <td align="center" style="padding:40px 16px;">
        <table width="540" cellpadding="0" cellspacing="0" role="presentation"
          style="max-width:540px;width:100%;">

          <!-- Header -->
          <tr>
            <td style="background:#095858;border-radius:12px 12px 0 0;
              padding:32px;text-align:center;">
              <span style="color:#ffffff;font-size:26px;font-weight:800;
                letter-spacing:-0.5px;">PetaFinds</span>
              <span style="display:inline-block;width:7px;height:7px;
                background:#E8821A;border-radius:50%;
                vertical-align:super;margin-left:2px;"></span>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="background:#FAFAF8;border:1px solid #E8E8E8;
              border-top:none;border-radius:0 0 12px 12px;padding:36px 32px;">

              <h2 style="margin:0 0 8px;font-size:22px;font-weight:800;
                color:#1A1A1A;letter-spacing:-0.3px;">
                &#x1F389; Your business has been approved!
              </h2>

              <p style="font-size:15px;color:#555555;line-height:1.6;
                margin:0 0 24px;">
                Great news! <strong>${businessName}</strong> is now live on
                PetaFinds and visible to customers across Colombo.
              </p>

              <!-- Active badge -->
              <table width="100%" cellpadding="0" cellspacing="0"
                role="presentation"
                style="background:#F0FFF8;border-left:4px solid #095858;
                border-radius:8px;margin-bottom:24px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="margin:0;font-size:14px;color:#095858;
                      font-weight:700;">
                      &#x2705; Your listing is now active
                    </p>
                    <p style="margin:8px 0 0;font-size:14px;color:#1A5C44;">
                      Customers can now find your business, browse your
                      products, and contact you directly through the app.
                    </p>
                  </td>
                </tr>
              </table>

              <p style="font-size:14px;color:#555555;line-height:1.65;
                margin:0 0 0;">
                Open the PetaFinds app to access your business dashboard,
                add products, and start connecting with customers.
              </p>

              <hr style="border:none;border-top:1px solid #E8E8E8;
                margin:32px 0 16px;">
              <p style="margin:0;font-size:12px;color:#9E9E9E;
                text-align:center;">
                PetaFinds &middot; Bringing Pettah online &middot; Colombo 11
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/* eslint-enable max-len */
