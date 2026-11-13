import 'package:flutter/material.dart';
class WizardScreen extends StatefulWidget { const WizardScreen({super.key}); @override State<WizardScreen> createState()=>_WizardState(); }
class _WizardState extends State<WizardScreen> {
  String? safeMode; String? diesWithCharge; String? onset; String? gLogo;
  String get verdict {
    if([safeMode,diesWithCharge,onset,gLogo].any((e)=>e==null)) return 'Answer all four questions for a verdict.';
    if(gLogo=='yes' && safeMode=='still') return 'Likely HARDWARE or corrupted OS. A hang at the Google logo happens before apps load, and it persists in Safe Mode - so an app is not the cause. Try Pixel Repair from a computer, then a shop. Battery first, then storage/board.';
    if(safeMode=='still' && diesWithCharge=='yes') return 'Likely HARDWARE - battery first. Dying with charge showing + failing in Safe Mode is the classic voltage-sag pattern. Back up now, get a battery quote before paying for a board.';
    if(safeMode=='gone') return 'Likely a DOWNLOADED APP. It went away in Safe Mode - remove recently installed/updated apps one by one, restarting after each.';
    if(onset=='update') return 'Likely SOFTWARE / corrupted update. Onset locked to an update points there first - try Pixel Update & Software Repair before a factory reset.';
    return 'Unclear - keep the recorder running, watch storage (>10% free), temperature and the timeline. If it fails after a clean factory reset, it is hardware.';
  }
  @override Widget build(BuildContext context){ return ListView(padding: const EdgeInsets.all(16), children:[
    const Text('Why did my phone die?', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    const Text('This walks Google\'s own diagnosis ladder. Safe Mode: restart, when the animation starts hold Volume Down until it boots - look for "Safe mode" at the bottom. Use it normally, then restart normally to exit.'),
    _q('Did the problem happen in Safe Mode too?', safeMode, (v)=>setState(()=>safeMode=v), {'still':'Yes, still bad','gone':'No, it went away'}),
    _q('Does it die with charge still showing (e.g. 30-50%)?', diesWithCharge, (v)=>setState(()=>diesWithCharge=v), {'yes':'Yes','no':'No'}),
    _q('How did it start?', onset, (v)=>setState(()=>onset=v), {'update':'Right after an update','gradual':'Gradually over weeks','sudden':'Suddenly, no update'}),
    _q('Does it hang at the Google logo when booting?', gLogo, (v)=>setState(()=>gLogo=v), {'yes':'Yes','no':'No'}),
    Card(color: const Color(0xFFE3F2FD), child: Padding(padding: const EdgeInsets.all(16), child: Text(verdict, style: const TextStyle(fontSize:16)))),
  ]); }
  Widget _q(String title, String? val, ValueChanged<String?> onChanged, Map<String,String> opts)=>Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text(title, style: const TextStyle(fontWeight:FontWeight.bold)), ...opts.entries.map((e)=>RadioListTile<String>(value:e.key, groupValue:val, onChanged:onChanged, title: Text(e.value)))])));
}
