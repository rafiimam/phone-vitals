import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../models/diagnostics.dart';
import '../services/native_diagnostics.dart';
import '../services/health_score.dart';
import '../services/recorder.dart';
import '../services/app_scan.dart';
import '../services/file_scan.dart';
import '../services/report_generator.dart';
import '../services/change_radar.dart';
import 'dashboard_screen.dart';
import 'agent_screen.dart';
import '../services/doctor_brain.dart';
import 'case_file_screen.dart';
import 'scan_screens.dart';
import 'wizard_screen.dart';

class HomeShell extends StatefulWidget { const HomeShell({super.key}); @override State<HomeShell> createState()=>_HomeShellState(); }
class _HomeShellState extends State<HomeShell> {
  int _idx=0; bool _loading=true;
  BatteryDetail? _battery; ThermalInfo? _thermal; MemoryStorage? _mem; SystemIntegrity? _sys;
  List<RecorderEvent> _events=[]; String _deviceLine='Unknown device'; String _androidLine='Unknown Android';
  List<AppInfoItem> _apps=[]; List<Map<String,dynamic>> _files=[]; List<String> _changes=[];
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    setState(()=>_loading=true);
    try { final di=await DeviceInfoPlugin().androidInfo; _deviceLine='${di.manufacturer} ${di.model} (${di.device})'; _androidLine='Android ${di.version.release} SDK ${di.version.sdkInt}, patch ${di.version.securityPatch}'; } catch(_){}
    _battery=await NativeDiagnostics.battery(); _thermal=await NativeDiagnostics.thermal(); _mem=await NativeDiagnostics.memoryStorage(); _sys=await NativeDiagnostics.systemIntegrity();
    final boot=await NativeDiagnostics.bootInfo(); final bc=(boot['bootCount'] as num?)?.toInt()??-1; final up=(boot['uptimeMs'] as num?)?.toInt()??-1;
    _events=await Recorder.checkAndLoad(bootCount:bc, uptimeMs:up);
    if(_battery!=null) await Recorder.heartbeat(batteryPct:_battery!.level, tempC:_battery!.tempC, thermal:_thermal?.label??'unknown', uptimeMs:up);
    _apps=await NativeDiagnostics.installedApps(); _files=await NativeDiagnostics.sharedFiles();
    _changes=await ChangeRadar.diff(apps:_apps, sys:_sys, mem:_mem, battery:_battery);
    if(_changes.isNotEmpty){
      if(_changes.length<=6){ for(final c in _changes) await Recorder.add('change_detected', c); }
      else { await Recorder.add('change_detected', '${_changes.length} changes since last check: ${_changes.take(6).join('; ')}; and more - see Apps/System tabs'); }
      _events=await Recorder.checkAndLoad(bootCount:bc, uptimeMs:up);
    }
    if(mounted) setState(()=>_loading=false);
  }
  String _caseContext(){
    final appFlags=scanApps(_apps,{}).map((f)=>'${f.app.label}: ${f.flags.join('; ')}').toList();
    final fileFlags=scanFiles(_files).map((f)=>'${f.kind}: ${f.path}').toList();
    return DoctorBrain.buildContext(deviceLine:_deviceLine, androidLine:_androidLine, health:_health, b:_battery, t:_thermal, ms:_mem, sys:_sys, events:_events, changes:_changes, appFlags:appFlags, fileFlags:fileFlags);
  }
  void _openAgent(){
    Navigator.push(context, MaterialPageRoute(builder:(_)=>AgentScreen(caseContext:_caseContext(), onOpenWizard:()=>setState(()=>_idx=6), onOpenApps:()=>setState(()=>_idx=2), onOpenFiles:()=>setState(()=>_idx=3), onShare:_shareReport)));
  }
  HealthResult get _health=>evaluateHealth(b:_battery,t:_thermal,ms:_mem,sys:_sys,uncleanCount:_events.where((e)=>e.kind=='unexpected_reboot').length);
  Future<void> _shareReport() async {
    final appFlags=scanApps(_apps,{}).map((f)=>'${f.app.label} (${f.app.packageName}): ${f.flags.join('; ')}').toList();
    final fileFlags=scanFiles(_files).map((f)=>'${f.kind}: ${f.path} - ${f.detail}').toList();
    final text=buildRepairReport(deviceLine:_deviceLine, androidLine:_androidLine, b:_battery,t:_thermal,ms:_mem,sys:_sys,health:_health,events:_events,appFlags:appFlags,fileFlags:fileFlags);
    await Share.share(text, subject:'BlackBox MD Repair Report - $_deviceLine');
  }
  @override Widget build(BuildContext context){
    final pages=[
      CaseFileScreen(events:_events, health:_health, battery:_battery, mem:_mem, sys:_sys, deviceLine:_deviceLine, changes:_changes, caseContext:_caseContext(), onOpenAgent:_openAgent, onOpenWizard:()=>setState(()=>_idx=6), onOpenApps:()=>setState(()=>_idx=2), onOpenFiles:()=>setState(()=>_idx=3), onShare:_shareReport),
      DashboardScreen(loading:_loading,battery:_battery,thermal:_thermal,mem:_mem,sys:_sys,health:_health,deviceLine:_deviceLine,androidLine:_androidLine,onRefresh:_load,onShare:_shareReport),
      AppsScanScreen(apps:_apps),
      FilesScanScreen(files:_files, onFilesChanged:_load),
      SystemScreen(sys:_sys, androidLine:_androidLine),
      TimelineScreen(events:_events),
      const WizardScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('BlackBox MD'), actions:[IconButton(onPressed:_openAgent, icon: const Icon(Icons.smart_toy_outlined), tooltip:'Ask Dr. BlackBox (agent)'), IconButton(onPressed:_shareReport, icon: const Icon(Icons.share), tooltip:'Share repair report'), IconButton(onPressed:_load, icon: const Icon(Icons.refresh))]),
      body: _loading && _battery==null ? const Center(child:CircularProgressIndicator()) : pages[_idx],
      bottomNavigationBar: NavigationBar(selectedIndex:_idx, onDestinationSelected:(i)=>setState(()=>_idx=i), destinations: const [
        NavigationDestination(icon:Icon(Icons.assignment_outlined), label:'Case'),
        NavigationDestination(icon:Icon(Icons.health_and_safety_outlined), label:'Health'),
        NavigationDestination(icon:Icon(Icons.apps), label:'Apps'),
        NavigationDestination(icon:Icon(Icons.folder_outlined), label:'Files'),
        NavigationDestination(icon:Icon(Icons.verified_user_outlined), label:'System'),
        NavigationDestination(icon:Icon(Icons.timeline), label:'Timeline'),
        NavigationDestination(icon:Icon(Icons.help_outline), label:'Why?'),
      ]),
    );
  }
}
