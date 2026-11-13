# PhoneVitals — Product Plan

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
