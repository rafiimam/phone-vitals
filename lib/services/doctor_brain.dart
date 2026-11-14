import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diagnostics.dart';
import 'native_diagnostics.dart';
import 'health_score.dart';

/// The Doctor Agent's brain.
/// The LLM is an open-source model that BlackBox MD does NOT pretend to be:
/// it runs either on the user's own machine (Ollama) or on any
/// OpenAI-compatible endpoint (LM Studio, Groq, Together, OpenRouter...)
/// and a fully on-device engine is the next milestone. What makes the
/// agent a *doctor* rather than a chatbot is the grounding: every answer
/// is conditioned on the real case file (recorder events, measurements,
/// change radar) and constrained by the honesty rules below.
class AgentSettings {
  String mode; // 'ollama' | 'openai'
  String baseUrl;
  String model;
  String apiKey;
  AgentSettings({this.mode = 'ollama', this.baseUrl = '', this.model = '', this.apiKey = ''});
  bool get configured => mode == 'ondevice' ? model.trim().isNotEmpty : (baseUrl.trim().isNotEmpty && model.trim().isNotEmpty);
  static Future<AgentSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    return AgentSettings(
      mode: sp.getString('bb_agent_mode') ?? 'ollama',
      baseUrl: sp.getString('bb_agent_base') ?? '',
      model: sp.getString('bb_agent_model') ?? '',
      apiKey: sp.getString('bb_agent_key') ?? '',
    );
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('bb_agent_mode', mode);
    await sp.setString('bb_agent_base', baseUrl);
    await sp.setString('bb_agent_model', model);
    await sp.setString('bb_agent_key', apiKey);
  }
}

class AgentReply {
  final String text;
  final String? action;
  const AgentReply(this.text, this.action);
}

class DoctorBrain {
  static String buildContext({
    required String deviceLine,
    required String androidLine,
    required HealthResult health,
    BatteryDetail? b,
    ThermalInfo? t,
    MemoryStorage? ms,
    SystemIntegrity? sys,
    required List<RecorderEvent> events,
    required List<String> changes,
    required List<String> appFlags,
    required List<String> fileFlags,
  }) {
    final sb = StringBuffer();
    sb.writeln('CASE DATA (measured on this phone by BlackBox MD - trust this over general knowledge):');
    sb.writeln('Device: $deviceLine');
    sb.writeln('Android: $androidLine');
    sb.writeln('Health score: ${health.score}/100 - ${health.verdict}');
    if (health.warnings.isNotEmpty) sb.writeln('Warnings: ${health.warnings.join('; ')}');
    if (b != null) sb.writeln('Battery: ${b.level}%, health ${b.health}, ${b.tempC}C, ${b.voltageMv} mV, status ${b.status}, cycles ${b.cycleCount}, tech ${b.technology}');
    if (t != null) sb.writeln('Thermal: ${t.label}, headroom ${t.headroom}');
    if (ms != null) sb.writeln('Storage: ${ms.storageUsedPct}% used, ${ms.freeStorageGb.toStringAsFixed(1)} GB free; RAM ${ms.totalRamMb} MB total; uptime ${ms.uptimeHours.toStringAsFixed(1)}h');
    if (sys != null) sb.writeln('System: patch ${sys.securityPatch} (${sys.patchAgeDays} days old), Verified Boot ${sys.verifiedBootState}, build ${sys.buildType}, root suspected: ${sys.rootSuspected}');
    final deaths = events.where((e) => e.kind == 'unexpected_reboot').length;
    sb.writeln('Unexpected reboots recorded by the black box: $deaths');
    for (final e in events.take(8)) {
      sb.writeln('Event ${e.time} [${e.kind}]: ${e.detail.length > 220 ? e.detail.substring(0, 220) : e.detail}');
    }
    if (changes.isNotEmpty) sb.writeln('Changed since last check: ${changes.join('; ')}');
    if (appFlags.isNotEmpty) sb.writeln('Flagged apps: ${appFlags.take(8).join('; ')}');
    if (fileFlags.isNotEmpty) sb.writeln('File issues: ${fileFlags.take(8).join('; ')}');
    return sb.toString();
  }

  static String systemPrompt(String caseContext) => '''
You are Dr. BlackBox, the doctor inside the BlackBox MD Android app. You speak plainly and warmly, like a good doctor: what you found, what it likely means, what to do next. Short paragraphs, no jargon without explanation. Reply in the language the user writes in (English, Bangla or Banglish).

$caseContext

HONESTY RULES - never break these:
1. Ground every claim in the CASE DATA above. If a measurement is missing, say "I don't have that measurement yet" and name the app screen that produces it. Never invent numbers.
2. You CANNOT do things Android forbids for normal apps, and you must never claim otherwise: you cannot clear other apps' caches yourself, force-stop apps, boost RAM, cool the CPU, repair a battery, toggle Wi-Fi/Bluetooth silently, or reboot the phone into Safe Mode. What you CAN do: measure, record, explain, guide the user step-by-step, open the exact system settings page (via the app's buttons), run the Storage Doctor cleanup with the user's selection + Android's consent dialog, and share the Repair Passport.
3. Diagnosis is probabilistic. Say "likely" / "points to", give the evidence, and name the test that would confirm it (the app has a Safe Mode test in the Why? tab, a Storage Doctor in Files, a Cache Radar in Apps).
4. SAFETY FIRST: if the phone is swollen, the screen/back is lifting, it smells, smokes or is too hot to hold - tell the user to stop charging it and take it to a shop before any other advice.
5. If unexpected reboots are repeating, remind about backup early.

At the very end of your reply, on its own line, output exactly one action token if an in-app step fits, chosen from: [[ACTION:SAFE_MODE]] [[ACTION:STORAGE]] [[ACTION:APPS]] [[ACTION:SHARE]] - or no token if none fits. The app turns the token into a button; do not explain the token.''';

  static AgentReply parseReply(String raw) {
    final m = RegExp(r'\[\[ACTION:(\w+)\]\]').firstMatch(raw);
    if (m == null) return AgentReply(raw.trim(), null);
    return AgentReply(raw.replaceAll(m.group(0)!, '').trim(), m.group(1));
  }

  /// Brain priority: a brain the user deliberately configured first, then
  /// the on-device model if it has been downloaded. Null = no brain yet.
  static Future<AgentSettings?> resolveBrain() async {
    final s = await AgentSettings.load();
    if (s.configured) return s;
    final info = await NativeDiagnostics.llmModelInfo();
    if (info['exists'] == true) return AgentSettings(mode: 'ondevice', model: 'Qwen2.5-1.5B (on-device)');
    return null;
  }

  /// The on-device brain: Qwen2.5-1.5B-Instruct (Apache-2.0), converted by
  /// Google's litert-community for the MediaPipe/LiteRT stack, public and
  /// ungated on Hugging Face - downloaded once, at runtime, into the app's
  /// private storage. q8 weights, 4096-token KV cache (our case prompts
  /// are long). ~1.6 GB one-time download; fully offline afterwards.
  static const brainUrl = 'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';

  static Future<bool> downloadBrain({required void Function(double) onProgress}) async {
    final info = await NativeDiagnostics.llmModelInfo();
    final path = info['path']?.toString() ?? '';
    if (path.isEmpty) return false;
    final part = File('$path.part');
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(brainUrl));
      final resp = await req.close();
      if (resp.statusCode != 200) return false;
      final total = resp.contentLength;
      var received = 0;
      final sink = part.openWrite();
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      if (total > 0 && received != total) return false;
      await part.rename(path);
      await AgentSettings(mode: 'ondevice', model: 'Qwen2.5-1.5B (on-device)').save();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  static Future<AgentReply> ask({
    required AgentSettings s,
    required String system,
    required List<Map<String, String>> history,
  }) async {
    final messages = [
      {'role': 'system', 'content': system},
      ...history,
    ];
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      if (s.mode == 'ondevice') {
        // Qwen2.5 chat template (ChatML), applied by hand - the runtime
        // does not template prompts for us.
        final buf = StringBuffer();
        buf.writeln('<|im_start|>system');
        buf.writeln(system);
        buf.writeln('<|im_end|>');
        for (final m in history) {
          buf.writeln('<|im_start|>${m['role'] == 'user' ? 'user' : 'assistant'}');
          buf.writeln(m['content'] ?? '');
          buf.writeln('<|im_end|>');
        }
        buf.writeln('<|im_start|>assistant');
        final raw = await NativeDiagnostics.llmGenerate(buf.toString());
        if (raw.trim().isEmpty) return const AgentReply('The on-device brain returned an empty answer. Try asking again.', null);
        return parseReply(raw);
      }
      final String content;
      if (s.mode == 'ollama') {
        final base = s.baseUrl.replaceAll(RegExp(r'/+$'), '');
        final req = await client.postUrl(Uri.parse('$base/api/chat'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'model': s.model, 'messages': messages, 'stream': false}));
        final resp = await req.close().timeout(const Duration(seconds: 240));
        final body = await resp.transform(utf8.decoder).join();
        if (resp.statusCode != 200) throw HttpException('Ollama replied ${resp.statusCode}: ${body.length > 200 ? body.substring(0, 200) : body}');
        content = (jsonDecode(body) as Map)['message']?['content']?.toString() ?? '';
      } else {
        var base = s.baseUrl.replaceAll(RegExp(r'/+$'), '');
        final url = base.endsWith('/v1') ? '$base/chat/completions' : '$base/v1/chat/completions';
        final req = await client.postUrl(Uri.parse(url));
        req.headers.contentType = ContentType.json;
        if (s.apiKey.trim().isNotEmpty) req.headers.set('Authorization', 'Bearer ${s.apiKey.trim()}');
        req.write(jsonEncode({'model': s.model, 'messages': messages}));
        final resp = await req.close().timeout(const Duration(seconds: 240));
        final body = await resp.transform(utf8.decoder).join();
        if (resp.statusCode != 200) throw HttpException('Endpoint replied ${resp.statusCode}: ${body.length > 200 ? body.substring(0, 200) : body}');
        final j = jsonDecode(body) as Map;
        content = (((j['choices'] as List?)?.first as Map?)?['message'] as Map?)?['content']?.toString() ?? '';
      }
      if (content.trim().isEmpty) return const AgentReply('The model replied with an empty answer. Try again, or check the model name in Agent settings.', null);
      return parseReply(content);
    } on SocketException catch (e) {
      return AgentReply('I could not reach the model endpoint (${e.message}). Check: is Ollama/your server running, is the phone on the same Wi-Fi, and is the address in Agent settings right? Nothing about your phone changed - this is only the agent connection.', null);
    } on TimeoutException {
      return const AgentReply('The model took too long to answer (over 4 minutes). A smaller/faster model or a less loaded machine will help. Your case data is safe.', null);
    } catch (e) {
      return AgentReply('Agent error: $e', null);
    } finally {
      client.close();
    }
  }

  /// Zero-config auto-connect: scan the phone's own Wi-Fi subnet for an
  /// Ollama server (port 11434), read its model list, pick a chat model
  /// and save the settings - the user never types an address. Raw dart:io
  /// sockets are used for the scan, so no extra permissions are needed.
  static Future<List<String>> _ollamaModels(String base) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.getUrl(Uri.parse('$base/api/tags'));
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];
      final body = await resp.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map;
      return ((j['models'] as List?) ?? []).map((m) => (m as Map)['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<AgentSettings?> discoverOllama() async {
    try {
      // Also try this device itself first (Ollama via Termux etc.).
      for (final base in ['http://127.0.0.1:11434']) {
        final models = await _ollamaModels(base);
        if (models.isNotEmpty) return _pick(base, models);
      }
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      final prefixes = <String>{};
      for (final ni in ifs) {
        for (final a in ni.addresses) {
          final parts = a.address.split('.');
          if (parts.length == 4 && parts[0] != '169') prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
      final hosts = <String>[];
      for (final p in prefixes) {
        for (int i = 1; i <= 254; i++) {
          hosts.add('$p.$i');
        }
      }
      String? found;
      for (int s = 0; s < hosts.length && found == null; s += 48) {
        final end = s + 48 > hosts.length ? hosts.length : s + 48;
        final results = await Future.wait(hosts.sublist(s, end).map((h) async {
          try {
            final sock = await Socket.connect(h, 11434, timeout: const Duration(milliseconds: 220));
            sock.destroy();
            return h;
          } catch (_) {
            return null;
          }
        }));
        for (final r in results) {
          if (r != null) {
            found = r;
            break;
          }
        }
      }
      if (found == null) return null;
      final base = 'http://$found:11434';
      final models = await _ollamaModels(base);
      if (models.isEmpty) return null;
      return _pick(base, models);
    } catch (_) {
      return null;
    }
  }

  static Future<AgentSettings> _pick(String base, List<String> models) async {
    final model = models.firstWhere(
      (m) => m.toLowerCase().contains('qwen'),
      orElse: () => models.firstWhere((m) => m.toLowerCase().contains('llama'), orElse: () => models.first),
    );
    final s = AgentSettings(mode: 'ollama', baseUrl: base, model: model);
    await s.save();
    return s;
  }
}
