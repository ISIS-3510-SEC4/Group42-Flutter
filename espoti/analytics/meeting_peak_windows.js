// Business question (type 4): what are the peak days and time windows during
// which groups organize meetings, broken down by transit mode?
// Reads FLUTTER MEETING_CREATED events from analytics_events and writes the
// aggregates to analytics_results/meeting_peak_windows_FLUTTER.
// Same setup as recommendation_reviews.js (firebase-admin + ADC credentials).
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "moviles-9132d"
});

const DAYS = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"];
const WINDOWS = ["EARLY_MORNING", "MORNING", "MIDDAY", "AFTERNOON", "EVENING", "NIGHT"];

function increment(target, ...keys) {
  let node = target;
  for (let i = 0; i < keys.length - 1; i++) {
    node[keys[i]] = node[keys[i]] || {};
    node = node[keys[i]];
  }
  const last = keys[keys.length - 1];
  node[last] = (node[last] || 0) + 1;
}

function peak(counts) {
  let best = null;
  for (const [key, value] of Object.entries(counts || {})) {
    if (!best || value > best.count) best = { key, count: value };
  }
  return best;
}

async function main() {
  const db = getFirestore();
  const platform = "FLUTTER";

  const snapshot = await db.collection("analytics_events")
    .where("platform", "==", platform)
    .where("eventType", "==", "MEETING_CREATED")
    .get();

  const seenMeetings = new Set();
  const byMode = {};
  let ignoredEvents = 0;

  for (const document of snapshot.docs) {
    const event = document.data();
    const m = event.metadata || {};
    const valid =
      typeof event.meetingId === "string" &&
      DAYS.includes(m.createdDayOfWeek) &&
      WINDOWS.includes(m.createdTimeWindow) &&
      typeof m.transitMode === "string";

    // One event per meeting (doc ids are already deterministic; this is a guard).
    if (!valid || seenMeetings.has(event.meetingId)) {
      ignoredEvents++;
      continue;
    }
    seenMeetings.add(event.meetingId);

    const mode = m.transitMode;
    increment(byMode, mode, "total");
    increment(byMode, mode, "createdByDay", m.createdDayOfWeek);
    increment(byMode, mode, "createdByWindow", m.createdTimeWindow);
    increment(byMode, mode, "createdByDayAndWindow", `${m.createdDayOfWeek}_${m.createdTimeWindow}`);
    if (DAYS.includes(m.scheduledDayOfWeek) && WINDOWS.includes(m.scheduledTimeWindow)) {
      increment(byMode, mode, "scheduledByDay", m.scheduledDayOfWeek);
      increment(byMode, mode, "scheduledByWindow", m.scheduledTimeWindow);
    }
  }

  const peaks = {};
  for (const [mode, data] of Object.entries(byMode)) {
    peaks[mode] = {
      peakCreatedDay: peak(data.createdByDay),
      peakCreatedWindow: peak(data.createdByWindow),
      peakCreatedDayAndWindow: peak(data.createdByDayAndWindow),
      peakScheduledDay: peak(data.scheduledByDay),
      peakScheduledWindow: peak(data.scheduledByWindow)
    };
  }

  const result = {
    businessQuestion:
      "What are the peak days and time windows during which groups organize meetings, broken down by transit mode?",
    metric: "meeting_peak_windows_by_transit_mode",
    platform,
    sampleCount: seenMeetings.size,
    ignoredEvents,
    timeWindows: {
      EARLY_MORNING: "05-08", MORNING: "08-12", MIDDAY: "12-14",
      AFTERNOON: "14-18", EVENING: "18-22", NIGHT: "22-05"
    },
    byTransitMode: byMode,
    peaks,
    updatedAt: FieldValue.serverTimestamp()
  };

  await db.collection("analytics_results")
    .doc("meeting_peak_windows_FLUTTER")
    .set(result);

  console.log("Resultado guardado en analytics_results");
  console.log(JSON.stringify({ sampleCount: seenMeetings.size, ignoredEvents, peaks }, null, 2));
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
