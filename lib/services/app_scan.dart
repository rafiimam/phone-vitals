import '../models/diagnostics.dart';
class AppFlag { final AppInfoItem app; final List<String> flags; const AppFlag(this.app,this.flags); int get severity=>flags.length; }
List<AppFlag> scanApps(List<AppInfoItem> apps, Map<String,Map<String,dynamic>> usageByPkg) {
  final out=<AppFlag>[];
  for (final a in apps) {
    final f=<String>[];
    if (a.sideloaded) f.add('Sideloaded - installed from ${a.installer}, not Google Play. Only keep it if you trust the source');
    if (!a.isSystem && a.daysSinceUpdate>730) f.add('Not updated in ${(a.daysSinceUpdate/365).toStringAsFixed(1)} years - old apps can crash newer Android');
    if (a.targetSdk>0 && a.targetSdk<29) f.add('Targets very old Android (SDK ${a.targetSdk}) - may behave badly / be blocked from new protections');
    if (a.dangerousPermissions.length>=5) f.add('${a.dangerousPermissions.length} sensitive permissions: ${a.dangerousPermissions.take(4).join(', ')}...');
    final u=usageByPkg[a.packageName];
    if (u!=null) { final fg=(u['totalForegroundMs'] as num?)?.toInt()??0; if (fg> 6*3600*1000) f.add('Foreground ${(fg/3600000).toStringAsFixed(1)}h in the stats window - a top time / drain candidate (proxy, not mAh)'); }
    if (f.isNotEmpty) out.add(AppFlag(a,f));
  }
  out.sort((a,b)=>b.severity.compareTo(a.severity)); return out;
}
