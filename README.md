# Parrot OS / Debian 13 (Mesa 25+) Intel Bay Trail GPU & Firefox Hardware Decoding Fix

A complete fix and diagnostic breakdown for **Intel Atom Z36xxx/Z37xxx (Bay Trail / Valleyview, device ID `0f31`)** hardware running **Parrot OS 7 / Debian 13 (Trixie)** with **Linux 7.x** and **Mesa 25.x**.

## Symptoms
- **~176% CPU usage** and heavy RAM consumption in `firefox-esr` while playing a single 1080p YouTube video on bare metal.
- High Xorg CPU usage and sluggish desktop rendering/scrolling.
- Firefox Profiler showing **`SwComposite`** and **`Paint`** taking ~47% of Parent Process time.
- Firefox `about:support` showing **`Unsupported`** for every single codec (including `H264`) under **Hardware Decoding**.

---

## Troubleshooting Timeline: Every Roadblock & How We Solved It

### 1. Identifying the CPU Bottleneck (`ps aux` & Firefox Profiler)
Running `ps aux --sort=-%cpu` revealed three Firefox processes saturating nearly two full CPU cores:
- Main browser process (`firefox-esr`): **93.6% CPU** (`SwComposite` / software painting)
- Active YouTube tab (`-contentproc ... tab`): **53.2% CPU**
- Remote Data Decoder (`rdd`): **21.6% CPU** (decoding video frames on the CPU)

### 2. Why `h264ify` Alone Was Not Enough
Installing the **h264ify** extension forced YouTube to serve H.264 instead of VP9/AV1, but `about:support` still reported **`H264 Hardware Decoding: Unsupported`**. Without OS-level VA-API and OpenGL acceleration, Firefox was still decoding H.264 in software.

### 3. Roadblock #1: VA-API `iHD` vs `i965` Driver Mismatch
Running `vainfo` showed that `libva` attempted to load the newer Intel `iHD_drv_video.so` driver first and failed before falling back to `i965_drv_video.so`:
```text
libva error: /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so init failed
vainfo: Driver version: Intel i965 driver for Intel(R) Bay Trail - 2.4.1
```
Firefox's sandboxed `rdd` process aborted on that initial `iHD` failure.
- **Fix:** Explicitly set `LIBVA_DRIVER_NAME=i965` in `/etc/environment` (and ensured `i965-va-driver` was installed).

### 4. Roadblock #2: System-Wide `llvmpipe` Software Rendering (`Accelerated: no`)
Even with `LIBVA_DRIVER_NAME=i965` and Firefox `about:config` flags enabled (`gfx.webrender.all`, `media.ffmpeg.vaapi.enabled`, `media.hardware-video-decoding.force-enabled`), Firefox still refused hardware decoding. Inspecting `about:support` and `glxinfo -B` revealed the real culprit:
```text
WebGL 1 Driver Renderer: Mesa -- llvmpipe (LLVM 19.1.7, 128 bits)
Accelerated: no
```
The entire X11 desktop was running on Mesa's CPU-based `llvmpipe` rasterizer rather than the Bay Trail GPU.

### 5. Root Cause: Legacy Xorg `intel` Driver vs. Mesa 25+ (`i965_dri.so` Removed)
Checking `/proc/cmdline` confirmed `nomodeset` was **not** present and kernel flags (`intel_idle.max_cstate=1 i915.enable_fbc=0 i915.enable_psr=0`) were healthy. Checking `/var/log/Xorg.0.log` exposed the exact failure:
```text
(EE) AIGLX error: dlopen of /usr/lib/x86_64-linux-gnu/dri/i965_dri.so failed (No such file or directory)
(EE) AIGLX error: unable to load driver i965
(II) GLX: Initialized DRISWRAST GL provider for screen 0
```
- **Why this happened:** An existing `/etc/X11/xorg.conf.d/20-intel.conf` specified the legacy `Driver "intel"` (`xserver-xorg-video-intel`), which tries to load `i965_dri.so`. In **Mesa 25+**, `i965_dri.so` no longer exists (Bay Trail Gen 7 graphics are handled by **`crocus_dri.so`**). When `dlopen` failed, AIGLX fell back to `DRISWRAST` (`llvmpipe`).
- **Final Fix:** Switched `/etc/X11/xorg.conf.d/20-intel.conf` from `Driver "intel"` to `Driver "modesetting"` with `AccelMethod "glamor"` and `DRI "3"`.

---

## Final Working Results
- **`glxinfo -B`**: `Accelerated: yes` | `OpenGL renderer string: Mesa Intel(R) HD Graphics (BYT)`
- **Firefox `about:support`**:
  - **WebGL 1 Driver Renderer**: `Mesa Intel(R) HD Graphics (BYT)`
  - **H264 Hardware Decoding**: `Supported` (Green)
  - **H264 Hardware Encoding**: `Supported` (Green)
- **Desktop & Browser Performance**: System-wide rendering moved from CPU (`llvmpipe`) to GPU (`glamor` + `crocus`), eliminating desktop lag and dropping YouTube CPU usage dramatically.

## Installation
```bash
git clone https://github.com/KUBiRedruM/parrot-baytrail-gpu-fix.git
cd parrot-baytrail-gpu-fix
chmod +x install.sh
./install.sh
sudo reboot
```
*(Recommended: Install the **h264ify** extension in Firefox and disable 60fps so YouTube streams `1080p30` H.264, which Bay Trail decodes natively in hardware.)*
