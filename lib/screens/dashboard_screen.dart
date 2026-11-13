import 'package:flutter/material.dart';
import '../models/diagnostics.dart';
import '../services/health_score.dart';
class DashboardScreen extends StatelessWidget {
  final bool loading; final BatteryDetail? battery; final ThermalInfo? thermal; final MemoryStorage? mem; final SystemIntegrity? sys; final HealthResult health; final String deviceLine; final String androidLine; final VoidCallback onRefresh; final VoidCallback onShare;
  const DashboardScreen({super.key, required this.loading, required this.battery, required this.thermal, required this.mem, required this.sys, required this.health, required this.deviceLine, required this.androidLine, required this.onRefresh, required this.onShare});
  @override Widget build(BuildContext context){
    final color= health.score>=85?Colors.green:health.score>=65?Colors.orange:health.score>=40?Colors.deepOrange:Colors.red;
    return RefreshIndicator(onRefresh:() async=>onRefresh(), child: ListView(padding: const EdgeInsets.all(16), children:[
      Text(deviceLine, style: Theme.of(context).textTheme.titleLarge), Text(androidLine), const SizedBox(height:16),
      Card(color: color.withOpacity(0.12), child: Padding(padding: const EdgeInsets.all(20), child: Column(children:[Text('${health.score}', style: TextStyle(fontSize:56,fontWeight:FontWeight.bold,color:color)), Text(health.verdict, textAlign:TextAlign.center, style: const TextStyle(fontSize:16,fontWeight:FontWeight.w600)), const SizedBox(height:8), const Text('Every value is labelled Measured / Estimated / Unavailable. No fake boost, clean or cool claims.', textAlign:TextAlign.center)]))),
      const SizedBox(height:12),
      if(battery!=null) _tile('Battery', '${battery!.level}% - ${battery!.status}', 'Health ${battery!.health} - Temp ${battery!.tempC.toStringAsFixed(1)}C - ${battery!.voltageMv} mV - Cycles ${battery!.cycleCount<0?'Unavailable':battery!.cycleCount} - ${battery!.technology}', Icons.battery_charging_full),
      if(thermal!=null) _tile('Thermal', thermal!.label, 'Headroom: ${thermal!.headroom.isNaN?'Unavailable':thermal!.headroom.toStringAsFixed(2)} - Severe thermal + hot battery is a shutdown pattern', Icons.thermostat),
      if(mem!=null) _tile('Memory & Storage', 'Storage ${mem!.storageUsedPct}% used - ${mem!.freeStorageGb.toStringAsFixed(1)} GB free', 'RAM ${mem!.totalRamMb} MB total, ${mem!.availRamMb} MB available, lowMemory=${mem!.lowMemory} - Uptime ${mem!.uptimeHours.toStringAsFixed(1)}h', Icons.storage),
      const SizedBox(height:8), const Text('Warnings', style: TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
      if(health.warnings.isEmpty) const Text('No warnings from the signals we can measure.'),
      ...health.warnings.map((e)=>ListTile(leading: const Icon(Icons.warning_amber,color:Colors.orange), title: Text(e))),
      const Text('Good signs', style: TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
      ...health.good.map((e)=>ListTile(leading: const Icon(Icons.check_circle,color:Colors.green), title: Text(e))),
      const SizedBox(height:12), FilledButton.icon(onPressed:onShare, icon: const Icon(Icons.share), label: const Text('Share repair report')),
      const SizedBox(height:8), const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Hot or swollen phone? Stop. If the screen/back is lifting, it smells, or it is too hot to hold: power off, do not charge it, and take it to a shop. Back up in the first window it stays on.'))),
    ]));
  }
  Widget _tile(String t,String s,String d,IconData i)=>Card(child: ListTile(leading: Icon(i), title: Text(t), subtitle: Text('$s\n$d'), isThreeLine:true));
}
