#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Installing VA-API driver and diagnostics..."
sudo apt update
sudo apt install -y vainfo i965-va-driver mesa-utils

echo "[2/4] Setting LIBVA_DRIVER_NAME=i965 in /etc/environment..."
grep -qxF 'LIBVA_DRIVER_NAME=i965' /etc/environment || echo 'LIBVA_DRIVER_NAME=i965' | sudo tee -a /etc/environment >/dev/null

echo "[3/4] Configuring Xorg to use modesetting + glamor (fixes Mesa 25+ llvmpipe fallback)..."
sudo mkdir -p /etc/X11/xorg.conf.d
sudo cp 20-intel.conf /etc/X11/xorg.conf.d/20-intel.conf

echo "[4/4] Applying Firefox user.js preferences (if profile exists)..."
for profile in ~/.mozilla/firefox/*.default* ~/.mozilla/firefox-esr/*.default*; do
    if [ -d "$profile" ]; then
        cp user.js "$profile/user.js"
        echo "  -> Copied user.js to $profile"
    fi
done

echo "Done! Reboot your system to apply the Xorg and environment changes."
