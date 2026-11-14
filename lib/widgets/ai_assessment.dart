import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/doctor_brain.dart';

/// The AI-driven doctor: when a brain is connected, the Case File opens
/// with a fresh AI assessment of the case - generated from the real case
/// context, cached against a case fingerprint so it regenerates only when
/// the evidence changes. No brain connected -> a quiet invitation, never
/// a fake assessment.
class AiAssessmentCard extends StatefulWidget {
  final String caseContext;
  final String fingerprint;
  final VoidCallback onOpenAgent;
  final VoidCallback? onOpenWizard;
  final VoidCallback? onOpenApps;
  final VoidCallback? onOpenFiles;
  final VoidCallback? onShare;
  const AiAssessmentCard({super.key, required this.caseContext, required this.fingerprint, required this.onOpenAgent, this.onOpenWizard, this.onOpenApps, this.onOpenFiles, this.onShare});
  @override
  State<AiAssessmentCard> createState() => _AiAssessmentState();
}

class _AiAssessmentState extends State<AiAssessmentCard> {
  String? _text;
  String? _action;
  String? _model;
  bool _loading = false;
  bool _noBrain = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;
    final s = await AgentSettings.load();
    if (!mounted) return;
    if (!s.configured) {
      setState(() => _noBrain = true);
      return;
    }
    final sp = await SharedPreferences.getInstance();
    if (sp.getString('bb_ai_fp') == widget.fingerprint && (sp.getString('bb_ai_text') ?? '').isNotEmpty) {
      setState(() {
        _text = sp.getString('bb_ai_text');
        _action = sp.getString('bb_ai_action');
        _model = s.model;
      });
      return;
    }
    setState(() => _loading = true);
    final reply = await DoctorBrain.ask(
      s: s,
      system: DoctorBrain.systemPrompt(widget.caseContext),
      history: const [
        {
          'role': 'user',
          'content': 'Give your assessment of my case in 3-4 short sentences: what is most likely wrong, the strongest evidence for it, and the single most important next step I should take now.'
        }
      ],
    );
    if (!mounted) return;
    // Connection errors are not assessments - don't cache or present them.
    if (reply.text.startsWith('I could not reach') || reply.text.startsWith('Agent error') || reply.text.startsWith('The model took too long')) {
      setState(() {
        _loading = false;
        _noBrain = true;
      });
      return;
    }
    await sp.setString('bb_ai_fp', widget.fingerprint);
    await sp.setString('bb_ai_text', reply.text);
    if (reply.action != null) await sp.setString('bb_ai_action', reply.action!);
    setState(() {
      _text = reply.text;
      _action = reply.action;
      _model = s.model;
      _loading = false;
    });
  }

  String _label(String a) => switch (a) {
        'SAFE_MODE' => 'Open the Safe Mode investigation',
        'STORAGE' => 'Open Storage Doctor',
        'APPS' => 'Open Apps & Cache Radar',
        'SHARE' => 'Share the Repair Passport',
        _ => a,
      };

  VoidCallback? _cb(String a) => switch (a) {
        'SAFE_MODE' => widget.onOpenWizard,
        'STORAGE' => widget.onOpenFiles,
        'APPS' => widget.onOpenApps,
        'SHARE' => widget.onShare,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (_noBrain) {
      return Card(
        color: const Color(0xFFF3F7FC),
        child: ListTile(
          leading: const Icon(Icons.psychology_alt, color: Color(0xFF17457A)),
          title: const Text('AI assessment is off', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Connect the doctor\'s brain (Ollama auto-connects on your Wi-Fi) and the Case File will open with an AI assessment of your evidence.'),
          trailing: FilledButton(onPressed: widget.onOpenAgent, child: const Text('Connect')),
        ),
      );
    }
    return Card(
      color: const Color(0xFFF3F7FC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.psychology_alt, color: Color(0xFF17457A), size: 20),
            SizedBox(width: 8),
            Text('AI assessment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Color(0xFF12283F))),
          ]),
          const SizedBox(height: 8),
          if (_loading)
            const Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Expanded(child: Text('Dr. BlackBox is reviewing your case file with the AI brain...'))])
          else if (_text != null) ...[
            Text(_text!, style: const TextStyle(height: 1.4)),
            if (_action != null && _cb(_action!) != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: _cb(_action!), icon: const Icon(Icons.arrow_forward, size: 18), label: Text(_label(_action!))),
            ],
            const SizedBox(height: 6),
            Text('Generated by ${_model ?? 'the connected model'} from this case file. AI can be wrong - the evidence above is the source of truth.', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          ],
        ]),
      ),
    );
  }
}
