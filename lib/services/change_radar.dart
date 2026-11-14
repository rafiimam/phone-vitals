import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diagnostics.dart';

/// Change Radar - the forensic question snapshot apps never ask:
/// "WHAT CHANGED since last time?" Phones rarely die for no reason; they
/// die after an app update, an OS patch, a storage jump. Every launch,
/// BlackBox MD diffs the current device snapshot against the previous one
/// and logs the deltas as case evidence, so a death can be lined up
/// against whatever changed just before it.
class ChangeRadar {
  static const _key = 'pv_snapshot_v1';

  static Future<List<String>> diff({
    required List<AppInfoItem> apps,
    SystemIntegrity? sys,
    MemoryStorage? mem,
    BatteryDetail? battery,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final curApps = {for (final a in apps) a.packageName: a.lastUpdateMs};
    final cur = <String, dynamic>{
      'apps': curApps,
      'patch': sys?.securityPatch ?? '',
      'fp': sys?.fingerprint ?? '',
      'storagePct': mem?.storageUsedPct ?? -1,
      'cycles': battery?.cycleCount ?? -1,
    };
    final raw = sp.getString(_key);
    await sp.setString(_key, jsonEncode(cur));
    if (raw == null) return []; // first snapshot: baseline only, no fake "changes"
    Map prev;
    try {
      prev = jsonDecode(raw) as Map;
    } catch (_) {
      return [];
    }
    final prevApps = ((prev['apps'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    final changes = <String>[];
    for (final e in curApps.entries) {
      if (!prevApps.containsKey(e.key)) {
        changes.add('App installed: ${e.key}');
      } else if (e.value > 0 && prevApps[e.key] != e.value) {
        changes.add('App updated: ${e.key}');
      }
    }
    for (final k in prevApps.keys) {
      if (!curApps.containsKey(k)) changes.add('App removed: $k');
    }
    final prevPatch = prev['patch']?.toString() ?? '';
    final curPatch = cur['patch'] as String;
    if (curPatch.isNotEmpty && prevPatch.isNotEmpty && prevPatch != curPatch) {
      changes.add('Security patch changed: $prevPatch -> $curPatch');
    }
    final prevFp = prev['fp']?.toString() ?? '';
    final curFp = cur['fp'] as String;
    if (curFp.isNotEmpty && prevFp.isNotEmpty && prevFp != curFp) {
      changes.add('System build changed (OS update or reflash): the fingerprint differs from the last snapshot');
    }
    final ps = (prev['storagePct'] as num?)?.toInt() ?? -1;
    final cs = cur['storagePct'] as int;
    if (ps >= 0 && cs >= 0 && (cs - ps).abs() >= 5) {
      changes.add('Storage usage jumped: $ps% -> $cs% used');
    }
    final pc = (prev['cycles'] as num?)?.toInt() ?? -1;
    final cc = cur['cycles'] as int;
    if (pc >= 0 && cc > pc) {
      changes.add('Battery cycle count moved: $pc -> $cc');
    }
    return changes;
  }
}
