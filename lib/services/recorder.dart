import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diagnostics.dart';
/// The "black box" - v2.
///
/// v0.1's flaw: it treated "the previous APP session ended without a clean-exit
/// marker" as a possible phone shutdown. Android kills app processes all the
/// time, so that produced false unclean_exit clusters and, worse, could MISS a
/// real reboot (a normal app pause had set the "clean" flag).
///
/// v2 rule: a reboot is counted ONLY when the device's boot identity changes -
/// Android's Settings.Global.BOOT_COUNT increases, or the elapsed-realtime
/// uptime clock goes backwards. At that point, the native BootReceiver's
/// record decides clean vs unexpected: ACTION_SHUTDOWN/ACTION_REBOOT mean the
/// previous boot ended on purpose; their absence after a crash, battery pull
/// or kernel panic means it did not. One event per boot, never per app launch.
/// The true kernel shutdown reason stays unavailable to normal apps - the
/// events are labelled inferred everywhere.
class Recorder {
  static const _eventsKey = 'pv_events';
  static const _heartbeatKey = 'pv_heartbeat_ms';
  static const _vitalsKey = 'pv_last_vitals';
  static const _snapBootKey = 'pv_snap_boot_count';
  static const _snapUptimeKey = 'pv_snap_uptime_ms';
  static const _loggedBootKey = 'pv_logged_boot_key';
  static const _safePendingKey = 'pv_safemode_pending_ms';

  static Future<void> heartbeat({required int batteryPct, required double tempC, required String thermal, int uptimeMs = -1}) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await sp.setInt(_heartbeatKey, now);
    await sp.setString(_vitalsKey, jsonEncode({'pct': batteryPct, 'temp': tempC, 'thermal': thermal, 'ts': now}));
    if (uptimeMs >= 0) await sp.setInt(_snapUptimeKey, uptimeMs);
  }

  static Future<List<RecorderEvent>> checkAndLoad({int bootCount = -1, int uptimeMs = -1}) async {
    final sp = await SharedPreferences.getInstance();
    final events = _decode(sp.getString(_eventsKey));
    final snapBoot = sp.getInt(_snapBootKey);
    final snapUp = sp.getInt(_snapUptimeKey);
    final loggedKey = sp.getInt(_loggedBootKey) ?? -999999;
    var rebooted = false;
    if (bootCount >= 0 && snapBoot != null && bootCount > snapBoot) rebooted = true;
    if (!rebooted && uptimeMs >= 0 && snapUp != null && uptimeMs < snapUp - 60000) rebooted = true;
    final bootKey = bootCount >= 0 ? bootCount : (uptimeMs >= 0 ? -(DateTime.now().millisecondsSinceEpoch - uptimeMs) : 0);
    if (rebooted && bootKey != loggedKey) {
      final prevClean = sp.getBool('pv_prev_boot_clean') ?? sp.getBool('pv_clean_exit') ?? false;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final bootWall = uptimeMs >= 0 ? nowMs - uptimeMs : nowMs;
      if (prevClean) {
        events.add(_chained(events, bootWall, 'reboot_clean', 'Phone restarted with a clean shutdown signal (power menu or system update). Not a failure - recorded so real failures stand out.'));
      } else {
        var vit = '';
        try {
          final raw = sp.getString(_vitalsKey);
          if (raw != null) { final m = jsonDecode(raw) as Map; vit = ' Last heartbeat before it: battery ${m['pct']}%, temp ${m['temp']}C, thermal ${m['thermal']}.'; }
        } catch (_) {}
        final beat = sp.getInt(_heartbeatKey);
        events.add(_chained(events, beat ?? bootWall, 'unexpected_reboot', 'Phone rebooted and NO clean shutdown was recorded - it died, crashed or lost power.$vit Detection: Android boot count changed. The kernel reason itself is hidden from normal apps, so this is inferred - but the reboot is real.'));
      }
      await sp.setInt(_loggedBootKey, bootKey);
      await sp.setString(_eventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
    }
    if (bootCount >= 0) await sp.setInt(_snapBootKey, bootCount);
    if (uptimeMs >= 0) await sp.setInt(_snapUptimeKey, uptimeMs);
    events.sort((a, b) => b.tsMs.compareTo(a.tsMs));
    return events;
  }

  /// Tamper-evident case chain: every event's hash covers the previous
  /// event's hash, its timestamp, kind and detail. Editing, deleting or
  /// reordering any entry breaks every later hash - a repair shop (or a
  /// court of common sense) can recompute the chain from the exported
  /// report and see whether the case file was altered after the fact.
  static String _chainFor(List<RecorderEvent> existing, int ts, String kind, String detail) {
    final prev = existing.isEmpty ? 'GENESIS' : (existing.last.chain.isNotEmpty ? existing.last.chain : 'LEGACY');
    return sha256.convert(utf8.encode('$prev|$ts|$kind|$detail')).toString();
  }
  static RecorderEvent _chained(List<RecorderEvent> existing, int ts, String kind, String detail) =>
      RecorderEvent(ts, kind, detail, chain: _chainFor(existing, ts, kind, detail));

  static Future<void> add(String kind, String detail) async {
    final sp = await SharedPreferences.getInstance();
    final events = _decode(sp.getString(_eventsKey));
    events.add(_chained(events, DateTime.now().millisecondsSinceEpoch, kind, detail));
    await sp.setString(_eventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  // --- Guided Safe Mode test ---
  static Future<void> startSafeModeTest() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_safePendingKey, DateTime.now().millisecondsSinceEpoch);
    await add('safe_mode_started', 'Safe Mode test started from BlackBox MD. The phone is about to be restarted into Safe Mode by hand - third-party apps (including BlackBox MD) do not run there.');
  }
  static Future<int?> safeModePendingSince() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_safePendingKey);
  }
  static Future<void> completeSafeModeTest({required bool stable}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_safePendingKey);
    await add('safe_mode_result', stable
        ? 'Safe Mode test result: STABLE. The phone did NOT die/reboot in Safe Mode - a downloaded third-party app is the prime suspect. Remove recent apps one by one.'
        : 'Safe Mode test result: IT DIED AGAIN in Safe Mode, where third-party apps cannot run. That rules apps out - this points to the OS or hardware (battery first).');
  }

  static List<RecorderEvent> _decode(String? s) {
    if (s == null) return [];
    try { final l = jsonDecode(s) as List; return l.whereType<Map>().map((m) => RecorderEvent.fromJson(m.map((k, v) => MapEntry(k.toString(), v)))).toList(); } catch (_) { return []; }
  }
}
