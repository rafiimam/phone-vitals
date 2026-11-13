import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diagnostics.dart';
/// The "black box": persists a heartbeat + a clean-shutdown marker.
/// On launch, if the previous session had a heartbeat but NO clean-exit
/// marker and uptime has reset, we infer an unclean shutdown.
/// This is an INFERENCE - Android blocks the true kernel boot reason
/// for normal apps. We label it that way everywhere in the UI.
class Recorder {
  static const _eventsKey='pv_events'; static const _heartbeatKey='pv_heartbeat_ms'; static const _cleanKey='pv_clean_exit';
  static Future<void> heartbeat({required int batteryPct, required double tempC, required String thermal}) async {
    final sp=await SharedPreferences.getInstance();
    await sp.setInt(_heartbeatKey, DateTime.now().millisecondsSinceEpoch);
    await sp.setBool(_cleanKey, false);
    await sp.setString('pv_last_vitals', jsonEncode({'pct':batteryPct,'temp':tempC,'thermal':thermal,'ts':DateTime.now().millisecondsSinceEpoch}));
  }
  static Future<void> markCleanExit() async { final sp=await SharedPreferences.getInstance(); await sp.setBool(_cleanKey, true); }
  static Future<List<RecorderEvent>> checkAndLoad() async {
    final sp=await SharedPreferences.getInstance();
    final events=_decode(sp.getString(_eventsKey));
    final lastBeat=sp.getInt(_heartbeatKey); final clean=sp.getBool(_cleanKey)??true;
    if (lastBeat!=null && !clean) {
      // A previous session ended without a clean marker.
      // We cannot know if it was a crash of THIS app vs a whole-phone shutdown,
      // so the wording stays "unclean exit / possible shutdown".
      final already=events.any((e)=>e.tsMs==lastBeat && e.kind=='unclean_exit');
      if (!already) { events.add(RecorderEvent(lastBeat,'unclean_exit','Previous session ended without a clean shutdown marker. If the whole phone died, this was an unexpected shutdown - inferred, not a kernel reason.')); await sp.setString(_eventsKey, jsonEncode(events.map((e)=>e.toJson()).toList())); }
    }
    await sp.setBool(_cleanKey, false);
    events.sort((a,b)=>b.tsMs.compareTo(a.tsMs)); return events;
  }
  static Future<void> add(String kind, String detail) async { final sp=await SharedPreferences.getInstance(); final events=_decode(sp.getString(_eventsKey)); events.add(RecorderEvent(DateTime.now().millisecondsSinceEpoch,kind,detail)); await sp.setString(_eventsKey, jsonEncode(events.map((e)=>e.toJson()).toList())); }
  static List<RecorderEvent> _decode(String? s){ if(s==null) return []; try { final l=jsonDecode(s) as List; return l.whereType<Map>().map((m)=>RecorderEvent.fromJson(m.map((k,v)=>MapEntry(k.toString(),v)))).toList(); } catch(_){ return []; } }
  static int bootCount(SharedPreferences sp)=>sp.getInt('pv_boot_count')??0;
}
