import 'package:flutter/services.dart';
import '../models/diagnostics.dart';
/// Thin wrapper over the Kotlin MethodChannel in MainActivity.kt.
/// Every method returns null / empty on failure - the UI must label that
/// "Unavailable on this device", never invent a value.
class NativeDiagnostics {
  static const _ch = MethodChannel('com.rafiimam.phonevitals/diagnostics');
  static Future<BatteryDetail?> battery() async { try { final m = await _ch.invokeMethod('getBatteryDetail'); if (m is Map) return BatteryDetail.fromMap(m); } catch (_) {} return null; }
  static Future<ThermalInfo?> thermal() async { try { final m = await _ch.invokeMethod('getThermal'); if (m is Map) return ThermalInfo.fromMap(m); } catch (_) {} return null; }
  static Future<MemoryStorage?> memoryStorage() async { try { final m = await _ch.invokeMethod('getMemoryStorage'); if (m is Map) return MemoryStorage.fromMap(m); } catch (_) {} return null; }
  static Future<Map<String,dynamic>> cpuInfo() async { try { final m = await _ch.invokeMethod('getCpuInfo'); if (m is Map) return m.map((k,v)=>MapEntry(k.toString(), v)); } catch (_) {} return {}; }
  static Future<List<Map<String,dynamic>>> sensors() async { try { final l = await _ch.invokeMethod('getSensors'); if (l is List) return l.whereType<Map>().map((m)=>m.map((k,v)=>MapEntry(k.toString(), v))).toList(); } catch (_) {} return []; }
  static Future<List<AppInfoItem>> installedApps() async { try { final l = await _ch.invokeMethod('getInstalledApps'); if (l is List) return l.whereType<Map>().map(AppInfoItem.fromMap).toList(); } catch (_) {} return []; }
  static Future<SystemIntegrity?> systemIntegrity() async { try { final m = await _ch.invokeMethod('getSystemIntegrity'); if (m is Map) return SystemIntegrity.fromMap(m); } catch (_) {} return null; }
  static Future<Map<String,dynamic>> bootInfo() async { try { final m = await _ch.invokeMethod('getBootInfo'); if (m is Map) return m.map((k,v)=>MapEntry(k.toString(), v)); } catch (_) {} return {}; }
  static Future<bool> hasUsageAccess() async { try { return await _ch.invokeMethod('hasUsageAccess') == true; } catch (_) { return false; } }
  static Future<void> openUsageAccessSettings() async { try { await _ch.invokeMethod('openUsageAccessSettings'); } catch (_) {} }
  static Future<List<Map<String,dynamic>>> usageStats() async { try { final l = await _ch.invokeMethod('getUsageStats'); if (l is List) return l.whereType<Map>().map((m)=>m.map((k,v)=>MapEntry(k.toString(), v))).toList(); } catch (_) {} return []; }
  static Future<List<Map<String,dynamic>>> sharedFiles() async { try { final l = await _ch.invokeMethod('listSharedFiles'); if (l is List) return l.whereType<Map>().map((m)=>m.map((k,v)=>MapEntry(k.toString(), v))).toList(); } catch (_) {} return []; }
  /// Storage Doctor deletion. URIs are deleted only after Android's own
  /// consent dialog approves the exact batch; returns false if the user
  /// cancelled or anything failed - the UI must then say nothing was deleted.
  static Future<bool> deleteFiles({required List<String> uris, required List<String> paths}) async { try { return await _ch.invokeMethod('deleteFiles', {'uris': uris, 'paths': paths}) == true; } catch (_) { return false; } }
  /// Cache Radar: per-app app/data/cache bytes from Android's
  /// StorageStatsManager. Requires the user-granted Usage Access
  /// (PACKAGE_USAGE_STATS); empty without it - never estimated.
  static Future<List<Map<String,dynamic>>> appStorageStats() async { try { final l = await _ch.invokeMethod('getAppStorageStats'); if (l is List) return l.whereType<Map>().map((m)=>m.map((k,v)=>MapEntry(k.toString(), v))).toList(); } catch (_) {} return []; }
  static Future<void> openAppSettings(String packageName) async { try { await _ch.invokeMethod('openAppSettings', {'package': packageName}); } catch (_) {} }
  /// Android keeps process-exit reasons ONLY for our own UID
  /// (ApplicationExitInfo). This tells us if BlackBox MD itself was
  /// force-stopped, low-memory killed or crashed - recorder self-awareness.
  static Future<List<Map<String,dynamic>>> ownExitReasons() async { try { final l = await _ch.invokeMethod('getOwnExitReasons'); if (l is List) return l.whereType<Map>().map((m)=>m.map((k,v)=>MapEntry(k.toString(), v))).toList(); } catch (_) {} return []; }
}
