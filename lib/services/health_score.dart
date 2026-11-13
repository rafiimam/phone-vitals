import '../models/diagnostics.dart';
class HealthResult { final int score; final String verdict; final List<String> warnings; final List<String> good; const HealthResult(this.score,this.verdict,this.warnings,this.good); }
HealthResult evaluateHealth({BatteryDetail? b, ThermalInfo? t, MemoryStorage? ms, SystemIntegrity? sys, int uncleanCount=0}) {
  var score=100; final w=<String>[]; final g=<String>[];
  if (b!=null) {
    if (b.health!='Good' && b.health!='Unknown') { score-=30; w.add('Battery health reported as: ${b.health}'); } else { g.add('Battery health flag: ${b.health} (Measured)'); }
    if (b.tempC>=45) { score-=25; w.add('Battery very hot: ${b.tempC.toStringAsFixed(1)}C - let it cool, remove case, do not charge while hot'); }
    else if (b.tempC>=40) { score-=12; w.add('Battery warm: ${b.tempC.toStringAsFixed(1)}C'); }
    else if (b.tempC>0) { g.add('Battery temperature normal: ${b.tempC.toStringAsFixed(1)}C (Measured)'); }
    if (b.cycleCount>800) { score-=15; w.add('Battery cycles: ${b.cycleCount} - past the ~800-cycle point Google rates Pixel batteries to ~80% capacity. Wear is likely (Measured cycles, Estimated wear)'); }
    else if (b.cycleCount>=0) { g.add('Battery cycles: ${b.cycleCount} (Measured, Android 14+)'); }
  }
  if (ms!=null) {
    if (ms.storageUsedPct>=95) { score-=20; w.add('Storage ${ms.storageUsedPct}% full - below 10% free can cause hangs and failed boots. Free space now'); }
    else if (ms.storageUsedPct>=90) { score-=10; w.add('Storage high: ${ms.storageUsedPct}% used'); } else { g.add('Storage OK: ${ms.storageUsedPct}% used, ${ms.freeStorageGb.toStringAsFixed(1)} GB free (Measured)'); }
    if (ms.lowMemory) { score-=12; w.add('System is reporting low memory right now'); }
  }
  if (t!=null) { if (t.status>=3) { score-=20; w.add('Thermal status: ${t.label} - phone is throttling to protect itself'); } else { g.add('Thermal: ${t.label} (Measured)'); } }
  if (sys!=null) { final age=sys.patchAgeDays; if (age>180) { score-=10; w.add('Security patch is $age days old (${sys.securityPatch}) - check for a system update'); } if (sys.rootSuspected) { score-=8; w.add('Root / modified system suspected: ${sys.rootClues.join(', ')} - this can break updates and banking apps'); } if (sys.verifiedBootState=='orange' || sys.verifiedBootState=='red') { score-=15; w.add('Verified Boot state: ${sys.verifiedBootState} - bootloader unlocked / system may be modified'); } }
  if (uncleanCount==1) { score-=10; w.add('1 unexpected reboot recorded (boot count changed, no clean shutdown) - note the battery % and what you were doing, and back up'); }
  else if (uncleanCount>=2) { score-=15; w.add('$uncleanCount unexpected reboots recorded - failure is repeating, back up today'); }
  score=score.clamp(0,100);
  final verdict= score>=85?'Healthy':score>=65?'Mostly OK - watch the warnings':score>=40?'Struggling - follow the Verdict Wizard':'Critical - back up NOW, hardware fault is likely';
  return HealthResult(score, verdict, w, g);
}
