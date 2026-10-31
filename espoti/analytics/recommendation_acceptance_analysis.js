// Business question (type 5): How do user's location preferences and interaction
// patterns affect the acceptance rate of meeting point recommendations?
// Reads FLUTTER events from analytics_events and writes aggregated results to
// analytics_results/bq5_recommendation_acceptance_FLUTTER.
// Setup: firebase-admin + ADC / service account credentials.

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "moviles-9132d"
});

function calculateRate(accepted, total) {
  if (!total || total === 0) return 0.0;
  return Number(((accepted / total) * 100).toFixed(1));
}

async function main() {
  const db = getFirestore();
  const platform = "FLUTTER";

  console.log("Fetching BQ5 analytics events for platform:", platform);

  const snapshot = await db.collection("analytics_events")
    .where("platform", "==", platform)
    .where("eventType", "in", ["RECOMMENDATION_DECISION", "RECOMMENDATION_SELECTED"])
    .get();

  console.log(`Found ${snapshot.size} candidate event(s)`);

  let totalDecisions = 0;
  let totalAccepted = 0;
  let totalRejected = 0;

  const prefStats = {}; // { prefName: { total, accepted } }
  const patternStats = {}; // { pattern: { total, accepted } }
  const categoryStats = {}; // { category: { total, accepted } }

  let distanceSumAccepted = 0;
  let countDistanceAccepted = 0;
  let distanceSumRejected = 0;
  let countDistanceRejected = 0;

  for (const doc of snapshot.docs) {
    const event = doc.data();
    const meta = event.metadata || {};

    const isAccepted = meta.accepted === true || event.eventType === "RECOMMENDATION_SELECTED";
    totalDecisions++;
    if (isAccepted) {
      totalAccepted++;
    } else {
      totalRejected++;
    }

    // 1. Location Preferences Analysis
    const prefs = Array.isArray(meta.locationPreferences) ? meta.locationPreferences : [];
    for (const p of prefs) {
      const pKey = String(p).trim();
      if (!pKey) continue;
      prefStats[pKey] = prefStats[pKey] || { total: 0, accepted: 0 };
      prefStats[pKey].total++;
      if (isAccepted) prefStats[pKey].accepted++;
    }

    // 2. Interaction Pattern Analysis
    const pattern = meta.interactionPattern || "DIRECT_SELECT";
    patternStats[pattern] = patternStats[pattern] || { total: 0, accepted: 0 };
    patternStats[pattern].total++;
    if (isAccepted) patternStats[pattern].accepted++;

    // 3. Category Breakdown
    const cat = meta.placeCategory || "General";
    categoryStats[cat] = categoryStats[cat] || { total: 0, accepted: 0 };
    categoryStats[cat].total++;
    if (isAccepted) categoryStats[cat].accepted++;

    // 4. Distances
    const dist = Number(meta.distanceMeters);
    if (!isNaN(dist) && dist > 0) {
      if (isAccepted) {
        distanceSumAccepted += dist;
        countDistanceAccepted++;
      } else {
        distanceSumRejected += dist;
        countDistanceRejected++;
      }
    }
  }

  // Format preference breakdown
  const byPreference = {};
  for (const [p, stats] of Object.entries(prefStats)) {
    byPreference[p] = {
      total: stats.total,
      accepted: stats.accepted,
      rate: calculateRate(stats.accepted, stats.total)
    };
  }

  // Format interaction pattern breakdown
  const byInteractionPattern = {};
  for (const [pat, stats] of Object.entries(patternStats)) {
    byInteractionPattern[pat] = {
      total: stats.total,
      accepted: stats.accepted,
      rate: calculateRate(stats.accepted, stats.total)
    };
  }

  // Format category breakdown
  const byCategory = {};
  for (const [cat, stats] of Object.entries(categoryStats)) {
    byCategory[cat] = {
      total: stats.total,
      accepted: stats.accepted,
      rate: calculateRate(stats.accepted, stats.total)
    };
  }

  const overallRate = calculateRate(totalAccepted, totalDecisions);
  const avgDistanceAcceptedMeters = countDistanceAccepted > 0
    ? Math.round(distanceSumAccepted / countDistanceAccepted)
    : 0;
  const avgDistanceRejectedMeters = countDistanceRejected > 0
    ? Math.round(distanceSumRejected / countDistanceRejected)
    : 0;

  const result = {
    question: "How do user's location preferences and interaction patterns affect the acceptance rate of meeting point recommendations?",
    platform,
    calculatedAt: FieldValue.serverTimestamp(),
    totalDecisions,
    totalAccepted,
    totalRejected,
    overallAcceptanceRate: overallRate,
    byPreference,
    byInteractionPattern,
    byCategory,
    distanceMetrics: {
      avgDistanceAcceptedMeters,
      avgDistanceRejectedMeters
    }
  };

  console.log("Analysis Summary:", {
    totalDecisions,
    totalAccepted,
    overallAcceptanceRate: `${overallRate}%`,
    preferencesCount: Object.keys(byPreference).length,
    patternsCount: Object.keys(byInteractionPattern).length
  });

  const targetDoc = db.collection("analytics_results").doc("bq5_recommendation_acceptance_FLUTTER");
  await targetDoc.set(result);
  console.log("Saved results to analytics_results/bq5_recommendation_acceptance_FLUTTER");
}

main().catch(err => {
  console.error("Error executing BQ5 analysis:", err);
  process.exit(1);
});
