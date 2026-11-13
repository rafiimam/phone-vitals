# BlackBox MD — a black box and a doctor for your phone

**Why did my phone die?** Every Android user asks it. No major app answers it.

DevCheck, AIDA64 and CPU-Z dump 200 raw numbers and forget everything when your phone dies. AccuBattery estimates battery wear, but only for the battery. None of them keep a history, none give a plain-language verdict, and none produce the report a repair shop actually needs.

BlackBox MD is different: it's a **flight recorder**.

- It logs your phone's vitals — battery %, temperature, voltage, thermal status
- It records **inferred unclean shutdowns** across reboots (see "Honest limits" below)
- When you ask why, it walks Google's own diagnosis ladder and gives a verdict: *likely an app / likely software / likely battery / likely hardware*
- It scans your **installed apps, your files, and your OS/system integrity** and puts everything into one shareable repair report

Built after a real Pixel 6 started hanging, powering off on its own, getting stuck at the Google logo, and overheating while hung. That phone is the first test case. The problem belongs to millions.

## What it checks

### 1. Health dashboard
Battery level / health flag / temperature / voltage / current / **cycle count (Android 14+)**, thermal status + headroom, RAM, storage, uptime — combined into a 0–100 score with warnings in plain language. Every value is labelled **Measured / Estimated / Unavailable**.

### 2. Black box timeline
A heartbeat is persisted while the app runs, and a native receiver records boots and clean shutdowns. If a session ends with no clean marker, the next launch records an *inferred* unclean exit. That's the evidence snapshot apps throw away.

### 3. Installed apps scan
For every app Android lets us see (PackageManager, **not** `QUERY_ALL_PACKAGES`):
sideloaded source (not Play), not updated in 2+ years, targets a very old Android SDK, 5+ sensitive permissions, and — with optional Usage Access — top foreground time as a drain *proxy*.

### 4. Files scan
Shared files Android lets a normal app see: zero-byte files (failed/corrupted saves), partial downloads (`.part` / `.tmp`), downloaded APKs, media whose header doesn't parse (possibly corrupted), and duplicates over 1 MB by SHA-256.

### 5. OS / system integrity
Security patch age, build fingerprint/type, Verified Boot state (where readable), root/modification heuristics, and a guided path for suspected OS corruption: free storage → updates → **Pixel Update & Software Repair** → factory reset *last* → hardware if it still fails clean.

### 6. Verdict wizard — "Why did my phone die?"
Four questions (Safe Mode result, dies-with-charge, onset, Google-logo hang) implementing Google's decision logic. No fake certainty — the verdict says *likely*, and what to do next.

### 7. Repair report
One tap shares a complete report: device/build, battery, thermal, timeline, app flags, file flags, system integrity, warnings — generated on-device, no account, no upload.

## Honest limits — what no normal app can do

Android blocks these for non-system apps. BlackBox MD says so in the UI instead of faking them:

- ❌ Scan or hash `/system` / OS files — **Verified Boot already does this at startup**; a hang at the Google logo can be exactly that check failing
- ❌ True per-app CPU %, per-app RAM, per-app battery mAh for other apps
- ❌ CPU/SoC temperature as a guaranteed °C reading (we show thermal status/headroom + battery temp)
- ❌ An iPhone-style battery-health % read directly (health % here is *estimated* from cycles/current, labelled as such)
- ❌ UFS / storage-health % for third parties (system-only on Android 15)
- ❌ The true kernel shutdown reason (`sys.boot.reason` is SELinux-blocked) — our shutdown log is an **inference**, labelled as one
- ❌ Other apps' crash logs, logcat, bugreports

This honesty is a feature. Competitors present guesses as measurements.

## For your Pixel 6 — do this today

1. If it's hot, swollen, screen lifting, or smelling: **stop, don't charge it, take it to a shop**
2. Next time it stays on: **back up immediately** (Photos, Drive, WhatsApp, 2FA)
3. Check storage — keep **>10% free**; screenshot Settings → Battery → Battery usage
4. **Safe Mode test** — if it's fine there, it's an app; if not, it's not an app
5. Try Pixel Repair (`pixelrepair.withgoogle.com`) from a computer before any factory reset
6. Install BlackBox MD and let the recorder collect the next failure

Most likely for a 2021 Pixel 6 in 2026: a degraded battery (Google rates these batteries to ~80% for ~800 cycles, and Pixel 6 doesn't show health % in Settings), amplified by heat — then corrupted update/storage, then board.

## Tech

- **Flutter** (Dart) UI + logic — `device_info_plus`, `battery_plus`, `sensors_plus`, `connectivity_plus`, `shared_preferences`, `share_plus`, `crypto`
- **One custom Kotlin MethodChannel** (`MainActivity.kt`) for what plugins don't expose: BatteryManager detail + cycle count, PowerManager thermal, Memory/StatFs, CPU sysfs, SensorManager, installed apps + installer + permissions, system integrity, UsageStats, shared-file listing + hashing
- **Native `BootReceiver`** for BOOT_COMPLETED / ACTION_SHUTDOWN
- No `QUERY_ALL_PACKAGES`, no 24×7 foreground service, no analytics, **everything on-device** — by design, for Play policy and for trust

## Run it

```bash
flutter pub get
# If android/ios scaffolding files are missing on your machine:
flutter create --platforms=android .
flutter run
flutter test
```

> The VM this repo was authored in has no Flutter/Android SDK, so the first real compile happens on your machine (MacBook Air M1 + Android Studio works). Expect the usual first-build fixes; the native channel degrades gracefully — every call returns "Unavailable" rather than crashing.

## Roadmap

- **v0.1 (this repo):** dashboard, recorder, apps/files/system scans, wizard, share report
- **v0.2:** MediaStore-wide file scan, charge-session battery-wear estimate (AccuBattery-style, labelled Estimated), guided hardware tests (touch, speaker/mic, vibration, sensors live view)
- **v0.3:** periodic WorkManager sampling, backup-nudge notification after 3 unclean shutdowns in a week, PDF report
- **Play Store:** on-device-only data safety ("no data collected"), Usage Access as an optional upgrade with its own consent screen, target latest API

## Research

Full sourced research — Pixel 6 causes, Android API capability matrix, competitor teardown, Play policy — lives in the companion research page and in `PLAN.md`.

## License

MIT — see `LICENSE` when added. Contributions welcome; please keep the honesty labels.
