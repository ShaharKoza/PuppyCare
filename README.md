<h1 align="center">
  <br>
  🐾 PuppyCare
  <br>
</h1>

<h4 align="center">A smart IoT kennel monitoring system for dog owners — live sensor data, behavioral analytics, feeding management, and push alerts, all in one iOS app.</h4>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B-blue?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" />
  <img src="https://img.shields.io/badge/Firebase-Realtime%20DB%20%7C%20FCM-yellow?style=flat-square&logo=firebase" />
  <img src="https://img.shields.io/badge/Hardware-Raspberry%20Pi-red?style=flat-square&logo=raspberry-pi" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" />
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#installation">Installation</a> •
  <a href="#hardware-setup">Hardware Setup</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#resources">Resources</a>
</p>

---

## Overview

**PuppyCare** is a full-stack IoT product combining a Raspberry Pi sensor station with a native iOS app. It gives dog owners real-time visibility into their kennel environment: temperature, humidity, motion, light, sound, and live camera snapshots — all surfaced through an intelligent, design-forward mobile interface.

The system uses **Firebase Realtime Database** as the communication backbone between the Pi and the iPhone, and **Firebase Cloud Messaging** to push critical alerts even when the app is in the background.

> **The problem it solves:** Dog owners who use kennels have no way to know if their dog is too hot, too cold, anxious, or in distress. PuppyCare closes this gap with live environmental monitoring, behavioral pattern analysis, and an intelligent feeding and care management system.

---

## Marketing & Presentation

| Resource | Link |
|----------|------|
| 🎬 Marketing Video | [Watch here]([MARKETING_VIDEO_URL]) |
| 📊 Project Presentation | [View here]([PRESENTATION_URL]) |
| 📖 User Guide | [docs/USER_GUIDE.md](docs/USER_GUIDE.md) |
| 🏗️ Architecture Docs | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| ⚙️ Setup Guide | [docs/SETUP.md](docs/SETUP.md) |

---

## Features

### Live Sensor Dashboard
- Real-time temperature and humidity readings from a DHT22 sensor
- Motion detection via PIR sensor with time-since-last-motion display
- Sound and bark detection with 5-second burst counting
- Light state monitoring (on/off transitions)
- Live kennel presence timer — starts the moment the dog enters, resets on exit

### Smart Alerts System
- Automatic alerts for temperature out of range (customizable warn/critical thresholds)
- Bark detection alerts with sustained-sound escalation
- Motion and light change events
- Alerts history with date-grouped list, filter tabs, and search by type
- Behavioral analytics: peak bark hour, most active period, temperature range summary
- 12-hour bark frequency bar chart

### Camera Integration
- On-demand snapshot capture: the app writes a capture request to Firebase; the Pi takes a photo and uploads the URL back
- Live image displayed in the Dashboard with "Updated at HH:mm" timestamp

### Feeding Management
- Daily schedule with meals, walks, and play sessions
- Per-meal gram tracking and calorie calculation
- AI Food Assistant: type any food name and get a safety assessment (safe / caution / dangerous), explanation, and tips
- Next meal/event badge on each routine row

### Dog Profile
- Breed, sex, age (in months), weight
- Custom temperature alert thresholds (warn high/low, critical high/low)
- Israel-specific vaccine reminders based on age
- Profile photo from the device camera roll

### Push Notifications
- Firebase Cloud Functions (Node.js) deployed to trigger FCM push notifications for any non-normal alert level (warning, stress, emergency)
- Local notifications for scheduled meal and walk reminders

### Onboarding
- First-launch guided setup collecting dog name, breed, sex, age, and weight before showing the main interface

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                    iOS App (SwiftUI)                  │
│                                                      │
│  ┌──────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │Dashboard │  │  Alerts   │  │ Feeding / Routine │  │
│  │ View     │  │ History   │  │     Views         │  │
│  └────┬─────┘  └─────┬─────┘  └────────┬─────────┘  │
│       │              │                 │             │
│  ┌────▼──────────────▼─────────────────▼──────────┐  │
│  │           Core Services Layer                   │  │
│  │  FirebaseService · AlertManager · ProfileStore  │  │
│  │  ReminderManager · FoodAssistantService         │  │
│  └────────────────────┬────────────────────────────┘  │
└───────────────────────│────────────────────────────────┘
                        │ Firebase SDK (Realtime DB)
                        │
         ┌──────────────▼──────────────────────┐
         │        Firebase Realtime Database     │
         │  kennel/dht   · kennel/sound          │
         │  kennel/pir   · kennel/light          │
         │  kennel/alert · kennel/camera         │
         │  kennel/fcm_token                     │
         └──────────┬──────────────┬─────────────┘
                    │              │
         ┌──────────▼──┐   ┌───────▼───────────┐
         │  Raspberry   │   │  Cloud Functions   │
         │  Pi Sensor   │   │  (Node.js / FCM)   │
         │  Station     │   │  Alert → Push notif│
         └─────────────┘   └───────────────────┘
```

**Data flow:**
1. Raspberry Pi reads sensors every few seconds and writes structured JSON to Firebase paths (`kennel/dht`, `kennel/pir`, `kennel/sound`, `kennel/light`, `kennel/alert`)
2. `FirebaseService` (iOS) holds active `.observe(.value)` listeners on each path and updates `@Published var sensorData` on the main actor
3. `AlertManager` receives every sensor update, applies cooldown and threshold logic, and appends `AlertRecord` entries to its persistent store
4. Firebase Cloud Function triggers on `kennel/alert` writes and sends FCM push notifications to the registered device token

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS App | SwiftUI, Combine, `@MainActor` |
| Data persistence | `UserDefaults` (profile), JSON file (alert history) |
| Real-time sync | Firebase Realtime Database SDK |
| Push notifications | Firebase Cloud Messaging (FCM) + APNs |
| Cloud Functions | Node.js 18, Firebase Functions v2 |
| Hardware | Raspberry Pi (Python sensor script) |
| Sensors | DHT22 (temp/humidity), PIR, sound module, light sensor, camera |
| Design system | Custom `AppTheme` with semantic tokens (colors, radii, spacing, typography) |

---

## Installation

### Prerequisites

- Xcode 15.2 or later
- iOS 17+ device or simulator
- A Firebase project with Realtime Database and Cloud Messaging enabled
- A Raspberry Pi running the companion sensor script (see [Hardware Setup](#hardware-setup))

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/ShaharKoza/PuppyCare.git
cd PuppyCare
```

```bash
# 2. Open the project in Xcode
open SmartKennel.xcodeproj
```

**3. Add Firebase configuration**

- Go to your Firebase Console → Project Settings → iOS app
- Download `GoogleService-Info.plist`
- Drag it into the `Resources/` folder in Xcode (check "Copy items if needed")
- This file is excluded from version control for security — never commit it

**4. Install Swift Package dependencies**

Xcode will resolve the Swift Package Manager dependencies automatically on first open:
- `firebase-ios-sdk` (FirebaseDatabase, FirebaseMessaging)

**5. Configure signing**

- Select the `SmartKennel` target → Signing & Capabilities
- Set your Apple Developer team and bundle identifier

**6. Build and run**

Select your target device and press `Cmd+R`.

---

## Hardware Setup

The Raspberry Pi companion script is not included in this repository. It should:

1. Read sensors (DHT22, PIR, sound module, light sensor) at regular intervals
2. Write JSON payloads to the Firebase paths below using the Firebase Admin SDK or REST API
3. Listen to `kennel/camera/capture_request` and trigger a camera snapshot when it changes, then upload the image and write the URL to `kennel/camera/image_url`

**Firebase database paths written by the Pi:**

```
kennel/
  dht/
    temperature: Float
    humidity: Float
    timestamp: String (ISO 8601)
  light/
    light_detected: Boolean
    timestamp: String
  sound/
    sound_active: Boolean
    bark_detected: Boolean
    bark_count_5s: Int
    sustained_sound: Boolean
  pir/
    motion_detected: Boolean
    last_motion: String
    seconds_since_motion: Int
  alert/
    level: "normal" | "warning" | "stress" | "emergency"
    sleeping: Boolean
    puppy_mode: Boolean
    puppy_age: String
    reasons: [String]
    timestamp: String
  camera/
    capture_request: ServerTimestamp (written by iOS app)
    image_url: String (written by Pi after capture)
```

**FCM Token path (written by iOS app):**
```
kennel/fcm_token: String
```

---

## Cloud Functions Deployment

```bash
cd functions
npm install
firebase deploy --only functions
```

The function `sendAlertNotification` triggers on any write to `kennel/alert` where `level !== "normal"` and sends a push notification to the device registered at `kennel/fcm_token`.

---

## Project Structure

```
SmartKennel/
├── App/
│   ├── SmartKennelApp.swift      # App entry point, Firebase init, scene lifecycle
│   ├── AppTheme.swift            # Design system: colors, radii, spacing, typography
│   └── RootView.swift            # Navigation root, tab bar, onboarding gate
│
├── Core/
│   ├── Models.swift              # DogProfile, SensorData, ScheduleItem, dog breed data
│   ├── FirebaseService.swift     # Realtime Database listeners for all sensor paths
│   ├── AlertManager.swift        # Alert records, threshold checks, analytics engine
│   ├── ProfileStore.swift        # Dog profile persistence, threshold sync, reminder scheduling
│   ├── FoodAssistantService.swift# Rule-based food safety lookup + pluggable AI protocol
│   ├── NotificationManager.swift # APNs permission, FCM token registration
│   ├── ReminderManager.swift     # Local UNUserNotification scheduling for routine items
│   ├── SensorHistoryStore.swift  # In-memory ring buffer for sensor chart data
│   └── ImageStorageManager.swift # Profile photo save/load from local storage
│
├── Views/
│   ├── ContentView.swift         # Tab bar container
│   ├── DashboardView.swift       # Live sensor tiles, camera card, kennel timer
│   ├── AlertsHistoryView.swift   # Alert log, analytics, bark chart, filter chips
│   ├── FeedingView.swift         # Routine schedule, meal management, calorie calc
│   ├── FoodAssistantView.swift   # AI food safety assistant chat interface
│   ├── ProfileView.swift         # Dog profile editor, vaccine reminders, thresholds
│   ├── OnboardingView.swift      # First-launch setup flow
│   ├── CameraCardView.swift      # Kennel camera snapshot display
│   └── SensorChartView.swift     # Historical sensor chart
│
├── functions/
│   ├── index.js                  # Firebase Cloud Function: alert → FCM push
│   └── package.json
│
└── Resources/
    └── Assets.xcassets/          # App icon, accent color
```

---

## Environment & Security

| Secret | Where it lives | How to set up |
|--------|---------------|---------------|
| `GoogleService-Info.plist` | `Resources/` — gitignored | Download from Firebase Console |
| Firebase API keys | Inside `GoogleService-Info.plist` | Never commit to version control |
| FCM Server key | Managed by Firebase Admin SDK in Cloud Functions | No manual setup needed |
| Raspberry Pi credentials | On the Pi itself | Use Firebase service account JSON |

---

## Assumptions & Limitations

- **Single dog, single kennel:** The app is designed for one dog profile and one kennel device. Multi-dog support would require namespaced Firebase paths.
- **Single device:** The FCM token is stored as a single value; only the last device to register receives push notifications.
- **Local food assistant:** The AI food assistant uses a local rule-based engine. Plugging in a real LLM requires implementing the `FoodAssistantQuerying` protocol.
- **No offline queue:** If the Pi is offline, the iOS app shows the last known values. There is no local caching of historical sensor data beyond the alert records.
- **Israel-specific vaccine reminders:** The vaccine reminder logic is tuned for Israel's veterinary requirements.

---

## Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| Dashboard shows no data | Firebase not connected or Pi offline | Check `.info/connected` listener; verify Pi is running and writing to DB |
| Push notifications not arriving | FCM token not registered or Cloud Function not deployed | Ensure `NotificationManager.shared.configure()` runs and token is saved to `kennel/fcm_token` |
| Camera snapshot not updating | Pi not listening to `capture_request` | Verify Pi script listens on that path and has write access to `camera/image_url` |
| App crashes on launch | Missing `GoogleService-Info.plist` | Download the file from Firebase Console and add to project |
| Alert thresholds not saving | Profile save debounce window | Wait 500 ms or background the app to flush |

---

## Future Improvements

- [ ] Multi-dog / multi-kennel support with namespaced Firebase paths
- [ ] Historical sensor graphs (24h, 7d, 30d) backed by Firebase or InfluxDB
- [ ] AI-powered feeding recommendations using weight, breed, and activity data
- [ ] Integration with a real LLM for the Food Assistant (Claude / GPT-4)
- [ ] Apple Watch complication for kennel status at a glance
- [ ] Widget extension for the Lock Screen / Home Screen
- [ ] Export alert history as CSV or PDF report
- [ ] Shared access for multiple family members

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">Built with SwiftUI · Firebase · Raspberry Pi</p>
