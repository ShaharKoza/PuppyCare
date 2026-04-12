# PuppyCare — Architecture & Technical Reference

This document covers the system architecture, component responsibilities, data models, and design decisions for the PuppyCare iOS app.

---

## System Overview

PuppyCare is a two-component IoT system:

1. **Raspberry Pi sensor station** — reads physical sensors and writes structured JSON to Firebase Realtime Database. It also listens for camera capture requests from the iOS app.
2. **iOS app (SwiftUI)** — streams live data from Firebase, processes it through a local alert engine, manages the dog profile and daily routine, and renders a native mobile UI.

A **Firebase Cloud Function** (Node.js) bridges the two: it triggers on alert-level writes and delivers FCM push notifications to the registered device.

---

## iOS App Architecture

The app follows a **single-source-of-truth, reactive** pattern using Combine and SwiftUI's `@Published` / `@ObservedObject` / `@EnvironmentObject` system.

```
┌─────────────────────────────────────────────────────────────────┐
│                          SwiftUI Views                           │
│  DashboardView · AlertsHistoryView · FeedingView                │
│  FoodAssistantView · ProfileView · OnboardingView               │
└───────┬───────────────────┬────────────────────┬────────────────┘
        │ @EnvironmentObject │ @ObservedObject     │ @ObservedObject
        ▼                   ▼                     ▼
 ┌─────────────┐   ┌──────────────────┐   ┌──────────────────────┐
 │ ProfileStore│   │  FirebaseService │   │    AlertManager      │
 │ @MainActor  │   │  @MainActor      │   │    @MainActor        │
 │ @Published  │   │  @Published      │   │    @Published        │
 │  profile    │   │  sensorData      │   │    records           │
 │             │   │  isConnected     │   │    unreadCount       │
 │             │   │  cameraImageURL  │   │    analytics         │
 └──────┬──────┘   └───────┬──────────┘   └──────────┬───────────┘
        │                  │                          │
        │ syncThresholds   │ processSensorUpdate      │ append/prune
        └──────────────────┴──────────────────────────┘
```

All three core objects are `@MainActor` singletons (or environment-injected), ensuring all state mutations occur on the main thread without manual dispatch.

---

## Component Breakdown

### `SmartKennelApp.swift`
Entry point. Initializes Firebase, configures `NotificationManager`, injects `ProfileStore` as an environment object, and flushes the profile save on app background/inactive transitions.

### `RootView.swift`
Acts as the navigation root. Shows `OnboardingView` if `profile.hasCompletedOnboarding` is false; otherwise shows the tab bar container (`ContentView`).

### `AppTheme.swift`
A centralized design token namespace. All views reference `AppTheme` for colors, corner radii, spacing, and typography — never hardcoded values. This makes global redesigns a single-file change.

Key design decisions:
- `cardStyle()` — a `ViewModifier` that applies `cardFill` background + `softBorder` stroke + `softShadow` drop shadow consistently to every card surface
- Semantic naming (`warmTile` vs `cardFill`) separates intent from value

---

### `FirebaseService.swift`
Singleton that holds all active Realtime Database listeners. Responsibilities:

- Maintains one `DatabaseHandle` per sensor path (`kennel/sensors`, `kennel/sound`, `kennel/alert`, `kennel/camera`); `kennel/sensors` is the primary consolidated snapshot written by the Pi every ~5 s
- Merges partial updates from independent paths into a single `SensorData` struct on `@Published var sensorData`
- Guards against duplicate listeners with `isListening` flag and `startListening()` / `stopListening()` API
- Writes to `kennel/fcm_token` (FCM registration), `kennel/camera/capture_request` (snapshot trigger)
- All Firebase callbacks use `Task { @MainActor in ... }` to hop back to the main actor safely

**Why separate listeners per path?** The Pi writes sensors independently and asynchronously. Merging them at the Firebase level would require a single consolidated write which creates coupling on the hardware side. Separate listeners allow the Pi to be simple and the iOS app to handle assembly.

---

### `AlertManager.swift`

The local alert processing engine. It receives every `SensorData` update from `FirebaseService` and decides whether to create a new `AlertRecord`.

**Cooldown system:** Each alert type has a minimum interval between consecutive alerts to prevent flooding:

| Type | Cooldown |
|------|---------|
| Temperature | 5 minutes |
| Bark/Sound | 1 minute |
| Motion | 5 minutes |
| Light | 5 minutes |

**Threshold logic (temperature):**
```
temp > criticalHigh → AlertSeverity.critical, title: "Kennel overheating"
temp > warnHigh     → AlertSeverity.warning,  title: "Kennel getting warm"
temp < criticalLow  → AlertSeverity.critical, title: "Kennel too cold"
temp < warnLow      → AlertSeverity.warning,  title: "Kennel getting cold"
```

Thresholds are live-updated by `ProfileStore.syncThresholds()` whenever the user changes them in the Profile screen.

**Edge-triggered motion and light:** The first sensor update is used to establish baseline values. Subsequent motion/light alerts only fire on *changes* (false → true for motion, any transition for light).

**Persistence:** Records are saved to `Documents/alert_history.json` using a debounced `PassthroughSubject` that coalesces rapid successive writes into a single disk write 500 ms later.

**Pruning:** Records older than 30 days are pruned on every append. The in-memory cap is 500 records.

**`SensorAnalytics`:** A value-type computed over `[AlertRecord]` that derives all analytics (barks by hour, active minutes, temperature range, behavior insights). No mutable state — recalculated on every access.

---

### `ProfileStore.swift`

Manages the `DogProfile` value type and coordinates three side effects on profile changes:

1. **Auto-save** — debounced 500ms save to `UserDefaults` on any profile change
2. **Threshold sync** — calls `AlertManager.shared.updateThresholds(...)` whenever temperature threshold fields change
3. **Reminder scheduling** — calls `ReminderManager.shared.scheduleAllReminders(profile:)` whenever the profile changes

**Kennel session tracking:** A Combine publisher on `profile.isInKennel` stamps `profile.kennelSessionStart = Date()` on entry and `nil` on exit. Crucially, the guard `kennelSessionStart == nil` was *removed* so that toggling off-then-on always gives a fresh timestamp, not an accumulated one.

**`normalizeProfileIfNeeded()`:** Runs on every launch. Ensures string fields have valid defaults, repairs stale kennel session state (e.g. after a crash), and runs the one-time migration from legacy `mealsPerDay`/`walkTimes` fields into the `scheduleItems` array.

---

### `FoodAssistantService.swift`

Implements a `FoodAssistantQuerying` protocol with a local rule-based lookup table covering common foods and their dog-safety status. The protocol design means the entire service can be swapped for a real LLM backend (Claude, GPT-4) without changing any view code.

```swift
protocol FoodAssistantQuerying {
    func query(_ question: String) async -> FoodAssistantResult
}
```

---

### `ReminderManager.swift`

Wraps `UNUserNotificationCenter` to schedule local notifications for each `ScheduleItem` in the dog's routine. Called by `ProfileStore` whenever the profile (and therefore the schedule) changes. Cancels all existing notifications before rescheduling.

### `SensorHistoryStore.swift`

An in-memory ring buffer that stores recent temperature and humidity readings. Used by `SensorChartView` to render historical trend lines.

### `ImageStorageManager.swift`

Handles saving and loading the profile photo to the app's local `Documents` directory as a JPEG. The `DogProfile` stores only the filename; the image is loaded separately via this manager.

---

## Data Models

### `DogProfile`
Codable value type stored in `UserDefaults`. Key fields:

| Field | Type | Purpose |
|-------|------|---------|
| `name`, `breed`, `sex` | String | Identity |
| `ageMonths`, `weightKg` | String | Used for calorie and vaccine calculations |
| `isInKennel` | Bool | Drives presence timer |
| `kennelSessionStart` | Date? | Start time for the live timer |
| `scheduleItems` | [ScheduleItem] | Source of truth for daily routine |
| `tempWarnHigh/Low`, `tempCriticalHigh/Low` | Double | Alert thresholds |
| `foodCaloriesPer100g` | String | Used in calorie calculator |

Custom `Decodable` init uses safe defaults for all newer fields so that old saved data decodes cleanly without crashing.

### `SensorData`
A simple struct (not `Codable`) that aggregates the latest reading from all Firebase paths. Rebuilt on the main actor each time a listener fires.

### `AlertRecord`
`Codable`, `Identifiable`. Persisted to disk. Contains: type, severity, title, detail, optional sensor value and unit, timestamp, and read state.

### `ScheduleItem`
`Codable`, `Identifiable`. Represents a single daily routine event (meal, walk, or play). Stores type, time as `"HH:mm"` string, label, and optional grams (meals) or durationMinutes (play).

---

## Firebase Database Structure

```
kennel/
  sensors/       ← PRIMARY: written by Pi every ~5 s; iOS app reads here for all live tiles
                    temperature, humidity, light (String), motion (Bool), sound (Bool),
                    sleeping (Bool), motion_streak, sound_streak, timestamp (HH:MM:SS)
  sound/         ← Written by Pi bark-detection loop: sound_active, bark_detected,
                    bark_count_5s, sustained_sound
  alert/         ← Written by Pi: level, sleeping, puppy_mode, puppy_age, reasons, timestamp
  alerts/        ← Written by Pi: push-appended list of non-normal alert events (feed)
  dht/           ← Written by Pi: temperature, humidity, timestamp (detail path)
  light/         ← Written by Pi: light_detected, timestamp (detail path)
  pir/           ← Written by Pi: motion_detected, last_motion, seconds_since_motion
  camera/
    capture_request  ← Written by iOS app (ServerValue.timestamp())
    image_url        ← Written by Pi after capture
  fcm_token      ← Written by iOS app on FCM registration
```

---

## Cloud Function

`functions/index.js` exports a single function `sendAlertNotification` triggered on `onValueWritten` at `/kennel/alert`.

Logic:
1. Read `after.level` — skip if `"normal"`
2. Fetch `kennel/fcm_token` — skip if absent
3. Compose notification title from level emoji + `"PuppyCare"`, body from `reasons` array (joined by ` · `) or fallback to level string
4. Send via `getMessaging().send()` with APNs sound and badge

The function runs in `us-central1`. Deploy with `firebase deploy --only functions`.

---

## Threading Model

All Firebase callbacks arrive on background threads. Every callback in `FirebaseService` uses:

```swift
Task { @MainActor [weak self] in
    // safe to mutate @Published properties here
}
```

`AlertManager` and `ProfileStore` are both `@MainActor` classes. `@Published` mutations in these classes are always on the main thread, making them safe to observe directly from SwiftUI views.

---

## Design System

`AppTheme` defines all visual constants. Views never hardcode colors, radii, or spacing.

| Token | Value | Usage |
|-------|-------|-------|
| `accentBrown` | RGB(176,126,84) | Primary brand color, buttons, icons |
| `cardFill` | `.systemBackground` | Card surfaces |
| `warmTile` | `.secondarySystemBackground` | Tile backgrounds, filter chips |
| `pageBackground` | `.systemGroupedBackground` | Page backgrounds |
| `cardRadius` | 22pt | Card corner radius |
| `tileRadius` | 18pt | Smaller tile corner radius |
| `sectionSpacing` | 14pt | Vertical spacing between sections |
| `horizontalPadding` | 18pt | Left/right content insets |

`cardStyle()` view modifier bundles `cardFill` + `softBorder` (1pt stroke) + `softShadow` (radius 10, y 4) into a single call.

---

## Known Limitations

- **No unit tests for UI flows** — `SmartKennelTests.swift` and `SmartKennelUITests.swift` are scaffolding only
- **Single-instance singletons** — `FirebaseService.shared`, `AlertManager.shared` make dependency injection for tests harder
- **Food assistant is rule-based** — does not call any external API; results are static
- **No retry logic** for Firebase write failures (FCM token, capture request)
