// Business question (type 2): how many recommendations do users view
// before selecting one? Reads FLUTTER events from analytics_events and
// writes the metric to analytics_results.
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
    .get();

  // One selection per requestId; earlier duplicates are ignored.
  const selections = new Map();
  let ignoredEvents = 0;

  for (const document of snapshot.docs) {
    const event = document.data();
    if (event.eventType !== "RECOMMENDATION_SELECTED") continue;

    const metadata = event.metadata || {};
    const valid =
      typeof metadata.requestId === "string" &&
      metadata.requestId.length > 0 &&
      Number.isSafeInteger(metadata.viewedCount) &&
      metadata.viewedCount >= 1;

    if (!valid || selections.has(metadata.requestId)) {
      ignoredEvents++;
      continue;
    }
    selections.set(metadata.requestId, metadata.viewedCount);
  }

  const counts = [...selections.values()];
  const sampleCount = counts.length;
  const totalViewed = counts.reduce((sum, count) => sum + count, 0);
  const averageViewed = sampleCount === 0 ? null : totalViewed / sampleCount;

  const result = {
    businessQuestion:
      "How many meeting point recommendations do users usually review before selecting one?",
    metric: "recommendations_viewed_before_selection",
    platform,
    sampleCount,
    totalViewed,
    averageViewed,
    minViewed: sampleCount === 0 ? null : Math.min(...counts),
    maxViewed: sampleCount === 0 ? null : Math.max(...counts),
    ignoredEvents,
    updatedAt: FieldValue.serverTimestamp()
  };

  await db.collection("analytics_results")
    .doc("recommendations_viewed_before_selection_FLUTTER")
    .set(result);

  console.log("Resultado guardado en analytics_results");
  console.log({ sampleCount, averageViewed, ignoredEvents });
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
