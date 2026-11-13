import 'package:flutter/material.dart';
import '../models/diagnostics.dart';
import '../services/app_scan.dart';
import '../services/file_scan.dart';
import '../services/native_diagnostics.dart';

class AppsScanScreen extends StatefulWidget { final List<AppInfoItem> apps; const AppsScanScreen({super.key, required this.apps}); @override State<AppsScanScreen> createState()=>_AppsScanState(); }
class _AppsScanState extends State<AppsScanScreen> {
  Map<String,Map<String,dynamic>> _usage={}; bool _hasAccess=false;
  @override void initState(){ super.initState(); _loadUsage(); }
  Future<void> _loadUsage() async { _hasAccess=await NativeDiagnostics.hasUsageAccess(); if(_hasAccess){ final l=await NativeDiagnostics.usageStats(); _usage={for(final m in l) m['packageName']?.toString()??'': m}; if(mounted) setState((){}); } }
  @override Widget build(BuildContext context){
    final flags=scanApps(widget.apps,_usage);
    return ListView(padding: const EdgeInsets.all(16), children:[
      const Text('Installed Apps Scan', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      Text('${widget.apps.length} apps visible to PhoneVitals. Android 11+ hides apps by default - we use PackageManager queries, NOT QUERY_ALL_PACKAGES (Play will reject that for a diagnostics app).'),
      const SizedBox(height:8),
      if(!_hasAccess) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[const Text('Optional: Usage Access unlocks per-app foreground time (a proxy for drain - not mAh). The core scan works without it.'), FilledButton(onPressed: NativeDiagnostics.openUsageAccessSettings, child: const Text('Open Usage Access settings'))]))),
      if(flags.isEmpty) const Text('No risky apps flagged from installer, age, target SDK or permissions.'),
      ...flags.map((f)=>Card(child: ExpansionTile(title: Text('${f.app.label} - ${f.flags.length} flag(s)'), subtitle: Text(f.app.packageName), children: f.flags.map((x)=>ListTile(leading: const Icon(Icons.flag_outlined), title: Text(x))).toList()))),
      const Divider(), const Text('All apps', style: TextStyle(fontWeight:FontWeight.bold)),
      ...widget.apps.map((a)=>ListTile(title: Text(a.label), subtitle: Text('${a.packageName} - v${a.version} - ${a.isSystem?'System':'User'} - installer ${a.installer}'))),
    ]);
  }
}
class FilesScanScreen extends StatelessWidget { final List<Map<String,dynamic>> files; const FilesScanScreen({super.key, required this.files});
  @override Widget build(BuildContext context){ final issues=scanFiles(files); return ListView(padding: const EdgeInsets.all(16), children:[
    const Text('Files & Storage Scan', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    Text('${files.length} shared files listed by the system media store. We flag zero-byte, partial downloads, APKs, possibly corrupted media and duplicates over 1 MB.'),
    const Card(color: Color(0xFFFFF3E0), child: Padding(padding: EdgeInsets.all(12), child: Text('Honest limit: a normal app CANNOT scan /system or other apps private files. The OS itself is checked by Verified Boot at startup - a hang at the Google logo can be that check failing or a corrupted update. For OS corruption, use the System tab and Pixel Repair, not a file scan.'))),
    if(issues.isEmpty) const Text('No file issues found in the files Android let us see.'),
    ...issues.map((i)=>Card(child: ListTile(leading: const Icon(Icons.report_problem_outlined), title: Text(i.kind), subtitle: Text('${i.path}\n${i.detail}\nSize: ${prettySize(i.sizeBytes)}'), isThreeLine:true))),
  ]); }
}
class SystemScreen extends StatelessWidget { final SystemIntegrity? sys; final String androidLine; const SystemScreen({super.key, required this.sys, required this.androidLine});
  @override Widget build(BuildContext context){ return ListView(padding: const EdgeInsets.all(16), children:[
    const Text('OS / System Integrity', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)), Text(androidLine), const SizedBox(height:12),
    if(sys==null) const Text('System integrity: Unavailable on this device / build.'),
    if(sys!=null) ...[
      ListTile(title: const Text('Security patch'), subtitle: Text('${sys!.securityPatch} - ${sys!.patchAgeDays<0?'date unavailable':'${sys!.patchAgeDays} days old'}')),
      ListTile(title: const Text('Verified Boot state'), subtitle: Text(sys!.verifiedBootState=='unavailable'?'Unavailable - Android blocks the true boot reason for normal apps':sys!.verifiedBootState)),
      ListTile(title: const Text('Build'), subtitle: Text('${sys!.buildType} - OS debuggable (ro.debuggable): ${sys!.debuggable}')),
      ListTile(title: const Text('Root / modification'), subtitle: Text(sys!.rootSuspected?'Suspected: ${sys!.rootClues.join(', ')}':'No common root clues found (heuristic, not proof)')),
      ListTile(title: const Text('Fingerprint'), subtitle: Text(sys!.fingerprint)),
    ],
    const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('If you suspect a corrupted OS / failed update: 1) Keep >10% storage free 2) Check system + Play system updates 3) On a computer try Pixel Update & Software Repair (pixelrepair.withgoogle.com) - it can reinstall software without a wipe in some cases 4) Factory reset is LAST - it erases everything 5) If it still loops after a clean reset with nothing restored, it is hardware.'))),
  ]); }
}
class TimelineScreen extends StatelessWidget { final List<RecorderEvent> events; const TimelineScreen({super.key, required this.events});
  static String _title(String k){
    if(k=='unexpected_reboot') return 'Unexpected reboot';
    if(k=='reboot_clean') return 'Normal restart';
    if(k=='safe_mode_started') return 'Safe Mode test started';
    if(k=='safe_mode_result') return 'Safe Mode test result';
    if(k=='unclean_exit') return 'App session ended (v0.1 legacy)';
    return k;
  }
  static IconData _icon(String k){
    if(k=='unexpected_reboot') return Icons.power_off;
    if(k=='reboot_clean') return Icons.restart_alt;
    if(k=='safe_mode_started' || k=='safe_mode_result') return Icons.shield_outlined;
    return Icons.event;
  }
  static Color _color(String k){
    if(k=='unexpected_reboot') return Colors.red;
    if(k=='reboot_clean') return const Color(0xFF17457A);
    if(k=='safe_mode_started' || k=='safe_mode_result') return Colors.deepPurple;
    return Colors.grey;
  }
  @override Widget build(BuildContext context){ return ListView(padding: const EdgeInsets.all(16), children:[
    const Text('Black Box Timeline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF12283F))),
    const SizedBox(height: 4),
    const Text('A reboot is counted only when Android\'s boot count changes. A clean shutdown signal (power menu / update) = normal restart; no signal = the phone died, crashed or lost power. The kernel reason itself is hidden from normal apps. v0.1 "app session ended" entries were app-process restarts, NOT phone shutdowns.'),
    const SizedBox(height: 10),
    if(events.isEmpty) const Text('No events yet. Leave PhoneVitals installed - the recorder learns from the next reboot.'),
    ...events.map((e)=>Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), leading: CircleAvatar(backgroundColor: _color(e.kind).withOpacity(0.12), child: Icon(_icon(e.kind), color: _color(e.kind))), title: Text(_title(e.kind), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${e.time}\n${e.detail}'), isThreeLine:true))),
  ]); }
}
