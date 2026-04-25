# PuppyCare — Setup & Installation Guide

This guide covers everything needed to build and run PuppyCare locally, configure Firebase, and deploy the Cloud Function.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Xcode | 15.2+ | Available on the Mac App Store |
| iOS target | 16.0+ | Device or simulator |
| Firebase project | Any plan | Spark (free) tier is sufficient |
| Node.js | 20+ | Required for Cloud Functions deployment |
| Firebase CLI | Latest | `npm install -g firebase-tools` |

---

## 1. Clone the Repository

```bash
git clone https://github.com/ShaharKoza/PuppyCare.git
cd PuppyCare
```

---

## 2. Firebase Project Setup

### 2a. Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add Project**, name it (e.g. `PuppyCare`), follow the wizard
3. In the console, go to **Build → Realtime Database** → **Create Database**
   - Choose a region close to you
   - Start in **test mode** (you can add security rules later)
4. Go to **Build → Cloud Messaging** — no action needed yet, it enables automatically

### 2b. Register the iOS app

1. In the Firebase Console, click the gear icon → **Project Settings**
2. Under **Your apps**, click the iOS icon (+)
3. Enter the bundle ID: `com.yourname.SmartKennel` (match what you set in Xcode)
4. Download `GoogleService-Info.plist`

### 2c. Add GoogleService-Info.plist to Xcode

1. Open `SmartKennel.xcodeproj` in Xcode
2. In the Project Navigator, find the `Resources/` group
3. Drag `GoogleService-Info.plist` into it
4. In the dialog, check **"Copy items if needed"** and select the `SmartKennel` target
5. Verify the file appears in the `Resources/` group — **never commit this file**

> The `.gitignore` already excludes `GoogleService-Info.plist`.

---

## 3. Xcode Configuration

### 3a. Swift Package Dependencies

Open the project. Xcode will automatically resolve SPM packages defined in `Package.resolved`. This includes:
- `firebase-ios-sdk` (FirebaseDatabase, FirebaseMessaging)

If packages do not resolve automatically: **File → Packages → Resolve Package Versions**

### 3b. Signing

1. Select the `SmartKennel` target in the Project Navigator
2. Go to **Signing & Capabilities**
3. Set your **Team** (Apple Developer account)
4. Set a unique **Bundle Identifier** — must match what you registered in Firebase

### 3c. Push Notification Capability

1. Still in Signing & Capabilities, click **+ Capability**
2. Add **Push Notifications**
3. Add **Background Modes** → check **Remote notifications**

### 3d. Upload APNs Key to Firebase

Firebase Cloud Messaging needs an APNs authentication key to deliver push notifications:

1. Go to [Apple Developer → Certificates, IDs & Profiles → Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Create a key with **Apple Push Notifications service (APNs)** enabled
3. Download the `.p8` file and note the **Key ID** and your **Team ID**
4. In Firebase Console → Project Settings → Cloud Messaging → Apple app configuration
5. Upload the `.p8` file, enter Key ID and Team ID

---

## 4. Build and Run

```bash
open SmartKennel.xcodeproj
```

Select your target device (or a simulator) and press `Cmd+R`.

> Push notifications do not work on the simulator. Use a physical device to test FCM.

---

## 5. Cloud Functions Deployment

The Cloud Function sends push notifications when the kennel alert level changes.

```bash
# Authenticate with Firebase
firebase login

# Navigate to the functions directory
cd functions

# Install dependencies
npm install

# Deploy
firebase deploy --only functions --project YOUR_PROJECT_ID
```

After deployment, the function `sendAlertNotification` appears in the Firebase Console under **Functions**.

To verify it is working:
1. Open your Firebase Realtime Database in the console
2. Manually write `{ "level": "warning", "reasons": ["Test"] }` to `kennel/alert`
3. Your device should receive a push notification within a few seconds

---

## 6. Firebase Security Rules (recommended)

Replace the default permissive rules with these before going to production:

```json
{
  "rules": {
    "kennel": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

For a simpler setup without authentication (personal/home use only):

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

> Never use permissive rules on a public-facing Firebase project.

---

## 7. Raspberry Pi Setup

The Pi sensor script is not included in this repository. It must:

1. Write sensor readings to Firebase paths using the Firebase Admin Python SDK or REST API:
   ```
   kennel/sensors  → { temperature, humidity, motion, sleeping, light ("light"|"dark"), motion_streak, sound_streak, timestamp }
   kennel/sound    → { sound_active, bark_detected, bark_count_5s, sustained_sound }
   kennel/alert    → { level, sleeping, puppy_mode, puppy_age, reasons, timestamp } (deduplicated)
   kennel/heartbeat → { timestamp, epoch_ms } (every cycle — iOS surfaces "offline" if stale)
   kennel/diagnostics → { uptime, last_loop, sensor health }
   ```

2. Listen on `kennel/camera/capture_request` for changes, and when it fires:
   - Capture a photo
   - Upload to a public URL (Firebase Storage, Cloudinary, or any hosted URL)
   - Write the URL string to `kennel/camera/image_url`

3. Use a Firebase service account JSON for authentication on the Pi.

---

## 8. Environment Variables Reference

| Variable | Location | Purpose |
|----------|----------|---------|
| Firebase config | `GoogleService-Info.plist` | All Firebase connection details |
| APNs key | Firebase Console upload | Push notification delivery |
| Pi service account | Pi filesystem | Firebase write access from Pi |

None of these values should ever be committed to the repository.

---

## 9. Troubleshooting Build Issues

**"No such module 'FirebaseDatabase'"**
Run **File → Packages → Reset Package Caches**, then **Resolve Package Versions**.

**Build fails with "GoogleService-Info.plist not found"**
The file was not added to the Xcode project. Follow step 2c above.

**Push notifications not received on device**
- Verify the APNs key is uploaded in Firebase Console
- Verify Push Notifications capability is added in Xcode
- Open the app once after install — this registers the FCM token
- Check Firebase Console → Functions → Logs for errors

**Firebase Realtime Database returns "Permission denied"**
Your security rules are not allowing reads/writes. Update the rules to allow access (see step 6).
