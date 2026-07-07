import { getApp, getApps, initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";
import { getStorage } from "firebase/storage";
import {
  initializeAppCheck,
  ReCaptchaV3Provider,
} from "firebase/app-check";

/**
 * Firebase web app config — the SAME registered web app the Flutter
 * project uses (see lib/firebase_options.dart `web`). These values are
 * public client identifiers, not secrets; authorization is enforced by
 * Firestore/Storage rules and App-Check-gated Cloud Functions.
 */
const firebaseConfig = {
  apiKey: "AIzaSyDDSr6ZBmZONlwG1SjyhiXd1DB6tb3tjMg",
  appId: "1:263905072020:web:a39a5ab6920816007c3581",
  messagingSenderId: "263905072020",
  projectId: "pettahfinds-75075",
  authDomain: "pettahfinds-75075.firebaseapp.com",
  storageBucket: "pettahfinds-75075.firebasestorage.app",
};

export const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

/**
 * App Check (web = reCAPTCHA v3). Activates only when the site key is
 * provided at build time — register the web app under Firebase Console →
 * App Check and set NEXT_PUBLIC_RECAPTCHA_SITE_KEY. Portal callables are
 * deployed with `enforceAppCheck: true`, so this must be configured
 * before those features work in production.
 */
// The default is the project's registered reCAPTCHA v3 SITE key — a public
// client identifier (like apiKey above), safe to commit. The env var allows
// override per environment. The SECRET key lives only in Firebase Console →
// App Check and must never appear in this repo.
const recaptchaKey =
  process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY ??
  "6Lf2X0gtAAAAANkHvTOcaLVf1OeuM0m7ivQmPmQ1";
if (typeof window !== "undefined" && recaptchaKey) {
  initializeAppCheck(app, {
    provider: new ReCaptchaV3Provider(recaptchaKey),
    isTokenAutoRefreshEnabled: true,
  });
}

export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app);
export const storage = getStorage(app);
