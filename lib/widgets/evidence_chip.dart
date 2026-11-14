import 'package:flutter/material.dart';
import '../theme/vital_orbit.dart';

/// Evidence labels as a first-class visual element (VITAL ORBIT §2.4).
/// Every important number in the app should carry one of these. Tapping a
/// chip explains, in plain language, where the value comes from and why it
/// can or cannot be measured - the README's "Honest limits" as UI.
enum Evidence { measured, estimated, unavailable }

class EvidenceChip extends StatelessWidget {
  final Evidence kind;
  final String label; // the metric name, e.g. "Battery cycles"
  final String source; // API / method, e.g. "BatteryManager EXTRA_CYCLE_COUNT"
  final String why; // plain-language explanation for the sheet
  const EvidenceChip({super.key, required this.kind, required this.label, required this.source, required this.why});

  @override
  Widget build(BuildContext context) {
    final t = BOTokens.of(context);
    final (dot, text, ring) = switch (kind) {
      Evidence.measured => (t.accentCore, 'MEASURED', false),
      Evidence.estimated => (t.watch, 'ESTIMATED', true),
      Evidence.unavailable => (t.ghost, 'UNAVAILABLE', false),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: t.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: boTitle(c, size: 18)),
            const SizedBox(height: 6),
            Text(text, style: boData(c, size: 12, color: dot)),
            const SizedBox(height: 12),
            Text('Source: $source', style: TextStyle(color: t.textSecondary, fontSize: 13.5)),
            const SizedBox(height: 8),
            Text(why, style: TextStyle(color: t.textPrimary, fontSize: 14, height: 1.45)),
          ]),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: t.surfaceGlass.withValues(alpha: t.dark ? 0.85 : 1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.lineHair),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ring ? Colors.transparent : dot,
              border: Border.all(color: dot, width: 1.6),
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: boData(context, size: 9.5, color: t.dark ? t.textSecondary : const Color(0xFF5A6580))),
        ]),
      ),
    );
  }
}

/// Ghost value placeholder (spec §7): a dotted "· · ·" instead of a fake
/// number, tappable through the EvidenceChip beside it.
class GhostValue extends StatelessWidget {
  const GhostValue({super.key});
  @override
  Widget build(BuildContext context) {
    final t = BOTokens.of(context);
    return Text('· · ·', style: boData(context, size: 15, color: t.ghost));
  }
}
