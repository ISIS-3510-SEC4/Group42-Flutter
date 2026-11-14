// Business question (VV2): at which step do users most frequently abandon the
// meeting planning process?
// Reads the FLUTTER PLANNING_* events from analytics_events (written by
// lib/core/services/analytics_service.dart), groups them by planning attempt
// (metadata.attemptId) and writes the aggregate to
// analytics_results/planning_abandonment_FLUTTER, which the app shows in
// "Abandono de planificación".
// Same setup as meeting_peak_windows.js (firebase-admin + ADC credentials).
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "moviles-9132d"
});

const STEPS = ["details", "vote", "result"];
const STEP_INDEX = { details: 1, vote: 2, result: 3 };
const TYPES = [
  "PLANNING_STEP_STARTED",
  "PLANNING_STEP_COMPLETED",
  "PLANNING_FLOW_ABANDONED",
  "PLANNING_FLOW_COMPLETED"
];

function stepIndexOf(event) {
  const m = event.metadata || {};
  if (Number.isInteger(m.stepIndex)) return m.stepIndex;
  return STEP_INDEX[event.step] || 0;
}

async function main() {
  const db = getFirestore();
  const platform = "FLUTTER";

  const snapshot = await db.collection("analytics_events")
    .where("platform", "==", platform)
    .where("eventType", "in", TYPES)
    .get();

  const attempts = new Map();
  let ignoredEvents = 0;

  for (const document of snapshot.docs) {
    const event = document.data();
    const attemptId = (event.metadata || {}).attemptId;
    if (typeof attemptId !== "string" || !STEPS.includes(event.step)) {
      ignoredEvents++;
      continue;
    }
    const attempt = attempts.get(attemptId) || {
      maxStepIndex: 0,
      end: null,
      abandonStep: null,
      reason: null,
      durationMs: null
    };
    const m = event.metadata || {};
    attempt.maxStepIndex = Math.max(
      attempt.maxStepIndex,
      stepIndexOf(event),
      Number.isInteger(m.maxStepIndex) ? m.maxStepIndex : 0
    );
    if (event.eventType === "PLANNING_FLOW_COMPLETED") {
      attempt.end = "completed";
    } else if (event.eventType === "PLANNING_FLOW_ABANDONED" && attempt.end !== "completed") {
      attempt.end = "abandoned";
      attempt.abandonStep = event.step;
      attempt.reason = typeof m.reason === "string" ? m.reason : "unknown";
      attempt.durationMs = Number.isFinite(event.durationMs) ? event.durationMs : null;
    }
    attempts.set(attemptId, attempt);
  }

  const byStep = {};
  for (const step of STEPS) {
    byStep[step] = { stepIndex: STEP_INDEX[step], reached: 0, abandoned: 0, abandonRate: 0, avgMsBeforeAbandon: null };
  }
  const reasons = {};
  const durations = {};
  let completed = 0;
  let abandoned = 0;
  let openAttempts = 0;

  for (const attempt of attempts.values()) {
    // Attempts without an end event are still in progress (or their end event
    // has not been synced yet): they are reported but not used in the rates.
    if (!attempt.end) {
      openAttempts++;
      continue;
    }
    for (const step of STEPS) {
      if (attempt.maxStepIndex >= STEP_INDEX[step]) byStep[step].reached++;
    }
    if (attempt.end === "completed") {
      completed++;
      continue;
    }
    abandoned++;
    byStep[attempt.abandonStep].abandoned++;
    reasons[attempt.reason] = (reasons[attempt.reason] || 0) + 1;
    if (attempt.durationMs !== null) {
      (durations[attempt.abandonStep] = durations[attempt.abandonStep] || []).push(attempt.durationMs);
    }
  }

  let peakStep = null;
  for (const step of STEPS) {
    const data = byStep[step];
    data.abandonRate = data.reached > 0 ? data.abandoned / data.reached : 0;
    const values = durations[step] || [];
    data.avgMsBeforeAbandon = values.length
      ? Math.round(values.reduce((a, b) => a + b, 0) / values.length)
      : null;
    if (data.abandoned > 0 && (!peakStep || data.abandoned > peakStep.abandoned)) {
      peakStep = { step, abandoned: data.abandoned, abandonRate: data.abandonRate };
    }
  }

  const finished = completed + abandoned;
  const result = {
    businessQuestion:
      "At which step do users most frequently abandon the meeting planning process?",
    metric: "planning_abandonment_by_step",
    platform,
    sampleCount: finished,
    completedAttempts: completed,
    abandonedAttempts: abandoned,
    openAttempts,
    completionRate: finished > 0 ? completed / finished : 0,
    ignoredEvents,
    steps: STEPS,
    byStep,
    abandonReasons: reasons,
    peakAbandonStep: peakStep,
    updatedAt: FieldValue.serverTimestamp()
  };

  await db.collection("analytics_results")
    .doc("planning_abandonment_FLUTTER")
    .set(result);

  console.log("Resultado guardado en analytics_results/planning_abandonment_FLUTTER");
  console.log(JSON.stringify({ sampleCount: finished, openAttempts, ignoredEvents, peakStep, byStep }, null, 2));
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
