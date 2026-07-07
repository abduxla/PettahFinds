import type { NextConfig } from "next";

/**
 * The portal ships as a fully static bundle to Firebase Hosting.
 * There is no Next.js server: all data access goes through the Firebase
 * JS SDK (Firestore rules enforce authorization) and privileged writes go
 * through App-Check-enforced callable Cloud Functions — the same trust
 * model as the PettahFinds mobile app.
 */
const nextConfig: NextConfig = {
  output: "export",
  // Firebase Hosting serves the exported bundle verbatim; next/image
  // optimization needs a server, so images are served as-is (business
  // logos/banners are already client-resized before upload by the app).
  images: { unoptimized: true },
  // Emit /route/index.html paths so Hosting serves deep links directly.
  trailingSlash: true,
};

export default nextConfig;
