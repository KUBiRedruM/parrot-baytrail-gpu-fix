// Force GPU WebRender compositing
user_pref("gfx.webrender.all", true);

// Enable VA-API hardware video decoding on Linux
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);

// Reduce session restore disk writes (15s -> 5m)
user_pref("browser.sessionstore.interval", 300000);
