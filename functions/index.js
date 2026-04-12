const { onValueWritten } = require("firebase-functions/v2/database");
const { initializeApp }  = require("firebase-admin/app");
const { getMessaging }   = require("firebase-admin/messaging");
const { getDatabase }    = require("firebase-admin/database");

initializeApp();

// Fires every time kennel/alert is updated on Firebase Realtime Database.
// Sends a push notification to the registered iOS device (via FCM → APNs).
exports.sendAlertNotification = onValueWritten(
  { ref: "/kennel/alert", region: "us-central1" },
  async (event) => {
    const after = event.data.after.val();

    // Only notify on non-normal levels.
    if (!after || after.level === "normal") return;

    // Fetch the device's FCM token saved by the iOS app.
    const db       = getDatabase();
    const tokenSnap = await db.ref("/kennel/fcm_token").get();
    const token    = tokenSnap.val();

    if (!token) {
      console.log("No FCM token registered — skipping notification.");
      return;
    }

    const emoji = {
      warning:   "⚠️",
      stress:    "🔶",
      emergency: "🚨",
    }[after.level] ?? "🐶";

    // Build a human-readable body from the reasons array, fallback to level.
    const reasons = Array.isArray(after.reasons) ? after.reasons : [];
    const body    = reasons.length > 0
      ? reasons.join(" · ")
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
