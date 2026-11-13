import 'package:flutter/material.dart';
import '../services/recorder.dart';
class WizardScreen extends StatefulWidget { const WizardScreen({super.key}); @override State<WizardScreen> createState()=>_WizardState(); }
class _WizardState extends State<WizardScreen> {
  String? safeMode; String? diesWithCharge; String? onset; String? gLogo;
  int? safePendingSince;
  @override void initState(){ super.initState(); _loadPending(); }
  Future<void> _loadPending() async { final p = await Recorder.safeModePendingSince(); if(mounted) setState(()=>safePendingSince=p); }
  String get verdict {
    if([safeMode,diesWithCharge,onset,gLogo].any((e)=>e==null)) return 'Answer all four questions for a verdict - or run the Safe Mode test below, it answers the first one with evidence.';
    if(gLogo=='yes' && safeMode=='still') return 'Likely HARDWARE or corrupted OS. A hang at the Google logo happens before apps load, and it persists in Safe Mode - so an app is not the cause. Try Pixel Repair from a computer, then a shop. Battery first, then storage/board.';
    if(safeMode=='still' && diesWithCharge=='yes') return 'Likely HARDWARE - battery first. Dying with charge showing + failing in Safe Mode is the classic voltage-sag pattern. Back up now, get a battery quote before paying for a board.';
    if(safeMode=='gone') return 'Likely a DOWNLOADED APP. It went away in Safe Mode - remove recently installed/updated apps one by one, restarting after each.';
    if(onset=='update') return 'Likely SOFTWARE / corrupted update. Onset locked to an update points there first - try Pixel Update & Software Repair before a factory reset.';
    return 'Unclear - keep the recorder running, watch storage (>10% free), temperature and the timeline. If it fails after a clean factory reset, it is hardware.';
  }
  Future<void> _startTest() async {
    await Recorder.startSafeModeTest();
    await _loadPending();
    if(!mounted) return;
    showDialog(context: context, builder: (c)=>AlertDialog(
      title: const Text('Now restart into Safe Mode'),
      content: const SingleChildScrollView(child: Text('METHOD A - phone OFF (most reliable):\n1. Power the phone off completely.\n2. Press Power once to start it.\n3. The moment the Google logo / startup animation appears, press and HOLD Volume Down - keep holding until the phone fully boots.\n4. "Safe mode" at the bottom corner confirms it.\n\nMETHOD B - phone ON:\n1. Briefly hold Power + Volume Up (2-3 seconds only - holding longer force-restarts) until the power menu appears, then let go.\n2. Touch and HOLD the on-screen "Power off" or "Restart" tile - a plain tap just restarts normally.\n3. Tap OK on "Reboot to safe mode".\n\nUse the phone normally for a few hours. Downloaded apps are disabled there; PhoneVitals cannot run in Safe Mode either. To exit: restart normally, open PhoneVitals, and record the result here.')),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Got it'))],
    ));
  }
  Future<void> _finishTest(bool stable) async {
    await Recorder.completeSafeModeTest(stable: stable);
    setState((){ safeMode = stable ? 'gone' : 'still'; });
    await _loadPending();
  }
  @override Widget build(BuildContext context){ return ListView(padding: const EdgeInsets.all(16), children:[
    const Text('Why did my phone die?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF12283F))),
    const SizedBox(height: 4),
    const Text('This walks Google\'s own diagnosis ladder - one question at a time, no guessing.'),
    const SizedBox(height: 12),
    _safeModeCard(),
    const SizedBox(height: 8),
    _q('Did the problem happen in Safe Mode too?', safeMode, (v)=>setState(()=>safeMode=v), {'still':'Yes, still bad','gone':'No, it went away'}),
    _q('Does it die with charge still showing (e.g. 30-50%)?', diesWithCharge, (v)=>setState(()=>diesWithCharge=v), {'yes':'Yes','no':'No'}),
    _q('How did it start?', onset, (v)=>setState(()=>onset=v), {'update':'Right after an update','gradual':'Gradually over weeks','sudden':'Suddenly, no update'}),
    _q('Does it hang at the Google logo when booting?', gLogo, (v)=>setState(()=>gLogo=v), {'yes':'Yes','no':'No'}),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFD6E6F5), borderRadius: BorderRadius.circular(20)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[const Icon(Icons.psychology_alt, color: Color(0xFF17457A)), const SizedBox(width: 10), Expanded(child: Text(verdict, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Color(0xFF12283F))))])),
  ]); }
  Widget _safeModeCard(){
    final pending = safePendingSince!=null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors:[Color(0xFF17457A), Color(0xFF2E6DA8)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        const Row(children:[Icon(Icons.shield_outlined, color: Colors.white), SizedBox(width: 8), Text('Safe Mode test', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 8),
        const Text('Safe Mode runs only Google\'s built-in apps. If the phone still dies there, no downloaded app can be the cause - it is the OS or hardware. If it stays stable, a downloaded app is the culprit.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        const Text('Honest limit: Android does not let ANY app reboot your phone into Safe Mode - rebooting is reserved for the system. Any app promising a one-tap Safe Mode is lying or rooted. PhoneVitals records the test, guides your hands, and saves the verdict.', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        const SizedBox(height: 12),
        if(!pending) FilledButton.icon(onPressed: _startTest, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF17457A)), icon: const Icon(Icons.play_arrow), label: const Text('Start Safe Mode test')),
        if(pending) ...[
          Text('Test started ${DateTime.fromMillisecondsSinceEpoch(safePendingSince!)} - after you exit Safe Mode and come back, how did it go?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children:[
            FilledButton.icon(onPressed: ()=>_finishTest(true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ADE80), foregroundColor: const Color(0xFF12283F)), icon: const Icon(Icons.check), label: const Text('Stable in Safe Mode')),
            FilledButton.icon(onPressed: ()=>_finishTest(false), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF87171), foregroundColor: Colors.white), icon: const Icon(Icons.close), label: const Text('Died again in Safe Mode')),
          ]),
        ],
      ]),
    );
  }
  Widget _q(String title, String? val, ValueChanged<String?> onChanged, Map<String,String> opts)=>Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Padding(padding: const EdgeInsets.only(left: 6, top: 4), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))), ...opts.entries.map((e)=>RadioListTile<String>(value:e.key, groupValue:val, onChanged:onChanged, title: Text(e.value), dense: true))])));
}
