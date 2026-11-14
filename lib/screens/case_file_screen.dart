import 'package:flutter/material.dart';
import '../models/diagnostics.dart';
import '../services/health_score.dart';
import '../widgets/doctor_avatar.dart';
import '../widgets/ai_assessment.dart';

/// The Case File - BlackBox MD's flagship screen.
/// Not a snapshot: an open investigation. The black-box recorder supplies
/// the deaths, the elimination tests move causes between "ruled out" and
/// "still suspect", and the doctor states the next test. Everything shown
/// is derived from recorded events and measured values - nothing invented.
class CaseFileScreen extends StatelessWidget {
  final List<RecorderEvent> events;
  final HealthResult health;
  final BatteryDetail? battery;
  final MemoryStorage? mem;
  final SystemIntegrity? sys;
  final String deviceLine;
  final List<String> changes;
  final String caseContext;
  final VoidCallback onOpenAgent;
  final VoidCallback onOpenApps;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenWizard;
  final VoidCallback onShare;
  const CaseFileScreen({super.key, required this.events, required this.health, required this.battery, required this.mem, required this.sys, required this.deviceLine, required this.changes, required this.caseContext, required this.onOpenAgent, required this.onOpenWizard, required this.onOpenApps, required this.onOpenFiles, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final deaths = events.where((e) => e.kind == 'unexpected_reboot').toList();
    RecorderEvent? safeResult;
    for (final e in events) {
      if (e.kind == 'safe_mode_result') { safeResult = e; break; }
    }
    final safeDied = safeResult != null && safeResult.detail.contains('DIED AGAIN');
    final safeStable = safeResult != null && safeResult.detail.contains('STABLE');

    final ruledOut = <String>[];
    final suspects = <String>[];
    if (safeDied) ruledOut.add('Downloaded apps - ruled out: the phone died in Safe Mode, where third-party apps cannot run');
    if (safeStable) suspects.add('A downloaded app - the phone was stable in Safe Mode with apps disabled');
    if (sys != null && sys!.verifiedBootState == 'green') ruledOut.add('Corrupted OS image - unlikely: Verified Boot is green and the build is stock');
    if (sys != null && sys!.rootSuspected) suspects.add('Modified / rooted system (${sys!.rootClues.join(', ')})');
    if (mem != null && mem!.storageUsedPct < 90) ruledOut.add('Nearly-full storage - storage is ${mem!.storageUsedPct}% used, above the danger line is 90%+');
    if (mem != null && mem!.storageUsedPct >= 95) suspects.add('Storage almost full (${mem!.storageUsedPct}%) - can cause hangs and failed boots');
    if (deaths.isNotEmpty) {
      suspects.add('Battery / power delivery${battery != null && battery!.cycleCount >= 0 ? ' - ${battery!.cycleCount} charge cycles recorded' : ''}: dying with charge showing is the classic voltage-sag pattern');
      suspects.add('Mainboard / storage hardware - only if a clean OS repair also fails');
    }

    final String speech;
    final bool concerned;
    final bool happy;
    if (deaths.isEmpty) {
      speech = 'Your case file is open and the black box is recording. If this phone ever dies, freezes or restarts on its own, I will have the evidence - battery, temperature and charging state from its last moments.';
      concerned = false; happy = true;
    } else if (safeDied) {
      speech = 'Case update: ${deaths.length} unexpected death(s) recorded, and the Safe Mode test came back positive - it died there too. Apps are officially innocent. My prime suspect is the battery / power hardware. Next: back up, then take the Repair Passport to a shop - battery quote first.';
      concerned = true; happy = false;
    } else if (safeStable) {
      speech = 'Case update: the phone stayed stable in Safe Mode, so a downloaded app is the prime suspect. Remove recently installed apps one by one - I will keep watching the black box after each removal.';
      concerned = false; happy = false;
    } else {
      speech = 'I have recorded ${deaths.length} unexpected death(s) but the case is not solved yet. The decisive experiment is the Safe Mode test - it separates "an app did it" from "the phone itself is failing". Run it from the Why? tab.';
      concerned = deaths.length >= 2; happy = false;
    }

    final String nextStep;
    final String nextLabel;
    if (deaths.isNotEmpty && safeResult == null) { nextStep = 'Run the Safe Mode test - 10 minutes that eliminates an entire class of causes.'; nextLabel = 'Open the investigation (Why?)'; }
    else if (safeDied) { nextStep = 'Share the Repair Passport with the repair shop BEFORE they open the phone - and ask for a battery quote first.'; nextLabel = 'Share Repair Passport'; }
    else if (safeStable) { nextStep = 'Remove recent apps one by one from the Apps tab flags, restarting after each.'; nextLabel = 'Open the investigation (Why?)'; }
    else { nextStep = 'Keep BlackBox MD installed. The recorder only needs the phone to live its normal life.'; nextLabel = 'See how the investigation works'; }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const Icon(Icons.assignment_outlined, color: Color(0xFF17457A)),
        const SizedBox(width: 8),
        Expanded(child: Text('Case File - $deviceLine', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF12283F)))),
      ]),
      const SizedBox(height: 4),
      Text(deaths.isEmpty ? 'Status: MONITORING - black box recording, no failures yet' : 'Status: OPEN INVESTIGATION - ${deaths.length} unexpected death(s) on record', style: TextStyle(fontWeight: FontWeight.w700, color: deaths.isEmpty ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
      const SizedBox(height: 12),
      _passportCard(context),
      const SizedBox(height: 8),
      DoctorCard(mode: DoctorMode.detective, speech: speech, concerned: concerned, happy: happy),
      const SizedBox(height: 6),
      if (deaths.isNotEmpty)
        Card(child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFFEE2E2), child: Icon(Icons.power_off, color: Color(0xFFC62828))),
          title: Text('Last recorded death: ${deaths.first.time}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(deaths.first.detail),
          isThreeLine: true,
        )),
      _board('Ruled out by evidence', ruledOut, Icons.check_circle, const Color(0xFF2E7D32), 'Nothing ruled out yet - the tests below produce the evidence.'),
      _board('Still suspect', suspects, Icons.help_outline, const Color(0xFFEF6C00), 'No suspects yet - if the phone misbehaves, suspects appear here.'),
      if (changes.isNotEmpty) _board('What changed since last check', changes.take(5).toList(), Icons.compare_arrows, const Color(0xFF00838F), ''),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Color(0xFF17457A), Color(0xFF2E6DA8)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.science_outlined, color: Colors.white), SizedBox(width: 8), Text('Next step in the investigation', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 8),
          Text(nextStep, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: safeDied ? onShare : onOpenWizard,
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF17457A)),
            icon: Icon(safeDied ? Icons.share : Icons.play_arrow),
            label: Text(nextLabel),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      const Card(color: Color(0xFFFFF3E0), child: Padding(padding: EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.backup_outlined, color: Colors.deepOrange), SizedBox(width: 10), Expanded(child: Text('A case file is evidence, not a backup. If deaths are repeating, copy photos and files somewhere safe NOW - a phone that dies mid-boot may not offer another chance.'))]))),
    ]);
  }

  /// Repair Passport (VITAL ORBIT §8.12): a boarding-pass style summary -
  /// device, verdict, event counts and the hash-chain head seal. The full
  /// text Passport is one Share tap away; "Show to shop" is large-type.
  Widget _passportCard(BuildContext context) {
    final deaths = events.where((e) => e.kind == 'unexpected_reboot').length;
    final head = events.isNotEmpty && events.first.chain.isNotEmpty ? events.first.chain : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF17457A), width: 1.4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.badge_outlined, color: Color(0xFF17457A)),
          const SizedBox(width: 8),
          const Expanded(child: Text('REPAIR PASSPORT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.6, fontSize: 14, color: Color(0xFF17457A)))),
          if (head.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFB9DDBB))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.link, size: 11, color: Color(0xFF2E7D32)),
                const SizedBox(width: 3),
                Text('chain #${head.substring(0, 6)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        Text(deviceLine, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF12283F))),
        const SizedBox(height: 3),
        Text('Verdict so far: ${health.verdict} (score ${health.score}/100, estimated)', style: const TextStyle(color: Colors.black87, fontSize: 13)),
        Text('${events.length} recorded event(s) - $deaths unexpected death(s)${battery != null && battery!.cycleCount >= 0 ? ' - ${battery!.cycleCount} battery cycles (measured)' : ''}', style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFDFE8F1))),
        Row(children: [
          FilledButton.icon(onPressed: onShare, icon: const Icon(Icons.share, size: 17), label: const Text('Share Passport')),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('For the repair shop'),
                content: Text('$deviceLine\n\nVerdict so far: ${health.verdict}.\n${events.length} events recorded, $deaths unexpected deaths.\n${deaths > 0 ? 'Please quote a battery replacement first. The full evidence file (Repair Passport) can be shared from the Case File.' : 'No failures recorded yet - please run your standard diagnostics.'}', style: const TextStyle(fontSize: 19, height: 1.5)),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
              ),
            ),
            icon: const Icon(Icons.storefront, size: 17),
            label: const Text('Show to shop'),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Generated on this phone. Not uploaded anywhere.', style: TextStyle(fontSize: 11.5, color: Colors.black45)),
      ]),
    );
  }

  Widget _board(String title, List<String> items, IconData icon, Color color, String emptyText) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4), child: Row(children: [Icon(icon, size: 19, color: color), const SizedBox(width: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF12283F)))])),
      if (items.isEmpty) Padding(padding: const EdgeInsets.only(left: 4), child: Text(emptyText, style: const TextStyle(color: Colors.black54))),
      ...items.map((e) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 20)), title: Text(e)))),
    ]);
  }
}
