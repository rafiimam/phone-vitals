# BlackBox MD — Product Plan

## Problem
A Pixel 6 (2021, Tensor G1) hangs in use, powers off (sometimes auto-restarts, sometimes needs Power+Volume Up), hangs at the Google logo, and overheats while hung. Millions of aging Android phones fail the same way, and users cannot tell app vs software vs battery vs board — so they either panic-reset (losing data) or pay for the wrong repair.

## Research summary (2026-11-13, sourced — see research page)
- Most likely chain: degraded battery (voltage sag) > heat amplification > corrupted OTA / full or failing storage > board fault. Google rates Pixel 3–8 Pro batteries to ~80% at ~800 cycles; Pixel 6/7/8 show no health % in Settings.
- Google ladder: force restart → charge 10 min → Safe Mode → updates + >10% free storage → Pixel Repair tool → factory reset last. Bad in Safe Mode + bad after clean reset = hardware.
- Android gives a normal app strong point-in-time vitals and almost no history/cross-app precision. See capability labels in README.
- Competitors (DevCheck ~13M, AIDA64 28M, CPU-Z 110M, AccuBattery 41M installs, Play/AppBrain 2026-11-13) are snapshot spec sheets. Gap: verdict, persistent shutdown log, predictive warning, repair-shop report, honesty labelling.

## Differentiated product: "Black box for your phone"
Flight recorder + guided verdict + backup nudge + shareable repair report.

## MVP scope (v0.1, shipped in this repo)
Dashboard/score, recorder/timeline, battery detail, apps scan, files scan, system integrity, wizard, text repair report. No Usage Access required for core; no FGS; no QUERY_ALL_PACKAGES.

## Added at Rafi's request (2026-11-13)
Installed apps diagnosis, installed files diagnosis (corrupted files), and OS/system file diagnosis.
- Apps: full implementation above.
- Files: shared-storage implementation; /data/app and other apps' private files are inaccessible — stated in UI.
- OS/system: a normal app CANNOT verify OS files. Implementation = integrity signals (patch age, verified boot state, fingerprint, root heuristics, debuggable, build type) + the Google repair ladder. Never claim a /system scan.

## Success test (Pixel 6)
After 1 week installed, the report should be able to say e.g.: "N unclean shutdowns, last heartbeat at X% / Y°C / thermal Z, cycles N — pattern matches failing battery, not an app (also failed in Safe Mode per wizard). Back up, battery quote first."

## Play Store guardrails
Optional Usage Access only, privacy policy + Data safety, on-device processing, user-initiated share only, typed FGS declaration avoided in MVP (WorkManager later), target API current at submission.


## v0.3.0 — Phase 1: BlackBox MD (2026-11-13)
- Renamed PhoneVitals -> BlackBox MD (display name only; applicationId unchanged so existing installs, recorder history and case data carry over). Reason: 'PhoneVitals' is an existing commercial iPhone-diagnostics product in the same repair-report niche.
- Flagship = the Case File (Sudden-Failure Forensics): black-box recorder + elimination tests + ruled-out / still-suspect evidence board + Repair Passport. Storage cleanup is a treatment, not the headline.
- Dr. BlackBox avatar: layered-vector character (CustomPainter) with a DoctorMode outfit system - hat, outfit colour, tool chip and speech change per problem (check-up, storage, battery, cool-down, cache, notifications, detective, connectivity, hardware, update).
- Storage Doctor treatment: user-selected cleanup of zero-byte files, partial downloads, duplicate copies (first copy never pre-selected) and APKs; deletion goes through Android's own MediaStore consent dialog (createDeleteRequest) - nothing silent; result is verified by re-measuring free storage before/after and recorded as a Timeline event.
- Launcher icon: robot-doctor logo chosen; PNG set (all densities + 512 Play + 1024 master) lives in the branding folder - dropped into res/mipmap-* at release-build time (the GitHub connector cannot carry binaries).


## v0.4.0 — Phase 2: sensors beyond snapshots + the Doctor Agent (2026-11-14)
- Change Radar: every launch diffs a device snapshot (apps installed/updated/removed, security patch, build fingerprint, storage jumps >=5%, battery cycle movement) and logs deltas as change_detected case evidence; Case File shows "What changed since last check".
- Cache Radar: per-app app/data/cache bytes via StorageStatsManager (user-granted Usage Access), top-12 cache hogs, one tap to the exact App Info page to clear cache, refresh to re-measure. No app can clear another app's cache - the doctor measures and guides, never fakes.
- Recorder self-awareness: ApplicationExitInfo (Android keeps exit reasons only for the caller's own UID) shown in System - how BlackBox MD itself died between sessions (force-stop / LMK / crash).
- Tamper-evident case chain: every recorder event is SHA-256 hash-chained to the previous event; the Repair Passport prints the chain head + per-event short hashes.
- Doctor Agent ("Ask Dr. BlackBox"): a chat agent whose brain is an open-source LLM the USER connects - Ollama on their own machine or any OpenAI-compatible endpoint (Groq/LM Studio/Together...). Every answer is grounded in a built case context (recorder events, measurements, changes, flags) and bound by honesty rules (no impossible-fix claims, safety first, probabilistic language). The agent can end replies with an action token that the app renders as a real button (Safe Mode investigation, Storage Doctor, Apps/Cache Radar, Share Passport). Settings (endpoint/model/key) stored only on-device. Case summary leaves the phone only to the endpoint the user chose.
- Parked for later: fully on-device LLM engine (llama.cpp/MediaPipe, Qwen2.5 GGUF download) behind the same DoctorBrain interface; local-ADB "deep scan" (LADB-style wireless pairing) as an experimental GitHub-build-only mode - fragile pairing UX and licensing review needed first.


## v0.5.0 — Phase 3a: zero-config, AI-driven (2026-11-14)
Rafi's call after the first successful build: the app must not ASK the user to connect anything - it should auto-connect and be AI driven.
- Zero-config Ollama discovery: on Agent open (and on the Case File's AI card retry), the app scans its own Wi-Fi subnet for port 11434, queries /api/tags, auto-picks a chat model (Qwen > Llama > first), saves it silently. Manual endpoint settings remain only as an override under the gear.
- AI-driven Case File: an "AI assessment" card under the doctor's speech auto-generates a grounded assessment (likely cause, strongest evidence, single next step + action button) from the case context whenever a brain is connected; results are cached against a case fingerprint (events/deaths/changes/score) and regenerate only when the evidence changes. Connection errors are never cached or shown as assessments; with no brain the card quietly offers Connect.
- Phase 1+2 compile-verified on Rafi's Pixel 6 (flutter run, 2026-11-14): APK built and installed; the "Could not start Dart VM service HTTP server" log line is the debug VM service failing to bind a localhost socket on-device - the app itself runs (it can affect hot reload/DevTools attachment, not the app).
- Next milestone (3b): fully on-device brain (no computer needed) - engine/model distribution to be verified before building.

## v0.6.0 — Phase 3b: the brain moves INTO the phone (2026-11-14)
Why: LAN auto-connect still depends on a computer running Ollama AND listening beyond localhost (Ollama binds 127.0.0.1 by default) - too many conditions for "the app will be AI driven". The brain now lives on-device.
- Engine: MediaPipe LLM Inference API (com.google.mediapipe:tasks-genai:0.10.27) via the existing MethodChannel (llmModelInfo / llmGenerate, generation on a background thread, engine instance cached).
- Model: Qwen2.5-1.5B-Instruct, litert-community conversion (multi-prefill, q8, 4096 KV), .task format. Verified on the Hugging Face API 2026-11-14: public, gated=false, license Apache-2.0. Downloaded once at runtime (~1.6 GB) into the app's private files dir with progress; the .part file is renamed only on a complete download.
- Prompting: ChatML template applied manually (the runtime does not template prompts); the system prompt is the doctor's grounded case prompt, so the on-device brain obeys the same honesty rules and action tokens.
- Priority (DoctorBrain.resolveBrain): user-configured endpoint > on-device model > Ollama auto-discovery (Agent screen). The one-tap brain download is the primary call-to-action when no brain exists; the settings dialog no longer pops up uninvited on Send.
- Caveats: the first response on a Tensor G1-class CPU can take a while (long case-context prefill); the AI assessment card caches per fingerprint as before.

## v0.6.1 — Review-fix batch: clusters A+B+C (2026-11-14)
From an external review of the repo (reviewer saw README/PLAN/MainActivity/BootReceiver/manifest, not the Dart layer); Rafi approved clusters A+B+C after evaluation.
- A (manifest): PACKAGE_USAGE_STATS declared (without it the app never appears in Usage-access settings - Cache Radar's data source); INTERNET + ACCESS_NETWORK_STATE in the main manifest (release builds had neither - agent/brain download would fail outside debug); BootReceiver exported=false; backup rules (backup_rules.xml + data_extraction_rules.xml) exclude FlutterSharedPreferences and dr_brain.task from cloud backup AND device transfer - one phone's black box must never be restored onto another phone.
- B (performance): getInstalledApps and listSharedFiles now run on a background thread (runAsync helper) instead of the platform/UI thread; SHA-256 hashing is now collision-only - a file is hashed only if another file shares its exact size (unique sizes cannot be duplicates), in both the legacy and MediaStore passes.
- C (evidence quality): BootReceiver captures shutdown vitals (battery %, temperature, thermal status) at ACTION_SHUTDOWN/REBOOT and writes with commit(); the recorder folds them into the clean-reboot event ("clean broadcast but battery 3% / thermal CRITICAL = suspicious, not calm") and adds a boot-count delta note when boots were hidden (bootloop/pre-unlock boots). Sentinel hygiene: unsupported battery readings (Long.MIN_VALUE current/charge, missing temp/voltage) now return null instead of magic numbers; systemTimeDriftSeconds is honestly null; the SELinux-blind frida-server root check removed; WEEKLY usage-stats buckets are merged per package (sum foreground, max last-used) instead of overwritten.
- Evaluated and NOT adopted: the review's thermal-API crash claim (getThermalHeadroom is API 29, guard is correct), its ACTION_SHUTDOWN delivery doubt (the broadcast is on the implicit-broadcast exemption list and empirically delivered on the Pixel), and its recorder redesign (boot-count inference, framework-restart immunity and first-run baselining were already the v0.2 design, invisible to the reviewer).
