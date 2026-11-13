import '../models/diagnostics.dart';
import 'health_score.dart';
String buildRepairReport({required String deviceLine, required String androidLine, BatteryDetail? b, ThermalInfo? t, MemoryStorage? ms, SystemIntegrity? sys, required HealthResult health, required List<RecorderEvent> events, required List<String> appFlags, required List<String> fileFlags, String wizardVerdict=''}) {
  final sb=StringBuffer();
  sb.writeln('BlackBox MD - Repair Report'); sb.writeln('Generated: ${DateTime.now()}'); sb.writeln('Device: $deviceLine'); sb.writeln('Android: $androidLine'); sb.writeln('');
  sb.writeln('HEALTH: ${health.score}/100 - ${health.verdict}');
  if (wizardVerdict.isNotEmpty) sb.writeln('Wizard verdict: $wizardVerdict');
  sb.writeln(''); sb.writeln('BATTERY (Measured unless labelled)'); if(b!=null){ sb.writeln('- Level ${b.level}%  Health ${b.health}  Status ${b.status}'); sb.writeln('- Temp ${b.tempC}C  Voltage ${b.voltageMv} mV  CurrentNow ${b.currentNowUa} uA'); sb.writeln('- Cycles ${b.cycleCount}  Technology ${b.technology}'); }
  sb.writeln(''); sb.writeln('THERMAL / MEMORY / STORAGE'); if(t!=null) sb.writeln('- Thermal: ${t.label} headroom ${t.headroom}'); if(ms!=null){ sb.writeln('- RAM total ${ms.totalRamMb} MB avail ${ms.availRamMb} MB lowMemory=${ms.lowMemory}'); sb.writeln('- Storage ${ms.storageUsedPct}% used, ${ms.freeStorageGb} GB free, uptime ${ms.uptimeHours.toStringAsFixed(1)}h'); }
  sb.writeln(''); sb.writeln('SYSTEM INTEGRITY'); if(sys!=null){ sb.writeln('- Security patch ${sys.securityPatch} (${sys.patchAgeDays} days old)'); sb.writeln('- Verified Boot: ${sys.verifiedBootState}  Build: ${sys.buildType}  Debuggable: ${sys.debuggable}'); sb.writeln('- Root suspected: ${sys.rootSuspected} ${sys.rootClues}'); sb.writeln('- NOTE: A normal app cannot hash /system files. Verified Boot checks the OS at startup; a hang at the Google logo can be a failed verified-boot / corrupted OTA - use Pixel Repair (pixelrepair.withgoogle.com) before a wipe.'); }
  sb.writeln(''); sb.writeln('WARNINGS'); for(final x in health.warnings) sb.writeln('- $x'); sb.writeln(''); sb.writeln('GOOD'); for(final x in health.good) sb.writeln('- $x');
  sb.writeln(''); sb.writeln('TIMELINE (reboots detected via Android boot count; clean vs unexpected judged by the shutdown broadcast; kernel reason unavailable to apps)'); for(final e in events.take(30)) sb.writeln('- ${e.time} [${e.kind}] ${e.detail}');
  sb.writeln(''); sb.writeln('APP FLAGS'); for(final x in appFlags.take(30)) sb.writeln('- $x'); sb.writeln(''); sb.writeln('FILE FLAGS'); for(final x in fileFlags.take(30)) sb.writeln('- $x');
  sb.writeln(''); sb.writeln('Labels: Measured = read from Android API. Estimated = calculated over time. Unavailable = Android blocks it for normal apps (no root).');
  return sb.toString();
}
