import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/diagnostics.dart';
/// Scans files the OS actually lets a normal app see: files returned by the
/// native MediaStore / shared-storage listing. It CANNOT scan /system or
/// other apps' private data - Verified Boot already checks the OS at boot,
/// and a hang at the Google logo is exactly what a failed check looks like.
/// That limit is shown in the UI, not hidden.
List<FileIssue> scanFiles(List<Map<String,dynamic>> files) {
  final issues=<FileIssue>[]; final byHash=<String,List<Map<String,dynamic>>>{};
  for (final f in files) {
    final path=f['path']?.toString()??''; final size=(f['size'] as num?)?.toInt()??-1; final name=path.split('/').last.toLowerCase();
    if (size==0) issues.add(FileIssue(path,'Zero-byte file','File is empty - often a failed download or a corrupted save',0));
    if (name.endsWith('.tmp')||name.endsWith('.part')||name.endsWith('.crdownload')) issues.add(FileIssue(path,'Partial download','Leftover partial file - safe to delete if the download finished',size));
    if (name.endsWith('.apk')) issues.add(FileIssue(path,'APK in storage','Downloaded APK file. If sideloaded, verify the source; otherwise it is just taking space',size));
    final hash=f['sha256']?.toString(); if (hash!=null && hash.isNotEmpty && size>1024*1024) { byHash.putIfAbsent(hash,()=>[]).add(f); }
    // Corrupt media heuristic supplied by native side: headerOk == false
    if (f['headerOk']==false) issues.add(FileIssue(path,'Possibly corrupted media','File header / container could not be parsed by the system media scanner',size));
  }
  byHash.forEach((h,list){ if(list.length>1){ for(final f in list){ issues.add(FileIssue(f['path'].toString(),'Possible duplicate','Same SHA-256 as ${list.length-1} other file(s) over 1 MB - review before deleting',(f['size'] as num?)?.toInt()??0)); } } });
  return issues;
}
String sha256OfBytes(List<int> bytes)=>sha256.convert(bytes).toString();
String prettySize(int b){ if(b<0) return 'unknown'; if(b<1024) return '$b B'; if(b<1024*1024) return '${(b/1024).toStringAsFixed(1)} KB'; if(b<1024*1024*1024) return '${(b/(1024*1024)).toStringAsFixed(1)} MB'; return '${(b/(1024*1024*1024)).toStringAsFixed(2)} GB'; }
