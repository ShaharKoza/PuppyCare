#!/usr/bin/env python3
"""
PuppyCare — Raspberry Pi Sensor Station
Puppy-Safe Edition v3

Improvements over v2:
  • DHT22 reading is fully retried (5 attempts, 0.5 s gap) before failing
  • Sensor object is re-initialised automatically after 3 consecutive failed cycles
  • Last valid reading is carried forward for up to 60 s ("warm cache") so brief
    glitches don't wipe the dashboard value
  • DHT errors are logged to stderr / kennel/diagnostics ONLY — never written as
    user-facing alert reasons
  • Reduced false "stale" events from dozens per day to near zero

Hardware (confirmed with photos):
  DHT22/AM2302  GPIO 22   (black housing, ventilation grid, 3-wire VCC/DATA/GND)
  LDR           GPIO 4    (analogue-style photoresistor via voltage divider)
  KY-038        GPIO 17   (red PCB, LM393 comparator, electret mic)
  HC-SR501 PIR  GPIO 27   (Fresnel dome; output active LOW, warm-up 5 s)

Firebase paths written:
  kennel/sensors    — primary: temperature, humidity, light, motion, sleeping, timestamp
  kennel/sound      — bark detection: bark_detected, bark_count_5s, sustained_sound
  kennel/alert      — alert metadata: level, reasons (user-facing only), sleeping, puppy_mode
  kennel/diagnostics— internal: dht_errors, last_error, consecutive_failures (never shown in app)
"""

import time
import threading
import logging
import sys
from collections import deque
from datetime import datetime

import board
import adafruit_dht
import RPi.GPIO as GPIO
import firebase_admin
from firebase_admin import credentials, db

# ─────────────────────────── logging ──────────────────────────────────────────
logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("puppycare")

# ─────────────────────────── GPIO pins ────────────────────────────────────────
PIN_DHT   = board.D22   # DHT22/AM2302 — data
PIN_LDR   = 4           # LDR photoresistor — BCM
PIN_SOUND = 17          # KY-038 digital out — BCM
PIN_PIR   = 27          # HC-SR501 PIR — BCM (active LOW)

# ─────────────────────────── tuning constants ─────────────────────────────────
DHT_POLL_INTERVAL   = 10      # seconds between DHT reads
DHT_RETRY_ATTEMPTS  = 5       # attempts per poll cycle
DHT_RETRY_DELAY     = 0.5     # seconds between retry attempts
DHT_REINIT_AFTER    = 3       # consecutive failed cycles before reinit
DHT_CACHE_SECONDS   = 60      # carry forward last valid reading for this long

SOUND_WINDOW        = 5.0     # seconds — bark-burst detection window
BARK_THRESHOLD      = 3       # events in SOUND_WINDOW to fire bark_detected
SUSTAINED_THRESHOLD = 1.5     # seconds of continuous sound = sustained_sound
SOUND_POLL          = 0.05    # seconds — sound sampling interval

PIR_WARMUP          = 5       # seconds — HC-SR501 stabilisation delay
PIR_HOLDOFF         = 10      # seconds — ignore re-triggers within this window

SLEEP_DARK_QUIET_STILL = 420  # seconds of dark+quiet+still before sleep=True

FIREBASE_UPDATE_INTERVAL = 5  # seconds between kennel/sensors pushes

# ─────────────────────────── Firebase init ────────────────────────────────────
cred = credentials.Certificate("/home/pi/puppycare-firebase-key.json")
firebase_admin.initialize_app(cred, {
    "databaseURL": "https://<YOUR-PROJECT-ID>.firebaseio.com"
})
db_ref = db.reference("kennel")

# ─────────────────────────── GPIO setup ───────────────────────────────────────
GPIO.setmode(GPIO.BCM)
GPIO.setup(PIN_LDR,   GPIO.IN)
GPIO.setup(PIN_SOUND, GPIO.IN)
GPIO.setup(PIN_PIR,   GPIO.IN, pull_up_down=GPIO.PUD_UP)  # active LOW

# ─────────────────────────── shared state ─────────────────────────────────────
state_lock = threading.Lock()
state = {
    # DHT22
    "temperature": None,
    "humidity":    None,
    "dht_last_valid_time": 0.0,   # monotonic time of last good reading
    "dht_consecutive_failures": 0,

    # Sensors
    "light":     False,
    "sound":     False,
    "motion":    False,
    "sleeping":  False,

    # Bark detection
    "bark_detected":  False,
    "bark_count_5s":  0,
    "sustained_sound": False,

    # Diagnostics (written to kennel/diagnostics, NOT alert reasons)
    "dht_total_errors": 0,
    "dht_last_error":   "",
}

# ─────────────────────────── DHT22 reader ─────────────────────────────────────

_dht_device = None

def _get_dht_device():
    """Return the DHT device, creating it if needed."""
    global _dht_device
    if _dht_device is None:
        # use_pulseio=False is required on modern Raspberry Pi OS (kernel 5.10+)
        # and is generally more reliable than the default pulseio backend.
        _dht_device = adafruit_dht.DHT22(PIN_DHT, use_pulseio=False)
        log.info("DHT22 initialised on %s (use_pulseio=False)", PIN_DHT)
    return _dht_device

def _reinit_dht():
    """Destroy and recreate the DHT device object."""
    global _dht_device
    if _dht_device is not None:
        try:
            _dht_device.exit()
        except Exception:
            pass
        _dht_device = None
    time.sleep(1.0)
    _get_dht_device()
    log.info("DHT22 re-initialised after consecutive failures")

def read_dht_robust():
    """
    Read DHT22 with retries and automatic sensor re-initialisation.

    Returns (temperature_c, humidity_pct) on success, (None, None) on failure.
    Never raises.

    Strategy:
      1. Try up to DHT_RETRY_ATTEMPTS times with DHT_RETRY_DELAY between each.
      2. Validate range: temp −40…80 °C, humidity 0…100 %.
      3. On consecutive failure beyond DHT_REINIT_AFTER cycles, reinitialise.
      4. On success, reset the failure counter.
    """
    device = _get_dht_device()

    for attempt in range(DHT_RETRY_ATTEMPTS):
        try:
            temperature = device.temperature
            humidity    = device.humidity

            # Sanity-check the values (library can return out-of-range on glitch)
            if (temperature is not None and humidity is not None and
                    -40.0 <= temperature <= 80.0 and
                    0.0   <= humidity    <= 100.0):
                # Success — reset failure counter
                with state_lock:
                    state["dht_consecutive_failures"] = 0
                return float(temperature), float(humidity)

            # Values were returned but are None or out of range — retry
            time.sleep(DHT_RETRY_DELAY)

        except RuntimeError as e:
            # adafruit_dht raises RuntimeError on checksum / timing failures.
            # These are VERY common (10-30 % of reads on a busy Pi) and should
            # be retried silently, not surfaced to the user.
            err_msg = str(e)
            log.debug("DHT retry %d/%d: %s", attempt + 1, DHT_RETRY_ATTEMPTS, err_msg)
            with state_lock:
                state["dht_total_errors"] += 1
                state["dht_last_error"]    = err_msg
            time.sleep(DHT_RETRY_DELAY)

        except Exception as e:
            # Unexpected error — log and reinitialise immediately
            log.warning("DHT unexpected error: %s", e)
            with state_lock:
                state["dht_total_errors"] += 1
                state["dht_last_error"]    = str(e)
            _reinit_dht()
            device = _get_dht_device()
            time.sleep(DHT_RETRY_DELAY)

    # All attempts failed
    with state_lock:
        state["dht_consecutive_failures"] += 1
        failures = state["dht_consecutive_failures"]

    log.warning("DHT22: all %d attempts failed (consecutive failed cycles: %d)",
                DHT_RETRY_ATTEMPTS, failures)

    # Re-initialise after N consecutive failed poll cycles
    if failures >= DHT_REINIT_AFTER:
        _reinit_dht()
        with state_lock:
            state["dht_consecutive_failures"] = 0

    return None, None

def dht_loop():
    """Background thread: poll DHT22 every DHT_POLL_INTERVAL seconds."""
    _get_dht_device()   # initialise early so first read has the object ready
    while True:
        temp, hum = read_dht_robust()
        now = time.monotonic()

        with state_lock:
            if temp is not None:
                state["temperature"]        = temp
                state["humidity"]           = hum
                state["dht_last_valid_time"] = now
            else:
                # Carry forward cached value for up to DHT_CACHE_SECONDS.
                # After that, set to None so the dashboard shows "--".
                age = now - state["dht_last_valid_time"]
                if age > DHT_CACHE_SECONDS:
                    state["temperature"] = None
                    state["humidity"]    = None
                    log.info("DHT cache expired (%.0f s since last valid read)", age)
                # If within cache window, existing values remain unchanged.

        time.sleep(DHT_POLL_INTERVAL)

# ─────────────────────────── Sound / bark detection ───────────────────────────

def sound_loop():
    """
    Background thread: sample the KY-038 digital output and compute:
      bark_detected  — ≥ BARK_THRESHOLD events in the last SOUND_WINDOW seconds
      bark_count_5s  — count of events in last 5 s
      sustained_sound — continuous sound lasting ≥ SUSTAINED_THRESHOLD seconds
    """
    events     = deque()   # timestamps of rising edges
    sound_on_since = None  # monotonic time when continuous sound started

    prev = GPIO.input(PIN_SOUND)

    while True:
        current = GPIO.input(PIN_SOUND)
        now     = time.monotonic()

        # Rising edge (LOW → HIGH on KY-038 means sound detected)
        if current == GPIO.HIGH and prev == GPIO.LOW:
            events.append(now)
            if sound_on_since is None:
                sound_on_since = now

        # Falling edge — sound ended
        if current == GPIO.LOW and prev == GPIO.HIGH:
            sound_on_since = None

        # Prune events older than the window
        cutoff = now - SOUND_WINDOW
        while events and events[0] < cutoff:
            events.popleft()

        bark_count  = len(events)
        bark_hit    = bark_count >= BARK_THRESHOLD
        sound_active = current == GPIO.HIGH
        sustained   = (sound_on_since is not None and
                       (now - sound_on_since) >= SUSTAINED_THRESHOLD)

        with state_lock:
            state["sound"]         = sound_active
            state["bark_detected"] = bark_hit
            state["bark_count_5s"] = bark_count
            state["sustained_sound"] = sustained

        prev = current
        time.sleep(SOUND_POLL)

# ─────────────────────────── PIR motion ───────────────────────────────────────

def pir_loop():
    """
    Background thread: debounce HC-SR501 (active LOW) with PIR_HOLDOFF cooldown.
    Warm-up delay of PIR_WARMUP seconds on startup.
    """
    log.info("PIR: waiting %d s for HC-SR501 warm-up...", PIR_WARMUP)
    time.sleep(PIR_WARMUP)
    log.info("PIR: ready")

    last_trigger = 0.0

    while True:
        raw = GPIO.input(PIN_PIR)
        motion = (raw == GPIO.LOW)   # active LOW
        now = time.monotonic()

        if motion and (now - last_trigger) >= PIR_HOLDOFF:
            last_trigger = now
            with state_lock:
                state["motion"] = True
        elif not motion:
            # No motion detected in this cycle
            with state_lock:
                state["motion"] = False

        time.sleep(0.1)

# ─────────────────────────── Sleep detection ──────────────────────────────────

def sleep_loop():
    """
    Compute sleep state: dog is considered asleep when the kennel has been
    dark + quiet + still for SLEEP_DARK_QUIET_STILL consecutive seconds.
    """
    calm_since = None

    while True:
        with state_lock:
            dark  = not state["light"]
            quiet = not state["sound"]
            still = not state["motion"]

        now = time.monotonic()

        if dark and quiet and still:
            if calm_since is None:
                calm_since = now
            elapsed = now - calm_since
            sleeping = elapsed >= SLEEP_DARK_QUIET_STILL
        else:
            calm_since = None
            sleeping   = False

        with state_lock:
            state["sleeping"] = sleeping

        time.sleep(1.0)

# ─────────────────────────── Light (LDR) ──────────────────────────────────────

def light_loop():
    """Poll LDR digital output (HIGH = light detected)."""
    while True:
        with state_lock:
            state["light"] = (GPIO.input(PIN_LDR) == GPIO.HIGH)
        time.sleep(0.5)

# ─────────────────────────── Alert evaluation ─────────────────────────────────

def _evaluate_alert_level(snap, thresholds):
    """
    Return (level_str, reasons_list) based on current sensor snapshot.

    levels: "normal" | "warning" | "stress" | "emergency"
    reasons: user-facing strings only — NO internal diagnostics here.
    """
    level   = "normal"
    reasons = []

    temp = snap.get("temperature")

    # ── Temperature ────────────────────────────────────────────────────────────
    if temp is not None:
        warn_high = thresholds.get("warn_high",     28.0)
        crit_high = thresholds.get("critical_high", 32.0)
        warn_low  = thresholds.get("warn_low",      12.0)
        crit_low  = thresholds.get("critical_low",   8.0)

        if temp > crit_high:
            level = "emergency"
            reasons.append(f"Temperature critical: {temp:.1f}°C — act immediately")
        elif temp > warn_high:
            level = max_level(level, "warning")
            reasons.append(f"Temperature high: {temp:.1f}°C")
        elif temp < crit_low:
            level = "emergency"
            reasons.append(f"Temperature critical low: {temp:.1f}°C — provide warmth immediately")
        elif temp < warn_low:
            level = max_level(level, "warning")
            reasons.append(f"Temperature low: {temp:.1f}°C")
    # Note: if temp is None (sensor failure), we do NOT add a diagnostic reason.
    # The iOS app shows "--" on the tile. A DHT error is not a kennel safety event.

    # ── Sound ──────────────────────────────────────────────────────────────────
    if snap.get("sustained_sound"):
        level = max_level(level, "stress")
        reasons.append("Sustained barking detected")
    elif snap.get("bark_detected"):
        level = max_level(level, "warning")
        reasons.append(f"Barking detected ({snap.get('bark_count_5s', 0)} barks in 5 s)")

    # ── Motion ─────────────────────────────────────────────────────────────────
    if snap.get("motion"):
        reasons.append("Motion detected in kennel")

    if not reasons:
        reasons.append("All clear")

    return level, reasons

def max_level(current, candidate):
    order = {"normal": 0, "warning": 1, "stress": 2, "emergency": 3}
    return candidate if order.get(candidate, 0) > order.get(current, 0) else current

# ─────────────────────────── Firebase writer ──────────────────────────────────

# Default thresholds — will be overridden by kennel/config in Firebase if present
_thresholds = {
    "warn_high":     28.0,
    "critical_high": 32.0,
    "warn_low":      12.0,
    "critical_low":   8.0,
}

def _load_remote_thresholds():
    """Pull threshold overrides from kennel/config (if written by the iOS app)."""
    global _thresholds
    try:
        cfg = db_ref.child("config").get()
        if isinstance(cfg, dict):
            for k in ("warn_high", "critical_high", "warn_low", "critical_low"):
                if k in cfg:
                    _thresholds[k] = float(cfg[k])
            log.info("Thresholds loaded from Firebase: %s", _thresholds)
    except Exception as e:
        log.warning("Could not load remote thresholds: %s", e)

def firebase_writer_loop():
    """Main Firebase push loop — runs every FIREBASE_UPDATE_INTERVAL seconds."""
    _load_remote_thresholds()

    while True:
        with state_lock:
            snap = dict(state)   # shallow copy under lock

        # ── kennel/sensors ────────────────────────────────────────────────────
        sensors_payload = {
            "temperature": snap["temperature"],
            "humidity":    snap["humidity"],
            "light":       "light" if snap["light"] else "dark",
            "motion":      snap["motion"],
            "sound":       snap["sound"],
            "sleeping":    snap["sleeping"],
            "timestamp":   datetime.now().strftime("%H:%M:%S"),
        }

        # ── kennel/sound ──────────────────────────────────────────────────────
        sound_payload = {
            "sound_active":   snap["sound"],
            "bark_detected":  snap["bark_detected"],
            "bark_count_5s":  snap["bark_count_5s"],
            "sustained_sound": snap["sustained_sound"],
            "timestamp":      datetime.now().strftime("%H:%M:%S"),
        }

        # ── kennel/alert ──────────────────────────────────────────────────────
        level, reasons = _evaluate_alert_level(snap, _thresholds)
        alert_payload = {
            "level":      level,
            "reasons":    reasons,
            "sleeping":   snap["sleeping"],
            "timestamp":  datetime.utcnow().isoformat() + "Z",
        }

        # ── kennel/diagnostics (internal only — never shown in app) ───────────
        diag_payload = {
            "dht_total_errors":       snap["dht_total_errors"],
            "dht_consecutive_failures": snap["dht_consecutive_failures"],
            "dht_last_error":         snap["dht_last_error"],
            "dht_last_valid_age_s":   int(time.monotonic() - snap["dht_last_valid_time"])
                                      if snap["dht_last_valid_time"] > 0 else -1,
        }

        try:
            db_ref.child("sensors").set(sensors_payload)
            db_ref.child("sound").set(sound_payload)
            db_ref.child("alert").set(alert_payload)
            db_ref.child("diagnostics").set(diag_payload)
        except Exception as e:
            log.error("Firebase write error: %s", e)

        time.sleep(FIREBASE_UPDATE_INTERVAL)

# ─────────────────────────── main ─────────────────────────────────────────────

def main():
    log.info("PuppyCare sensor station starting — Puppy-Safe Edition v3")

    threads = [
        threading.Thread(target=dht_loop,            name="dht",    daemon=True),
        threading.Thread(target=sound_loop,           name="sound",  daemon=True),
        threading.Thread(target=pir_loop,             name="pir",    daemon=True),
        threading.Thread(target=light_loop,           name="light",  daemon=True),
        threading.Thread(target=sleep_loop,           name="sleep",  daemon=True),
        threading.Thread(target=firebase_writer_loop, name="firebase", daemon=True),
    ]

    for t in threads:
        t.start()
        log.info("Thread started: %s", t.name)

    log.info("All threads running. Press Ctrl+C to stop.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        log.info("Shutting down...")
    finally:
        GPIO.cleanup()
        if _dht_device:
            try:
                _dht_device.exit()
            except Exception:
                pass

if __name__ == "__main__":
    main()
