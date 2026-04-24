#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PuppyCare — USB webcam MJPEG streamer
#
# Runs mjpg-streamer against /dev/video0 (USB webcam) and exposes an
# MJPEG stream on http://<pi-ip>:8081/?action=stream
#
# Port 8081 is used (not 8080) to avoid colliding with camera.py's
# still-image HTTP server which already listens on 8080.
#
# ---------------------------------------------------------------------------
# ONE-TIME INSTALL (run on the Pi):
#
#   sudo apt update
#   sudo apt install -y cmake libjpeg62-turbo-dev git build-essential v4l-utils
#   cd ~
#   git clone https://github.com/jacksonliam/mjpg-streamer.git
#   cd mjpg-streamer/mjpg-streamer-experimental
#   make
#   sudo make install
#
# Verify the webcam is detected:
#   v4l2-ctl --list-devices
#   # You should see /dev/video0 listed under your USB webcam
#
# Copy this script + the .service file to the Pi and enable auto-start:
#   sudo cp camera_stream.sh /usr/local/bin/puppycare-camera.sh
#   sudo chmod +x /usr/local/bin/puppycare-camera.sh
#   sudo cp puppycare-camera.service /etc/systemd/system/
#   sudo systemctl daemon-reload
#   sudo systemctl enable --now puppycare-camera.service
#
# Check it's running:
#   systemctl status puppycare-camera.service
#   curl -I http://localhost:8081/?action=stream
#
# Then in the iOS app, open the camera card → tap the gear icon →
# enter:  http://raspberrypi.local:8081/?action=stream
# (or the Pi's LAN IP if mDNS doesn't resolve)
# ---------------------------------------------------------------------------

set -euo pipefail

# ── Tunable parameters ─────────────────────────────────────────────────────
DEVICE="${CAMERA_DEVICE:-/dev/video0}"
WIDTH="${CAMERA_WIDTH:-640}"
HEIGHT="${CAMERA_HEIGHT:-480}"
FPS="${CAMERA_FPS:-15}"
PORT="${CAMERA_PORT:-8081}"

# Location of the installed mjpg-streamer binaries
MJPG_DIR="${MJPG_DIR:-/usr/local/share/mjpg-streamer}"
MJPG_BIN="${MJPG_BIN:-/usr/local/bin/mjpg_streamer}"

# ── Sanity checks ──────────────────────────────────────────────────────────
if [[ ! -e "$DEVICE" ]]; then
    echo "ERROR: camera device $DEVICE not found. Plug in the USB webcam or set CAMERA_DEVICE=/dev/videoN" >&2
    exit 1
fi

if [[ ! -x "$MJPG_BIN" ]]; then
    echo "ERROR: mjpg_streamer not found at $MJPG_BIN. Did you run 'sudo make install'?" >&2
    exit 1
fi

# ── Run ────────────────────────────────────────────────────────────────────
# -n = no credentials (LAN only); add "-c user:pass" if you want basic auth
exec "$MJPG_BIN" \
    -i "$MJPG_DIR/input_uvc.so -d $DEVICE -r ${WIDTH}x${HEIGHT} -f $FPS -n" \
    -o "$MJPG_DIR/output_http.so -p $PORT -w $MJPG_DIR/www"
