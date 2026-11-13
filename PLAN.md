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
