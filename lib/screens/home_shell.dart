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
import 'dashboard_screen.dart';
import 'scan_screens.dart';
import 'wizard_screen.dart';

class HomeShell extends StatefulWidget { const HomeShell({super.key}); @override State<HomeShell> createState()=>_HomeShellState(); }
class _HomeShellState extends State<HomeShell> {
  int _idx=0; bool _loading=true;
  BatteryDetail? _battery; ThermalInfo? _thermal; MemoryStorage? _mem; SystemIntegrity? _sys;
  List<RecorderEvent> _events=[]; String _deviceLine='Unknown device'; String _androidLine='Unknown Android';
  List<AppInfoItem> _apps=[]; List<Map<String,dynamic>> _files=[];
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    setState(()=>_loading=true);
    try { final di=await DeviceInfoPlugin().androidInfo; _deviceLine='${di.manufacturer} ${di.model} (${di.device})'; _androidLine='Android ${di.version.release} SDK ${di.version.sdkInt}, patch ${di.version.securityPatch}'; } catch(_){}
    _battery=await NativeDiagnostics.battery(); _thermal=await NativeDiagnostics.thermal(); _mem=await NativeDiagnostics.memoryStorage(); _sys=await NativeDiagnostics.systemIntegrity();
    _events=await Recorder.checkAndLoad();
    if(_battery!=null) await Recorder.heartbeat(batteryPct:_battery!.level, tempC:_battery!.tempC, thermal:_thermal?.label??'unknown');
    _apps=await NativeDiagnostics.installedApps(); _files=await NativeDiagnostics.sharedFiles();
    if(mounted) setState(()=>_loading=false);
  }
  HealthResult get _health=>evaluateHealth(b:_battery,t:_thermal,ms:_mem,sys:_sys,uncleanCount:_events.where((e)=>e.kind=='unclean_exit').length);
  Future<void> _shareReport() async {
    final appFlags=scanApps(_apps,{}).map((f)=>'${f.app.label} (${f.app.packageName}): ${f.flags.join('; ')}').toList();
    final fileFlags=scanFiles(_files).map((f)=>'${f.kind}: ${f.path} - ${f.detail}').toList();
    final text=buildRepairReport(deviceLine:_deviceLine, androidLine:_androidLine, b:_battery,t:_thermal,ms:_mem,sys:_sys,health:_health,events:_events,appFlags:appFlags,fileFlags:fileFlags);
    await Share.share(text, subject:'PhoneVitals Repair Report - $_deviceLine');
  }
  @override Widget build(BuildContext context){
    final pages=[
      DashboardScreen(loading:_loading,battery:_battery,thermal:_thermal,mem:_mem,sys:_sys,health:_health,deviceLine:_deviceLine,androidLine:_androidLine,onRefresh:_load,onShare:_shareReport),
      AppsScanScreen(apps:_apps),
      FilesScanScreen(files:_files),
      SystemScreen(sys:_sys, androidLine:_androidLine),
      TimelineScreen(events:_events),
      const WizardScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('PhoneVitals'), actions:[IconButton(onPressed:_shareReport, icon: const Icon(Icons.share), tooltip:'Share repair report'), IconButton(onPressed:_load, icon: const Icon(Icons.refresh))]),
      body: _loading && _battery==null ? const Center(child:CircularProgressIndicator()) : pages[_idx],
      bottomNavigationBar: NavigationBar(selectedIndex:_idx, onDestinationSelected:(i)=>setState(()=>_idx=i), destinations: const [
        NavigationDestination(icon:Icon(Icons.health_and_safety_outlined), label:'Health'),
        NavigationDestination(icon:Icon(Icons.apps), label:'Apps'),
        NavigationDestination(icon: Icon(Icons.folder_open), label: 'Files'),
        NavigationDestination(icon:Icon(Icons.verified_user_outlined), label:'System'),
        NavigationDestination(icon:Icon(Icons.timeline), label:'Timeline'),
        NavigationDestination(icon:Icon(Icons.help_outline), label:'Why?'),
      ]),
    );
  }
}
