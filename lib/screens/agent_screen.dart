import 'package:flutter/material.dart';
import '../services/doctor_brain.dart';
import '../services/native_diagnostics.dart';
import '../widgets/doctor_avatar.dart';

class _Msg {
  final bool user;
  final String text;
  final String? action;
  const _Msg(this.user, this.text, [this.action]);
}

/// Ask Dr. BlackBox - the agent chat. The model is an open-source LLM the
/// user connects (Ollama on their own machine, or any OpenAI-compatible
/// endpoint); the doctor's knowledge of THIS phone comes from the case
/// context built by DoctorBrain, not from the model's imagination.
class AgentScreen extends StatefulWidget {
  final String caseContext;
  final VoidCallback onOpenWizard;
  final VoidCallback onOpenApps;
  final VoidCallback onOpenFiles;
  final VoidCallback onShare;
  const AgentScreen({super.key, required this.caseContext, required this.onOpenWizard, required this.onOpenApps, required this.onOpenFiles, required this.onShare});
  @override
  State<AgentScreen> createState() => _AgentState();
}

class _AgentState extends State<AgentScreen> {
  final List<_Msg> _msgs = [];
  final TextEditingController _input = TextEditingController();
  AgentSettings _settings = AgentSettings();
  bool _busy = false;
  bool _searching = false;
  bool _searched = false;
  bool _brainReady = false;
  bool _downloading = false;
  double? _dlProgress;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final info = await NativeDiagnostics.llmModelInfo();
    _brainReady = info['exists'] == true;
    final brain = await DoctorBrain.resolveBrain();
    if (!mounted) return;
    if (brain != null) {
      setState(() => _settings = brain);
      return;
    }
    final s = await AgentSettings.load();
    if (mounted) setState(() => _settings = s);
    _autoConnect();
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _dlProgress = 0;
    });
    final ok = await DoctorBrain.downloadBrain(onProgress: (p) {
      if (mounted) setState(() => _dlProgress = p);
    });
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _dlProgress = null;
      _brainReady = ok;
      if (ok) _settings = AgentSettings(mode: 'ondevice', model: 'Qwen2.5-1.5B (on-device)');
    });
    if (ok) {
      setState(() => _msgs.add(const _Msg(false, 'My brain is installed - Qwen2.5-1.5B now lives inside your phone. No internet, no computer needed. Ask me about your case.')));
    }
  }

  /// The app should just work: on open, if no brain is configured, scan the
  /// Wi-Fi for Ollama and connect automatically. Manual settings (gear)
  /// remain only as an override.
  Future<void> _autoConnect() async {
    if (_searching) return;
    setState(() => _searching = true);
    final found = await DoctorBrain.discoverOllama();
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      if (found != null) _settings = found;
    });
    if (found != null) {
      setState(() => _msgs.add(_Msg(false, 'Auto-connected to Ollama at ${found.baseUrl} with model ${found.model}. I have your case file - ask me anything about your phone.')));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    if (!_settings.configured) {
      await _autoConnect();
      if (!_settings.configured) return; // download / connect options are on screen
    }
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
    });
    final history = _msgs
        .where((m) => m.text.isNotEmpty)
        .map((m) => {'role': m.user ? 'user' : 'assistant', 'content': m.text})
        .toList();
    final reply = await DoctorBrain.ask(s: _settings, system: DoctorBrain.systemPrompt(widget.caseContext), history: history);
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, reply.text, reply.action));
      _busy = false;
    });
  }

  void _runAction(String action) {
    Navigator.pop(context);
    switch (action) {
      case 'SAFE_MODE':
        widget.onOpenWizard();
        break;
      case 'STORAGE':
        widget.onOpenFiles();
        break;
      case 'APPS':
        widget.onOpenApps();
        break;
      case 'SHARE':
        widget.onShare();
        break;
    }
  }

  String _actionLabel(String a) => switch (a) {
        'SAFE_MODE' => 'Open the Safe Mode investigation',
        'STORAGE' => 'Open Storage Doctor',
        'APPS' => 'Open Apps & Cache Radar',
        'SHARE' => 'Share the Repair Passport',
        _ => a,
      };

  Future<void> _openSettings() async {
    final modeCtl = ValueNotifier<String>(_settings.mode);
    final base = TextEditingController(text: _settings.baseUrl);
    final model = TextEditingController(text: _settings.model);
    final key = TextEditingController(text: _settings.apiKey);
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Doctor Agent - model connection'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('The doctor\'s brain is an open-source LLM that YOU connect. Nothing about your phone leaves the device except the case summary sent to the endpoint you choose.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: modeCtl,
              builder: (_, v, __) => DropdownButton<String>(
                value: v,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'ollama', child: Text('Ollama (your computer / local network)')),
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI-compatible API (Groq, LM Studio, ...)')),
                ],
                onChanged: (x) => modeCtl.value = x ?? 'ollama',
              ),
            ),
            TextField(controller: base, decoration: const InputDecoration(labelText: 'Base URL', hintText: 'Ollama: http://192.168.0.105:11434  -  Groq: https://api.groq.com/openai/v1')),
            TextField(controller: model, decoration: const InputDecoration(labelText: 'Model', hintText: 'qwen2.5:1.5b / llama3.2 / llama-3.3-70b-versatile')),
            TextField(controller: key, decoration: const InputDecoration(labelText: 'API key (only for API mode, stored on this phone only)'), obscureText: true),
            const SizedBox(height: 10),
            const Text('Tip: install Ollama on your computer, run "ollama pull qwen2.5:1.5b", find the computer\'s Wi-Fi IP, and use it above. The phone and computer must be on the same Wi-Fi.', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              _settings = AgentSettings(mode: modeCtl.value, baseUrl: base.text.trim(), model: model.text.trim(), apiKey: key.text.trim());
              await _settings.save();
              if (mounted) setState(() {});
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Dr. BlackBox'), actions: [IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings), tooltip: 'Agent model settings')]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DoctorCard(
            mode: DoctorMode.exam,
            speech: _settings.configured
                ? 'Connected: ${_settings.model} at ${_settings.baseUrl}. I have your full case file in front of me - ask me what is wrong, what to test next, or what to tell the repair shop.'
                : _searching
                    ? 'I am scanning this Wi-Fi for my brain (an Ollama server on your computer)... one moment.'
                    : 'I auto-connect to Ollama on your Wi-Fi - no typing needed. If your computer runs Ollama, keep the phone on the same Wi-Fi and tap Retry. Manual setup hides under the gear (top right).',
          ),
        ),
        if (!_settings.configured)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              if (!_brainReady)
                _downloading
                    ? Column(children: [
                        LinearProgressIndicator(value: _dlProgress),
                        const SizedBox(height: 6),
                        Text('Downloading the doctor\'s brain... ${((_dlProgress ?? 0) * 100).toStringAsFixed(0)}% of ~1.6 GB. Keep the app open.'),
                      ])
                    : FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download_for_offline), label: const Text('Download my brain into this phone (~1.6 GB, one time)')),
              const SizedBox(height: 8),
              if (_searching)
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Scanning Wi-Fi for Ollama...')])
              else
                OutlinedButton.icon(onPressed: _autoConnect, icon: const Icon(Icons.wifi_find), label: Text(_searched ? 'Retry Ollama auto-connect' : 'Or auto-connect to Ollama on Wi-Fi')),
            ]),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length + (_busy ? 1 : 0),
            itemBuilder: (c, i) {
              if (i == _msgs.length && _busy) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [DoctorAvatar(mode: DoctorMode.exam, size: 34), SizedBox(width: 10), Text('Dr. BlackBox is examining the case...'), SizedBox(width: 10), SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))]),
                );
              }
              final m = _msgs[i];
              return Align(
                alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
                  decoration: BoxDecoration(
                    color: m.user ? const Color(0xFF17457A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: m.user ? null : Border.all(color: const Color(0xFFDFE8F1)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.text, style: TextStyle(color: m.user ? Colors.white : const Color(0xFF12283F), height: 1.35)),
                    if (m.action != null) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(onPressed: () => _runAction(m.action!), icon: const Icon(Icons.arrow_forward, size: 18), label: Text(_actionLabel(m.action!))),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: _settings.configured ? 'Ask about your phone...' : 'Connect a model first (gear icon)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDFE8F1)))) , onSubmitted: (_) => _send())),
              const SizedBox(width: 8),
              FilledButton(onPressed: _busy ? null : _send, child: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
