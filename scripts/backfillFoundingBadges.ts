/**
 * PettahFinds — one-time Founding-50 badge backfill.
 *
 * The onBusinessCreated trigger stamps `foundingMember: true` +
 * `foundingRank` on new signups until 50 badges exist (transactional
 * against counters/founding). This script awards the badge RETROACTIVELY
 * to businesses that signed up before the feature shipped:
 *
 *   - orders ALL businesses by createdAt ascending (true signup order),
 *   - stamps the first 50 that aren't already stamped,
 *   - seeds counters/founding with the final count so the live trigger
 *     continues the sequence from the right rank.
 *
 * Idempotent:
 *   Already-stamped businesses keep their existing rank (never re-ranked),
 *   and the counter is written as an absolute value. Safe to re-run.
 *
 * Safety — DRY RUN BY DEFAULT:
 *   With no flags it only reports what WOULD change and writes nothing.
 *   Pass --commit to actually write. Not wired into any deploy or CI.
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/service-account.json
 *   cd functions
 *   npx tsx ../scripts/backfillFoundingBadges.ts            # dry run
 *   npx tsx ../scripts/backfillFoundingBadges.ts --commit   # apply
 */

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const args = new Set(process.argv.slice(2));
const COMMIT = args.has("--commit");

const FOUNDING_LIMIT = 50;

async function main(): Promise<void> {
  initializeApp({ credential: applicationDefault() });
  const db = getFirestore();

  console.log(
    COMMIT ? "== COMMIT MODE — writing changes ==" : "== DRY RUN — no writes ==",
  );

  // All businesses in true signup order. Directory-scale collection; a
  // single ordered read is fine (createdAt exists on every doc).
  const snap = await db
    .collection("businesses")
    .orderBy("createdAt", "asc")
    .get();
  console.log(`businesses found: ${snap.size}`);

  // Existing stamps keep their ranks; find the highest one so new stamps
  // continue the sequence without collisions.
  let stamped = 0;
  let maxRank = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.foundingMember === true) {
      stamped++;
      if (typeof d.foundingRank === "number" && d.foundingRank > maxRank) {
        maxRank = d.foundingRank;
      }
    }
  }
  console.log(`already stamped: ${stamped} (highest rank ${maxRank})`);

  let nextRank = Math.max(stamped, maxRank);
  let awarded = 0;
  const batch = db.batch();

  for (const doc of snap.docs) {
    if (stamped + awarded >= FOUNDING_LIMIT) break;
    const d = doc.data();
    if (d.foundingMember === true) continue;
    nextRank++;
    awarded++;
    console.log(
      `  #${nextRank}  ${doc.id}  "${(d.businessName ?? "").slice(0, 40)}"  ` +
      `created ${d.createdAt?.toDate?.()?.toISOString?.()?.slice(0, 10) ?? "?"}`,
    );
    if (COMMIT) {
      batch.update(doc.ref, {
        foundingMember: true,
        foundingRank: nextRank,
      });
    }
  }

  const total = stamped + awarded;
  console.log(
    `${COMMIT ? "stamping" : "would stamp"} ${awarded} new founding ` +
    `businesses (total ${total}/${FOUNDING_LIMIT})`,
  );

  if (COMMIT) {
    // Seed the live trigger's counter with the absolute total so it
    // continues the sequence (or stops, if the cap is reached).
    batch.set(
      db.collection("counters").doc("founding"),
      { count: total },
      { merge: true },
    );
    await batch.commit();
    console.log("done — counter seeded to", total);
  } else {
    console.log("dry run complete — re-run with --commit to apply");
  }
}

main().catch((err) => {
  console.error("backfill failed:", err);
  process.exit(1);
});
