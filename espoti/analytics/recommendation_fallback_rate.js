// Business question (type 1): what percentage of meeting point recommendation
// requests are served with fallback data instead of live data? Reads FLUTTER
// events from analytics_events and writes the metric to analytics_results.
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "moviles-9132d"
});

async function main() {
  const db = getFirestore();
  const platform = "FLUTTER";

  const snapshot = await db.collection("analytics_events")
    .where("platform", "==", platform)
    .where("eventType", "==", "RECOMMENDATION_LOADED")
    .get();

  let totalRequests = 0;
  let fallbackRequests = 0;
  const byFallback = {};

  for (const document of snapshot.docs) {
    const fallbacks = (document.data().metadata || {}).fallbacks;
    if (!Array.isArray(fallbacks)) continue;

    totalRequests++;
    if (fallbacks.length > 0) fallbackRequests++;
    for (const fallback of fallbacks) {
      byFallback[fallback] = (byFallback[fallback] || 0) + 1;
    }
  }

  const fallbackRate =
    totalRequests === 0 ? null : (fallbackRequests / totalRequests) * 100;

  const result = {
    businessQuestion:
      "What percentage of meeting point recommendation requests are served with fallback data instead of live data?",
    metric: "recommendation_fallback_rate",
    platform,
    totalRequests,
    fallbackRequests,
    fallbackRate,
    byFallback,
    updatedAt: FieldValue.serverTimestamp()
  };

  await db.collection("analytics_results")
    .doc("recommendation_fallback_rate_FLUTTER")
    .set(result);

  console.log("Resultado guardado en analytics_results");
  console.log({ totalRequests, fallbackRequests, fallbackRate, byFallback });
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
