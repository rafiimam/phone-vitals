import 'package:flutter/material.dart';
import '../models/diagnostics.dart';
import '../services/app_scan.dart';
import '../services/file_scan.dart';
import '../services/native_diagnostics.dart';
import '../services/recorder.dart';
import '../widgets/doctor_avatar.dart';

class AppsScanScreen extends StatefulWidget { final List<AppInfoItem> apps; const AppsScanScreen({super.key, required this.apps}); @override State<AppsScanScreen> createState()=>_AppsScanState(); }
class _AppsScanState extends State<AppsScanScreen> {
  Map<String,Map<String,dynamic>> _usage={}; bool _hasAccess=false;
  @override void initState(){ super.initState(); _loadUsage(); }
  Future<void> _loadUsage() async { _hasAccess=await NativeDiagnostics.hasUsageAccess(); if(_hasAccess){ final l=await NativeDiagnostics.usageStats(); _usage={for(final m in l) m['packageName']?.toString()??'': m}; if(mounted) setState((){}); } }
  @override Widget build(BuildContext context){
    final flags=scanApps(widget.apps,_usage);
    return ListView(padding: const EdgeInsets.all(16), children:[
      const Text('Installed Apps Scan', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      Text('${widget.apps.length} apps visible to BlackBox MD. Android 11+ hides apps by default - we use PackageManager queries, NOT QUERY_ALL_PACKAGES (Play will reject that for a diagnostics app).'),
      const SizedBox(height:8),
      if(!_hasAccess) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[const Text('Optional: Usage Access unlocks per-app foreground time (a proxy for drain - not mAh). The core scan works without it.'), FilledButton(onPressed: NativeDiagnostics.openUsageAccessSettings, child: const Text('Open Usage Access settings'))]))),
      if(flags.isEmpty) const Text('No risky apps flagged from installer, age, target SDK or permissions.'),
      ...flags.map((f)=>Card(child: ExpansionTile(title: Text('${f.app.label} - ${f.flags.length} flag(s)'), subtitle: Text(f.app.packageName), children: f.flags.map((x)=>ListTile(leading: const Icon(Icons.flag_outlined), title: Text(x))).toList()))),
      const Divider(), const Text('All apps', style: TextStyle(fontWeight:FontWeight.bold)),
      ...widget.apps.map((a)=>ListTile(title: Text(a.label), subtitle: Text('${a.packageName} - v${a.version} - ${a.isSystem?'System':'User'} - installer ${a.installer}'))),
    ]);
  }
}
class FilesScanScreen extends StatefulWidget { final List<Map<String,dynamic>> files; final VoidCallback? onFilesChanged; const FilesScanScreen({super.key, required this.files, this.onFilesChanged}); @override State<FilesScanScreen> createState()=>_FilesScanState(); }
class _FilesScanState extends State<FilesScanScreen> {
  late List<Map<String,dynamic>> _files;
  final Set<String> _selected = {};
  bool _cleaning = false;
  String? _result;
  bool _resultOk = false;
  @override void initState(){ super.initState(); _files = widget.files; _preselect(); }
  @override void didUpdateWidget(FilesScanScreen old){ super.didUpdateWidget(old); if(!identical(old.files, widget.files)){ _files = widget.files; _selected.clear(); _preselect(); } }
  List<FileIssue> get _issues => scanFiles(_files);
  void _preselect(){
    // Safe junk pre-selected: zero-byte + partial downloads. For duplicates,
    // pre-select every copy EXCEPT the first of each same-size group, so the
    // user never deletes their only copy by default. APKs and possibly
    // corrupted media stay unselected - those need a human decision.
    final seenDupSize = <int>{};
    for(final i in _issues){
      if(i.kind=='Zero-byte file' || i.kind=='Partial download') _selected.add(i.path);
      else if(i.kind=='Possible duplicate'){ if(!seenDupSize.add(i.sizeBytes)) _selected.add(i.path); }
    }
  }
  int get _selectedBytes => _issues.where((i)=>_selected.contains(i.path)).fold(0,(a,i)=>a+i.sizeBytes);
  Future<void> _clean() async {
    final chosen = _issues.where((i)=>_selected.contains(i.path)).toList();
    if(chosen.isEmpty || _cleaning) return;
    setState(()=>_cleaning=true);
    final before = await NativeDiagnostics.memoryStorage();
    final uris = chosen.where((i)=>i.uri.isNotEmpty).map((i)=>i.uri).toList();
    final paths = chosen.where((i)=>i.uri.isEmpty).map((i)=>i.path).toList();
    final ok = await NativeDiagnostics.deleteFiles(uris: uris, paths: paths);
    if(!ok){
      if(mounted) setState((){ _cleaning=false; _resultOk=false; _result='Cleanup cancelled or blocked by Android - nothing was deleted. The consent dialog must be approved for the deletion to happen.'; });
      return;
    }
    final after = await NativeDiagnostics.memoryStorage();
    final chosenPaths = chosen.map((i)=>i.path).toSet();
    final totalBytes = chosen.fold(0,(a,i)=>a+i.sizeBytes);
    await Recorder.add('storage_cleaned', 'Storage Doctor treatment: deleted ${chosen.length} file(s) totalling ${prettySize(totalBytes)} (user-selected, Android consent approved). Storage free measured before: ${before?.freeStorageGb.toStringAsFixed(2) ?? '?'} GB, after: ${after?.freeStorageGb.toStringAsFixed(2) ?? '?'} GB. Files: ${chosenPaths.take(12).join(', ')}');
    if(mounted) setState((){
      _files = _files.where((f)=>!chosenPaths.contains(f['path']?.toString())).toList();
      _selected.clear(); _preselect(); _cleaning=false; _resultOk=true;
      _result='Treatment complete - verified. ${chosen.length} file(s) deleted. Storage free: ${before?.freeStorageGb.toStringAsFixed(2) ?? '?'} GB before -> ${after?.freeStorageGb.toStringAsFixed(2) ?? '?'} GB after (both measured, not estimated). Recorded in the Timeline.';
    });
    widget.onFilesChanged?.call();
  }
  @override Widget build(BuildContext context){
    final issues = _issues;
    return ListView(padding: const EdgeInsets.all(16), children:[
      const Text('Storage Doctor', style: TextStyle(fontSize:22,fontWeight:FontWeight.w800,color: Color(0xFF12283F))),
      const SizedBox(height: 8),
      DoctorCard(mode: DoctorMode.storage, speech: issues.isEmpty ? 'I checked every file Android lets me see - no junk, partial downloads or duplicates found. Storage treatment not needed right now.' : 'I found ${issues.length} item(s) worth your decision below. Nothing is deleted silently: you pick, Android shows its own consent dialog, and afterwards I re-measure your storage to prove what was freed.', happy: issues.isEmpty),
      const SizedBox(height: 8),
      Text('${_files.length} shared files listed by the system media store.'),
      const Card(color: Color(0xFFFFF3E0), child: Padding(padding: EdgeInsets.all(12), child: Text('Honest limits: a normal app CANNOT scan /system or other apps private files, and cannot delete files Android does not expose. The OS itself is checked by Verified Boot at startup. Duplicates: the first copy of each file is never pre-selected.'))),
      if(_result!=null) Card(color: _resultOk ? const Color(0xFFE8F5E9) : const Color(0xFFFEE2E2), child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[DoctorAvatar(mode: DoctorMode.storage, size: 44, happy: _resultOk, concerned: !_resultOk), const SizedBox(width: 10), Expanded(child: Text(_result!))]))),
      if(issues.isNotEmpty) ...[
        const SizedBox(height: 6),
        ...issues.map((i)=>Card(child: CheckboxListTile(value: _selected.contains(i.path), onChanged: (v)=>setState((){ if(v==true) _selected.add(i.path); else _selected.remove(i.path); }), title: Text(i.kind, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${i.path}\n${i.detail}\nSize: ${prettySize(i.sizeBytes)}'), isThreeLine: true, secondary: const Icon(Icons.report_problem_outlined)))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _cleaning ? null : _clean, icon: _cleaning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cleaning_services), label: Text(_selected.isEmpty ? 'Select files to clean' : 'Clean selected - ${prettySize(_selectedBytes)}')),
        const SizedBox(height: 6),
        const Text('Android will show its own consent dialog listing the batch before anything is deleted. Cancelling there deletes nothing.', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
      ],
    ]);
  }
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
    if(k=='storage_cleaned') return 'Storage Doctor treatment';
    if(k=='unclean_exit') return 'App session ended (v0.1 legacy)';
    return k;
  }
  static IconData _icon(String k){
    if(k=='unexpected_reboot') return Icons.power_off;
    if(k=='reboot_clean') return Icons.restart_alt;
    if(k=='safe_mode_started' || k=='safe_mode_result') return Icons.shield_outlined;
    if(k=='storage_cleaned') return Icons.cleaning_services;
    return Icons.event;
  }
  static Color _color(String k){
    if(k=='unexpected_reboot') return Colors.red;
    if(k=='reboot_clean') return const Color(0xFF17457A);
    if(k=='safe_mode_started' || k=='safe_mode_result') return Colors.deepPurple;
    if(k=='storage_cleaned') return const Color(0xFFF97316);
    return Colors.grey;
  }
  @override Widget build(BuildContext context){ return ListView(padding: const EdgeInsets.all(16), children:[
    const Text('Black Box Timeline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF12283F))),
    const SizedBox(height: 4),
    const Text('A reboot is counted only when Android\'s boot count changes. A clean shutdown signal (power menu / update) = normal restart; no signal = the phone died, crashed or lost power. The kernel reason itself is hidden from normal apps. v0.1 "app session ended" entries were app-process restarts, NOT phone shutdowns.'),
    const SizedBox(height: 10),
    if(events.isEmpty) const Text('No events yet. Leave BlackBox MD installed - the recorder learns from the next reboot.'),
    ...events.map((e)=>Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), leading: CircleAvatar(backgroundColor: _color(e.kind).withOpacity(0.12), child: Icon(_icon(e.kind), color: _color(e.kind))), title: Text(_title(e.kind), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${e.time}\n${e.detail}'), isThreeLine:true))),
  ]); }
}
