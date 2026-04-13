const { onValueWritten } = require("firebase-functions/v2/database");
const { initializeApp }  = require("firebase-admin/app");
const { getMessaging }   = require("firebase-admin/messaging");
const { getDatabase }    = require("firebase-admin/database");

initializeApp();

// ---------------------------------------------------------------------------
// Filters Pi hardware diagnostic strings out of alert reason text.
// These are internal sensor messages (DHT22 failures, GPIO errors) that are
// not user-actionable and should not appear in push notifications.
// ---------------------------------------------------------------------------
function sanitizeReason(reason) {
  const lower = reason.toLowerCase();

  // DHT22 sensor errors → friendly substitute
  if (
    lower.includes("dht") &&
    (lower.includes("stale") || lower.includes("error") ||
     lower.includes("fail")  || lower.includes("no valid") ||
     lower.includes("invalid"))
  ) {
    return "Temperature sensor temporarily unavailable";
  }

  // Raw hardware / Python diagnostic noise → suppress entirely
  if (
    lower.includes("gpio")          ||
    lower.includes("traceback")     ||
    lower.includes("checksum")      ||
    lower.includes("runtimeerror")  ||
    lower.includes("runtime error")
  ) {
    return null; // caller filters nulls out
  }

  return reason;
}

// ---------------------------------------------------------------------------
// Fires every time kennel/alert is updated on Firebase Realtime Database.
// Sends a push notification to the registered iOS device (via FCM → APNs).
// ---------------------------------------------------------------------------
exports.sendAlertNotification = onValueWritten(
  { ref: "/kennel/alert", region: "us-central1" },
  async (event) => {
    const after = event.data.after.val();

    // Only notify on non-normal levels.
    if (!after || after.level === "normal") return;

    // Fetch the device's FCM token saved by the iOS app.
    const db        = getDatabase();
    const tokenSnap = await db.ref("/kennel/fcm_token").get();
    const token     = tokenSnap.val();

    if (!token) {
      console.log("No FCM token registered — skipping notification.");
      return;
    }

    const emoji = {
      warning:   "⚠️",
      stress:    "🔶",
      emergency: "🚨",
    }[after.level] ?? "🐶";

    // Build a human-readable body from the reasons array.
    // Sanitize each reason before joining — Pi diagnostic strings must never
    // reach the user's lock screen verbatim.
    const rawReasons = Array.isArray(after.reasons) ? after.reasons : [];
    const cleanReasons = rawReasons
      .map(sanitizeReason)
      .filter((r) => r !== null && r.trim().length > 0);

    const body = cleanReasons.length > 0
      ? cleanReasons.join(" · ")
      : `Alert level: ${after.level}`;

    await getMessaging().send({
      token,
      notification: {
        title: `${emoji} PuppyCare`,
        body,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
      // Pass the level as data so the app can handle it in the future.
      data: {
        level: after.level,
      },
    });

    console.log(`Notification sent | level=${after.level} | reasons=${body}`);
  }
);
