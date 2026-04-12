# PuppyCare — User Guide

**Version 1.0 · iOS 16+**

Welcome to PuppyCare — your dog's smart kennel companion. This guide walks you through everything you need to get started and make the most of every feature.

---

## Table of Contents

1. [What is PuppyCare?](#1-what-is-puppycare)
2. [Requirements](#2-requirements)
3. [First Launch — Setting Up Your Dog's Profile](#3-first-launch)
4. [The Dashboard](#4-the-dashboard)
5. [Alerts History](#5-alerts-history)
6. [Feeding & Routine](#6-feeding--routine)
7. [Food Assistant](#7-food-assistant)
8. [Profile & Settings](#8-profile--settings)
9. [Push Notifications](#9-push-notifications)
10. [Frequently Asked Questions](#10-frequently-asked-questions)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. What is PuppyCare?

PuppyCare connects your iPhone to a Raspberry Pi sensor station installed in or near your dog's kennel. In real time, it shows you:

- The temperature and humidity inside the kennel
- Whether your dog is moving, sleeping, or barking
- When the kennel light turns on or off
- A live camera snapshot of the kennel, taken on demand

Beyond live data, PuppyCare keeps a full history of events, detects behavioral patterns, manages your dog's feeding and daily routine, and sends push notifications to your phone the moment something needs your attention.

---

## 2. Requirements

| Item | Details |
|------|---------|
| iPhone | Any iPhone running iOS 16 or later |
| Internet | Wi-Fi or cellular — the app streams data in real time |
| Kennel hardware | Raspberry Pi with DHT22, PIR, sound, light, and camera sensors |
| Setup | The kennel hardware must already be configured and connected to the same Firebase project |

> If you are not sure whether the hardware is set up, ask the person who configured your system. The app will still work for profile management and routine planning even without a live connection.

---

## 3. First Launch

The first time you open PuppyCare, you will see the **Setup screen**. This is a one-time process that takes about 60 seconds.

### Step-by-step

**1. Enter your dog's name**
Type your dog's name in the first field.

**2. Choose breed**
Tap the Breed field and type a few letters to search. Common breeds are listed; if yours is not there, choose the closest Mixed Breed option.

**3. Set sex, age, and weight**
- Sex: Male or Female
- Age: Select the number of months from the scroll picker
- Weight: Select in kilograms (0.5 kg increments)

**4. Tap "Get Started"**
Once all fields are filled, the button activates. Tap it to enter the main app.

> You can change any of these details later from the Profile tab.

---

## 4. The Dashboard

The Dashboard is the first tab you see when you open the app. It gives you a real-time snapshot of what is happening in the kennel right now.

### Connection status

A small indicator at the top of the screen shows whether the app is live-connected to Firebase. If you see "Connecting…" or no data in the sensor tiles, your phone or the kennel hardware may be offline.

### Sensor tiles

| Tile | What it shows |
|------|--------------|
| **Temperature** | Current kennel temperature in °C. Color changes from green (safe) to orange (warning) to red (critical) based on your thresholds |
| **Humidity** | Relative humidity percentage |
| **Motion** | Whether motion is currently detected, and how long ago the last movement was |
| **Sound** | Whether barking or sound is currently active |

Tap any tile to see a short history chart for that sensor.

### Kennel Presence Timer

The large card in the middle of the Dashboard shows whether your dog is currently **In Kennel** or **Out**.

- Tap the toggle switch to mark your dog as in or out of the kennel
- When set to **In Kennel**, a live stopwatch shows exactly how long your dog has been inside — down to the second
- The timer **resets to zero every time** you toggle the switch back on. It always counts from the exact moment you marked your dog as in the kennel

### Camera card

Below the sensor tiles you will find the Camera section.

- Tap **"Take Snapshot"** to request a live photo from the kennel camera
- The Pi captures the image and uploads it — the card updates within a few seconds
- The "Updated at HH:mm" label shows exactly when the current photo was taken
- If no snapshot has been taken yet, the card shows a placeholder

---

## 5. Alerts History

Tap the **Alerts** tab (bell icon) to open the full alerts log.

### What you will see

At the top, four summary cards give you a quick read on today:
- **Barks Today** — total bark events recorded
- **Active Est.** — estimated active minutes based on motion events
- **Temp Range** — lowest and highest temperature recorded today
- **Alerts Today** — total number of alerts (warnings + criticals)

Below that, the **Behavior Insights** card highlights patterns automatically:
- Peak barking hour and bark count
- Most active period of the day
- Temperature extremes worth noting

The **Barking chart** shows bark events by hour for the last 12 hours. The peak hour is highlighted in orange.

### Filtering alerts

Use the filter chips below the chart to narrow the list:
- **All** — every alert type
- **Temperature** — only temperature alerts
- **Sound** — only bark/sound alerts
- **Motion** — only motion detection events
- **Light** — only light on/off events

### Managing alerts

- **Delete one:** Long-press any alert row and tap Delete
- **Clear all:** Tap the trash icon in the top-right corner and confirm

All alerts are automatically marked as read when you open this screen. Unread alerts show a small badge on the tab icon.

---

## 6. Feeding & Routine

Tap the **Feeding** tab (fork icon) to manage your dog's daily schedule.

### The daily routine list

Every meal, walk, and play session you add appears here in chronological order. Each row shows:
- The event type icon (meal, walk, or play)
- The label (e.g. "Breakfast", "Morning Walk") and scheduled time
- A "Next" badge on the upcoming event, showing how many hours and minutes away it is
- A menu button (three dots) for editing or deleting that event

### Adding a new event

Tap the **+ Add** button at the bottom of the screen. A sheet slides up with:
- **Type:** Meal, Walk, or Play
- **Time:** A time picker
- **Label:** Auto-filled based on type and time (you can change it)
- **Grams:** (Meals only) How many grams to feed

Tap **Save** to add it to the schedule.

### Editing or deleting an event

Tap the three-dot menu on any row to edit its details or delete it. You can also tap the row itself to open the edit sheet.

### Calorie summary

At the top of the Feeding tab, a summary card shows:
- Total grams planned for the day across all meals
- Estimated calories based on your food's calorie density (set in Profile)
- Your dog's recommended daily calorie range based on weight and age

### Food Assistant

Tap the **"Food Assistant"** button at the top of the Feeding tab to open the AI food safety tool. See [Section 7](#7-food-assistant) for details.

---

## 7. Food Assistant

The Food Assistant helps you quickly find out whether a specific food is safe to give your dog.

### How to use it

1. Tap the search bar at the top
2. Type the name of any food — for example: "grapes", "chicken", "blueberries", "chocolate"
3. Tap **Ask** or press return

### What you get back

The result card shows:
- A clear safety verdict: **Safe in moderation**, **Use with caution**, **Dangerous — avoid**, or **Not sure — ask your vet**
- A color-coded icon (green, yellow, red)
- A plain-language explanation of why
- Tips on serving size or alternatives where relevant

### Important note

The Food Assistant is a helpful tool, not a substitute for veterinary advice. For any serious concerns about your dog's diet or if your dog has eaten something dangerous, contact your vet immediately.

---

## 8. Profile & Settings

Tap the **Profile** tab (dog icon) to manage your dog's information and app settings.

### Dog information

Edit your dog's name, breed, sex, age, and weight at any time. Changes are saved automatically within half a second.

### Profile photo

Tap the circular photo at the top of the Profile screen to choose a photo from your camera roll. This photo appears at the top of the Dashboard as well.

### Temperature thresholds

This section lets you customize when PuppyCare generates temperature alerts.

| Setting | Default | Meaning |
|---------|---------|---------|
| Warn High | 28°C | A warning alert fires when temperature exceeds this |
| Critical High | 32°C | A critical alert fires — immediate action needed |
| Warn Low | 12°C | A warning alert fires when temperature drops below this |
| Critical Low | 8°C | A critical alert fires — immediate action needed |

Adjust these to match your dog's breed and the climate in your area. Smaller or short-coated breeds may need tighter thresholds.

### Food information

Enter the name of your dog's food brand and its calorie density (kcal per 100g). This is used by the calorie calculator in the Feeding tab. The default is 380 kcal/100g, which is typical for most dry kibble.

### Vaccine reminders

PuppyCare shows age-appropriate vaccine reminders based on Israeli veterinary guidelines. These appear as an informational card in the Profile tab. You can dismiss individual reminders by tapping the X next to each one.

---

## 9. Push Notifications

PuppyCare sends two types of notifications to your phone:

### 1. Critical kennel alerts (push notifications)

These come from the Firebase Cloud Function and arrive even when the app is fully closed. They fire when the kennel alert level changes to **warning**, **stress**, or **emergency** — for example:
- Temperature dangerously high or low
- Repeated sustained barking
- Multiple simultaneous sensor triggers

The notification shows the reason in plain language, for example:
> ⚠️ SmartKennel · Temperature is 34.2°C — above critical threshold

### 2. Routine reminders (local notifications)

These come from the app itself and remind you of scheduled events from the Feeding tab:
- "🍽️ Breakfast time for [dog name] — 200g"
- "🐕 Morning Walk at 07:30"

These notifications appear at the exact scheduled time. Make sure notifications are enabled for PuppyCare in your iPhone's Settings → Notifications.

### Enabling notifications

On first launch, the app asks for notification permission. If you denied it, you can re-enable it:
1. Open your iPhone **Settings**
2. Scroll to **PuppyCare**
3. Tap **Notifications** → enable **Allow Notifications**

---

## 10. Frequently Asked Questions

**Q: The dashboard shows no sensor data. What's wrong?**
The kennel hardware (Raspberry Pi) is likely offline or not connected to the internet. Check that the Pi is powered on and connected to Wi-Fi. If the Pi is running, check that your Firebase project is configured correctly.

**Q: The camera snapshot is not updating.**
Tap "Take Snapshot" to request a new photo. If nothing appears after 10 seconds, the Pi may not be receiving the capture request. Check the Pi's camera script.

**Q: Can I use PuppyCare with multiple dogs?**
The current version supports one dog profile. Switching dogs requires resetting the profile from the Profile tab (scroll to the bottom).

**Q: The kennel timer shows the wrong time.**
The timer always starts fresh from the moment you toggle "In Kennel" on. If it shows unexpected values after restarting the app, force-quit and reopen — the timer re-anchors from the stored start time.

**Q: My routine reminders are not arriving.**
Check that notifications are enabled for PuppyCare in iPhone Settings. Also verify that the scheduled times are in the future — the app only schedules notifications going forward.

**Q: Can I share access with another family member?**
Not in the current version. Only one device at a time receives push notifications (the last one to register its FCM token).

**Q: I entered the wrong breed. Can I change it?**
Yes — tap the Profile tab, tap the Breed field, and update it. Changes save automatically.

---

## 11. Troubleshooting

| Symptom | What to try |
|---------|------------|
| App shows "Connecting…" indefinitely | Check internet connection on both iPhone and Raspberry Pi |
| No push notifications from kennel alerts | Go to Settings → PuppyCare → Notifications and enable them; open the app once so the FCM token is registered |
| Routine reminders stopped arriving | Open the Feeding tab — reminders are rescheduled each time the app launches or the profile changes |
| Profile photo disappeared | The photo is stored locally. If you deleted and reinstalled the app, the photo will need to be set again |
| Feeding schedule is empty after update | Tap "+ Add" to rebuild your schedule. If you had a schedule before, it may need to be recreated after a major update |
| Temperature shows 0°C | The sensor may not have sent data yet after a Pi restart. Wait 30 seconds and check again |

---

*PuppyCare v1.0 — For support or feedback, open an issue on [GitHub](https://github.com/ShaharKoza/PuppyCare/issues)*
