import 'package:flutter/material.dart';
import '../models/diagnostics.dart';
import '../services/health_score.dart';
import '../theme/vital_orbit.dart';
import '../widgets/evidence_chip.dart';
class DashboardScreen extends StatelessWidget {
  final bool loading; final BatteryDetail? battery; final ThermalInfo? thermal; final MemoryStorage? mem; final SystemIntegrity? sys; final HealthResult health; final String deviceLine; final String androidLine; final VoidCallback onRefresh; final VoidCallback onShare;
  const DashboardScreen({super.key, required this.loading, required this.battery, required this.thermal, required this.mem, required this.sys, required this.health, required this.deviceLine, required this.androidLine, required this.onRefresh, required this.onShare});
  Color get _band => health.score>=85 ? const Color(0xFF4ADE80) : health.score>=65 ? const Color(0xFFFBBF24) : health.score>=40 ? const Color(0xFFFB923C) : const Color(0xFFF87171);
  @override Widget build(BuildContext context){
    return RefreshIndicator(onRefresh:() async=>onRefresh(), child: ListView(padding: const EdgeInsets.all(16), children:[
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors:[Color(0xFF17457A), Color(0xFF2E6DA8)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Row(children:[const Icon(Icons.phone_android, color: Colors.white70, size: 20), const SizedBox(width: 8), Expanded(child: Text(deviceLine, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)))]),
          Text(androidLine, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 18),
          Row(children:[
            SizedBox(width: 132, height: 132, child: Stack(fit: StackFit.expand, children:[
              CircularProgressIndicator(value: health.score/100, strokeWidth: 13, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation<Color>(_band), strokeCap: StrokeCap.round),
              Center(child: Column(mainAxisSize: MainAxisSize.min, children:[Text('${health.score}', style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1)), const Text('of 100', style: TextStyle(color: Colors.white70, fontSize: 12))])),
            ])),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Text(health.verdict, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Every value is labelled Measured / Estimated / Unavailable. No fake boost, clean or cool claims.', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            ])),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if(battery!=null) const EvidenceChip(kind: Evidence.measured, label: 'Battery temperature', source: 'BatteryManager EXTRA_TEMPERATURE', why: 'Read straight from the battery fuel gauge - a real measurement of the battery (not the CPU, which normal apps cannot read).'),
        if(battery!=null) EvidenceChip(kind: battery!.cycleCount>=0 ? Evidence.measured : Evidence.unavailable, label: 'Battery cycles', source: 'BatteryManager BATTERY_PROPERTY_CYCLE_COUNT', why: battery!.cycleCount>=0 ? 'Android reports the charge-cycle count directly on Android 14 and newer.' : 'Cycle count needs Android 14 or newer, or the maker did not expose it - so this phone cannot report it, and we show Unavailable instead of guessing.'),
        const EvidenceChip(kind: Evidence.estimated, label: 'Health score', source: 'BlackBox MD heuristic', why: 'The inputs are measured; the single combined score is an estimate - a guide, not a lab grade.'),
        if(mem!=null) const EvidenceChip(kind: Evidence.measured, label: 'Storage used', source: 'StatFs + ActivityManager', why: 'The OS reports total and free bytes directly. Keeping more than 10% free matters: a nearly-full phone can hang and fail to boot.'),
        if(thermal!=null) EvidenceChip(kind: thermal!.headroom.isNaN ? Evidence.unavailable : Evidence.measured, label: 'Thermal headroom', source: 'PowerManager getThermalHeadroom (API 29+)', why: thermal!.headroom.isNaN ? 'This device did not return a headroom value, so we show the OS thermal status label instead and mark headroom Unavailable.' : 'How much thermal room the OS believes remains before throttling: 1.0 is cool, near 0 means throttling is imminent.'),
      ]),
      const SizedBox(height: 8),
      if(battery!=null) _tile('Battery', '${battery!.level}% - ${battery!.status}', 'Health ${battery!.health} - Temp ${battery!.tempC.toStringAsFixed(1)}C - ${battery!.voltageMv} mV - Cycles ${battery!.cycleCount<0?'Unavailable':battery!.cycleCount} - ${battery!.technology}', Icons.battery_charging_full, const Color(0xFF2E7D32)),
      if(thermal!=null) _tile('Thermal', thermal!.label, 'Headroom: ${thermal!.headroom.isNaN?'Unavailable':thermal!.headroom.toStringAsFixed(2)} - Severe thermal + hot battery is a shutdown pattern', Icons.thermostat, const Color(0xFFC62828)),
      if(mem!=null) _tile('Memory & Storage', 'Storage ${mem!.storageUsedPct}% used - ${mem!.freeStorageGb.toStringAsFixed(1)} GB free', 'RAM ${mem!.totalRamMb} MB total, ${mem!.availRamMb} MB available, lowMemory=${mem!.lowMemory} - Uptime ${mem!.uptimeHours.toStringAsFixed(1)}h', Icons.storage, const Color(0xFF17457A)),
      const SizedBox(height: 10),
      _sectionTitle(context, 'Warnings', Icons.warning_amber, Colors.orange),
      if(health.warnings.isEmpty) const Padding(padding: EdgeInsets.only(left: 4, bottom: 6), child: Text('No warnings from the signals we can measure.')),
      ...health.warnings.map((e)=>Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.warning_amber, color: Colors.orange, size: 20)), title: Text(e)))),
      _sectionTitle(context, 'Good signs', Icons.check_circle, Colors.green),
      ...health.good.map((e)=>Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.check, color: Colors.green, size: 20)), title: Text(e)))),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed:onShare, icon: const Icon(Icons.share), label: const Text('Share repair report')),
      const SizedBox(height: 10),
      const Card(color: Color(0xFFFFF3E0), child: Padding(padding: EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[Icon(Icons.local_fire_department, color: Colors.deepOrange), SizedBox(width: 10), Expanded(child: Text('Hot or swollen phone? Stop. If the screen/back is lifting, it smells, or it is too hot to hold: power off, do not charge it, and take it to a shop. Back up in the first window it stays on.'))]))),
    ]));
  }
  Widget _sectionTitle(BuildContext c, String t, IconData i, Color col)=>Padding(padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4), child: Row(children:[Icon(i, size: 19, color: col), const SizedBox(width: 7), Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: BOTokens.of(c).textPrimary))]));
  Widget _tile(String t,String s,String d,IconData i,Color col)=>Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), leading: CircleAvatar(backgroundColor: col.withOpacity(0.12), child: Icon(i, color: col)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('$s\n$d'), isThreeLine:true));
}
