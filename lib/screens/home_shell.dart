import 'dart:async';
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
import '../services/change_radar.dart';
import '../services/doctor_brain.dart';
import '../theme/vital_orbit.dart';
import '../widgets/vitals_strip.dart';
import '../widgets/core_dial.dart';
import '../widgets/vital_ring.dart';
import '../widgets/evidence_chip.dart';
import '../widgets/doctor_avatar.dart';
import '../widgets/ai_assessment.dart';
import 'dashboard_screen.dart';
import 'agent_screen.dart';
import 'case_file_screen.dart';
import 'scan_screens.dart';
import 'wizard_screen.dart';

/// VITAL ORBIT shell (spec §4): time is the main axis.
/// PAST (record) · NOW (vitals) · NEXT (treat) - three scenes around one
/// phone, navigated by the edge time rail, by pulling/pushing past a
/// scene's scroll edges, or from the menu sheet. The Core Dial (bottom
/// center) is the only persistent control: tap = doctor, double-tap =
/// Quick Check, long-press + drag = radial dive into a system.
/// All data loading, the recorder, the agent and every detail screen are
/// the existing BlackBox MD engines - this shell is their new cockpit.
class OrbitShell extends StatefulWidget {
  const OrbitShell({super.key});
  @override
  State<OrbitShell> createState() => _OrbitShellState();
}

class _OrbitShellState extends State<OrbitShell> {
  // Scene indices on the time axis.
  static const past = 0, now = 1, next = 2;
  int _scene = now;
  int _prevScene = now;
  int _pastTab = 0; // 0 timeline, 1 case file
  int _nowPage = 0; // 0 anatomy, 1 vitals, 2 apps, 3 storage, 4 system
  int _nextTab = 0; // 0 treatments, 1 wizard
  DateTime _lastSwitch = DateTime.fromMillisecondsSinceEpoch(0);

  bool _loading = true;
  BatteryDetail? _battery;
  ThermalInfo? _thermal;
  MemoryStorage? _mem;
  SystemIntegrity? _sys;
  List<RecorderEvent> _events = [];
  String _deviceLine = 'Unknown device';
  String _androidLine = 'Unknown Android';
  List<AppInfoItem> _apps = [];
  List<Map<String, dynamic>> _files = [];
  List<String> _changes = [];
  List<Map<String, dynamic>> _samples = [];
  int? _lastBeatMs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final di = await DeviceInfoPlugin().androidInfo;
      _deviceLine = '${di.manufacturer} ${di.model} (${di.device})';
      _androidLine = 'Android ${di.version.release} SDK ${di.version.sdkInt}, patch ${di.version.securityPatch}';
    } catch (_) {}
    _battery = await NativeDiagnostics.battery();
    _thermal = await NativeDiagnostics.thermal();
    _mem = await NativeDiagnostics.memoryStorage();
    _sys = await NativeDiagnostics.systemIntegrity();
    final boot = await NativeDiagnostics.bootInfo();
    final bc = (boot['bootCount'] as num?)?.toInt() ?? -1;
    final up = (boot['uptimeMs'] as num?)?.toInt() ?? -1;
    _events = await Recorder.checkAndLoad(bootCount: bc, uptimeMs: up);
    if (_battery != null) {
      await Recorder.heartbeat(batteryPct: _battery!.level, tempC: _battery!.tempC, thermal: _thermal?.label ?? 'unknown', uptimeMs: up);
    }
    _apps = await NativeDiagnostics.installedApps();
    _files = await NativeDiagnostics.sharedFiles();
    _changes = await ChangeRadar.diff(apps: _apps, sys: _sys, mem: _mem, battery: _battery);
    if (_changes.isNotEmpty) {
      if (_changes.length <= 6) {
        for (final c in _changes) {
          await Recorder.add('change_detected', c);
        }
      } else {
        await Recorder.add('change_detected', '${_changes.length} changes since last check: ${_changes.take(6).join('; ')}; and more - see Apps/System');
      }
      _events = await Recorder.checkAndLoad(bootCount: bc, uptimeMs: up);
    }
    _samples = await Recorder.samples();
    _lastBeatMs = await Recorder.lastHeartbeatMs();
    if (mounted) setState(() => _loading = false);
  }

  HealthResult get _health => evaluateHealth(b: _battery, t: _thermal, ms: _mem, sys: _sys, uncleanCount: _deaths);
  int get _deaths => _events.where((e) => e.kind == 'unexpected_reboot').length;

  /// Lite mode (spec §9): hot, low-battery or low-memory phones get flat
  /// surfaces and no decorative animation - the app must not hurt the phone.
  bool get _lite => (_thermal?.status ?? 0) >= 2 || (_battery?.level ?? 100) < 15 || (_mem?.lowMemory ?? false);

  bool get _recGap => _lastBeatMs != null && DateTime.now().millisecondsSinceEpoch - _lastBeatMs! > 6 * 3600 * 1000;

  bool get _alertLine {
    if (_events.isEmpty) return false;
    final e = _events.first; // newest first
    return e.kind == 'unexpected_reboot' && DateTime.now().millisecondsSinceEpoch - e.tsMs < 24 * 3600 * 1000;
  }

  int get _daysRecorded {
    if (_events.isEmpty) return 1;
    final first = _events.map((e) => e.tsMs).reduce((a, b) => a < b ? a : b);
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(first)).inDays + 1;
  }

  String _caseContext() {
    final appFlags = scanApps(_apps, {}).map((f) => '${f.app.label}: ${f.flags.join('; ')}').toList();
    final fileFlags = scanFiles(_files).map((f) => '${f.kind}: ${f.path}').toList();
    return DoctorBrain.buildContext(deviceLine: _deviceLine, androidLine: _androidLine, health: _health, b: _battery, t: _thermal, ms: _mem, sys: _sys, events: _events, changes: _changes, appFlags: appFlags, fileFlags: fileFlags);
  }

  Future<void> _shareReport() async {
    final appFlags = scanApps(_apps, {}).map((f) => '${f.app.label} (${f.app.packageName}): ${f.flags.join('; ')}').toList();
    final fileFlags = scanFiles(_files).map((f) => '${f.kind}: ${f.path} - ${f.detail}').toList();
    final text = buildRepairReport(deviceLine: _deviceLine, androidLine: _androidLine, b: _battery, t: _thermal, ms: _mem, sys: _sys, health: _health, events: _events, appFlags: appFlags, fileFlags: fileFlags);
    await Share.share(text, subject: 'BlackBox MD Repair Passport - $_deviceLine');
  }

  // ---------- navigation ----------
  void _goScene(int s) {
    final clamped = s.clamp(0, 2);
    if (clamped == _scene) return;
    setState(() {
      _prevScene = _scene;
      _scene = clamped;
    });
  }

  void _goNow(int page) => setState(() {
        _prevScene = _scene;
        _scene = now;
        _nowPage = page;
      });

  void _goPast(int tab) => setState(() {
        _prevScene = _scene;
        _scene = past;
        _pastTab = tab;
      });

  void _goNext(int tab) => setState(() {
        _prevScene = _scene;
        _scene = next;
        _nextTab = tab;
      });

  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification) {
      final t = DateTime.now();
      if (t.difference(_lastSwitch).inMilliseconds < 900) return false;
      if (n.overscroll < -6 && n.metrics.extentBefore == 0 && _scene > past) {
        _lastSwitch = t;
        _goScene(_scene - 1);
      } else if (n.overscroll > 6 && n.metrics.extentAfter == 0 && _scene < next) {
        _lastSwitch = t;
        _goScene(_scene + 1);
      }
    }
    return false;
  }

  void _openAgent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Theme(
            data: boMaterialTheme(BOTokens.paper),
            child: AgentScreen(
            caseContext: _caseContext(),
            onOpenWizard: () {
              Navigator.pop(sheetCtx);
              _goNext(1);
            },
            onOpenApps: () {
              Navigator.pop(sheetCtx);
              _goNow(2);
            },
            onOpenFiles: () {
              Navigator.pop(sheetCtx);
              _goNow(3);
            },
            onShare: _shareReport,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _quickCheck() async {
    await _load();
    _goNow(0);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quick check complete - score ${_health.score}: ${_health.verdict}')));
    }
  }

  void _dialSegment(String id) {
    switch (id) {
      case 'battery':
      case 'thermal':
        _goNow(1);
      case 'storage':
        _goNow(3);
      case 'apps':
        _goNow(2);
      case 'system':
        _goNow(4);
    }
  }

  void _showThemes() {
    final t = BOTokens.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Text('Theme', style: boTitle(c, size: 17)),
          for (final (id, name, desc) in [
            ('midnight', 'Midnight Cobalt', 'The cockpit. Dark, AMOLED-friendly.'),
            ('aurora', 'Aurora Lab', 'Dark, playful green.'),
            ('paper', 'Paper Lab', 'Light lab bench - every screen at full contrast.'),
          ])
            ListTile(
              leading: Icon(boThemeName.value == id ? Icons.radio_button_checked : Icons.radio_button_off, color: t.textPrimary),
              title: Text(name, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text(desc, style: TextStyle(color: t.textSecondary)),
              onTap: () {
                setBOTheme(id);
                Navigator.pop(c);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showMenu() {
    final t = BOTokens.of(context);
    Widget item(IconData icon, String label, VoidCallback go) => ListTile(
          leading: Icon(icon, color: t.textPrimary),
          title: Text(label, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            go();
          },
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const SizedBox(height: 8),
          item(Icons.smart_toy_rounded, 'Talk to Dr. BlackBox', _openAgent),
          item(Icons.bolt, 'Quick Check', _quickCheck),
          const Divider(),
          item(Icons.favorite, 'NOW - Anatomy', () => _goNow(0)),
          item(Icons.monitor_heart, 'NOW - Vitals (battery & thermal)', () => _goNow(1)),
          item(Icons.apps, 'NOW - Apps & Cache Radar', () => _goNow(2)),
          item(Icons.cleaning_services, 'NOW - Storage Doctor', () => _goNow(3)),
          item(Icons.verified_user, 'NOW - System Integrity', () => _goNow(4)),
          const Divider(),
          item(Icons.timeline, 'PAST - Black Box Timeline', () => _goPast(0)),
          item(Icons.assignment, 'PAST - Case File', () => _goPast(1)),
          item(Icons.healing, 'NEXT - Treatments', () => _goNext(0)),
          item(Icons.help_outline, 'NEXT - Why did my phone die?', () => _goNext(1)),
          const Divider(),
          item(Icons.share, 'Share Repair Passport', _shareReport),
          item(Icons.palette_outlined, 'Theme', _showThemes),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  /// Legacy detail screens were drawn for light surfaces. In the dark
  /// cockpit themes they render inside a "lab sheet": a Paper Lab panel
  /// with its own theme and ink text colour, so every legacy label stays
  /// readable while the shell (strip, rail, dial, anatomy) goes full
  /// cockpit. In Paper Lab the sheet simply matches the app.
  Widget _lab(Widget child) => Theme(
        data: boMaterialTheme(BOTokens.paper),
        child: DefaultTextStyle(style: const TextStyle(color: Color(0xFF12283F)), child: child),
      );

  Widget _labSheet(Widget child) => Container(
        margin: const EdgeInsets.fromLTRB(6, 2, 6, 0),
        decoration: BoxDecoration(color: const Color(0xFFF4F6FB), borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: _lab(child),
      );

  // ---------- scenes ----------
  Widget _sceneContent() {
    switch (_scene) {
      case past:
        return _pastScene();
      case next:
        return _nextScene();
      default:
        return _nowScene();
    }
  }

  Widget _pastScene() {
    final t = BOTokens.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Row(children: [
          Text('PAST', style: boData(context, size: 11, color: t.accentPulse)),
          const SizedBox(width: 10),
          Expanded(child: Text('the record', style: TextStyle(color: t.textDim, fontSize: 12.5))),
          _segChip('Timeline', _pastTab == 0, () => setState(() => _pastTab = 0)),
          const SizedBox(width: 6),
          _segChip('Case File', _pastTab == 1, () => setState(() => _pastTab = 1)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: t.surfaceGlass.withValues(alpha: t.dark ? 0.8 : 1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _recGap ? t.watch : t.lineHair)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_recGap ? Icons.warning_amber : Icons.fiber_manual_record, size: 16, color: _recGap ? t.watch : t.ok),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _recGap
                    ? 'Recorder gap: the last heartbeat is over 6 hours old. Android or the OEM battery killer may have stopped the app - reopening it (as now) restarts the record. Samples are taken when the app opens and during checks; there is no 24x7 background service, by design.'
                    : 'Recorder alive. Samples are taken when the app opens and during checks - the vitals line connects real sample points; there is no 24x7 background service, by design. Events are hash-chained: edits break the chain.',
                style: TextStyle(fontSize: 12, height: 1.4, color: t.textSecondary),
              ),
            ),
          ]),
        ),
      ),
      Expanded(
        child: _labSheet(
          _pastTab == 0
              ? TimelineScreen(events: _events)
              : CaseFileScreen(
                  events: _events,
                  health: _health,
                  battery: _battery,
                  mem: _mem,
                  sys: _sys,
                  deviceLine: _deviceLine,
                  changes: _changes,
                  caseContext: _caseContext(),
                  onOpenAgent: _openAgent,
                  onOpenWizard: () => _goNext(1),
                  onOpenApps: () => _goNow(2),
                  onOpenFiles: () => _goNow(3),
                  onShare: _shareReport,
                ),
        ),
      ),
    ]);
  }

  Widget _nowScene() {
    if (_nowPage == 0) return _anatomy();
    final Widget page = switch (_nowPage) {
      1 => DashboardScreen(loading: _loading, battery: _battery, thermal: _thermal, mem: _mem, sys: _sys, health: _health, deviceLine: _deviceLine, androidLine: _androidLine, onRefresh: _load, onShare: _shareReport),
      2 => AppsScanScreen(apps: _apps),
      3 => FilesScanScreen(files: _files, onFilesChanged: _load),
      _ => SystemScreen(sys: _sys, androidLine: _androidLine),
    };
    final t = BOTokens.of(context);
    final label = switch (_nowPage) { 1 => 'Vitals', 2 => 'Apps & Cache Radar', 3 => 'Storage Doctor', _ => 'System Integrity' };
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 0),
        child: Row(children: [
          TextButton.icon(onPressed: () => setState(() => _nowPage = 0), icon: Icon(Icons.arrow_back, size: 17, color: t.accentCore), label: Text('Anatomy', style: TextStyle(color: t.accentCore, fontWeight: FontWeight.w700))),
          const SizedBox(width: 4),
          Text(label, style: boTitle(context, size: 16)),
        ]),
      ),
      Expanded(child: _labSheet(page)),
    ]);
  }

  Widget _nextScene() {
    final t = BOTokens.of(context);
    if (_nextTab == 1) {
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 0),
          child: Row(children: [
            TextButton.icon(onPressed: () => setState(() => _nextTab = 0), icon: Icon(Icons.arrow_back, size: 17, color: t.accentCore), label: Text('Treatments', style: TextStyle(color: t.accentCore, fontWeight: FontWeight.w700))),
            const SizedBox(width: 4),
            Text('Why did it die?', style: boTitle(context, size: 16)),
          ]),
        ),
        Expanded(child: _labSheet(const WizardScreen())),
      ]);
    }
    return _treatments();
  }

  Widget _treatments() {
    final t = BOTokens.of(context);
    final fp = '${_events.length}|$_deaths|${_changes.length}|${_health.score}';
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 20), children: [
      Row(children: [
        Text('NEXT', style: boData(context, size: 11, color: t.accentHeat)),
        const SizedBox(width: 10),
        Text('what to do', style: TextStyle(color: t.textDim, fontSize: 12.5)),
      ]),
      const SizedBox(height: 4),
      Text('Treatments & forecast', style: boTitle(context, size: 22)),
      const SizedBox(height: 10),
      if (_deaths > 0)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.bad.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: t.bad, width: 1.4)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.backup, color: t.bad, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Back up now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: t.textPrimary)),
                const SizedBox(height: 3),
                Text('$_deaths unexpected shutdown${_deaths == 1 ? '' : 's'} on record. A phone that dies without warning can stop booting - copy photos and important files somewhere safe today.', style: TextStyle(fontSize: 13, height: 1.4, color: t.textSecondary)),
              ]),
            ),
          ]),
        ),
      if (_deaths > 0) const SizedBox(height: 10),
      _lab(AiAssessmentCard(
        caseContext: _caseContext(),
        fingerprint: fp,
        onOpenAgent: _openAgent,
        onOpenWizard: () => _goNext(1),
        onOpenApps: () => _goNow(2),
        onOpenFiles: () => _goNow(3),
        onShare: _shareReport,
      )),
      const SizedBox(height: 6),
      Text('Treatment queue', style: boTitle(context, size: 16)),
      const SizedBox(height: 4),
      if (_health.warnings.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.surfaceGlass.withValues(alpha: t.dark ? 0.8 : 1), borderRadius: BorderRadius.circular(16), border: Border.all(color: t.lineHair)),
          child: Text('Nothing in the queue - no warnings from the latest check. Keep the recorder fed: open the app now and then so samples stay fresh.', style: TextStyle(color: t.textSecondary, fontSize: 13.5, height: 1.4)),
        ),
      for (final w in _health.warnings.take(6)) _treatmentCard(w),
      const SizedBox(height: 10),
      if ((_battery?.cycleCount ?? 0) > 0)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.surfaceGlass.withValues(alpha: t.dark ? 0.8 : 1), borderRadius: BorderRadius.circular(16), border: Border.all(color: t.lineHair)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.show_chart, size: 18, color: t.accentPulse),
              const SizedBox(width: 8),
              Text('Battery wear outlook', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: t.textPrimary)),
              const Spacer(),
              EvidenceChip(
                kind: Evidence.estimated,
                label: 'Battery wear outlook',
                source: 'Cycle count (measured) + manufacturer rating',
                why: 'Google rates Pixel batteries to about 80% capacity near 800 cycles. Your cycle count is measured; what it means for THIS battery is an estimate - only a full charge-cycle measurement or a shop tester can grade it exactly.',
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              '${_battery!.cycleCount} cycles measured. Google rates Pixel batteries to ~80% capacity near 800 cycles - treat that line as a rough guide, not a prediction for this individual battery.',
              style: TextStyle(fontSize: 13, height: 1.45, color: t.textSecondary),
            ),
          ]),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => _goNext(1), icon: const Icon(Icons.help_outline), label: const Text('Run the Verdict Wizard - why did it die?')),
    ]);
  }

  Widget _treatmentCard(String warning) {
    final t = BOTokens.of(context);
    final lower = warning.toLowerCase();
    String effort = '1 min';
    String? actionLabel;
    VoidCallback? action;
    if (lower.contains('storage') || lower.contains('free space')) {
      effort = '5 min';
      actionLabel = 'Open Storage Doctor';
      action = () => _goNow(3);
    } else if (lower.contains('update') || lower.contains('patch')) {
      effort = '10 min';
      actionLabel = 'Open System';
      action = () => _goNow(4);
    } else if (lower.contains('back up') || lower.contains('unexpected reboot')) {
      effort = 'Today';
      actionLabel = 'Share Passport';
      action = _shareReport;
    } else if (lower.contains('cycle') || lower.contains('battery health')) {
      effort = 'Needs a shop';
      actionLabel = 'Open Case File';
      action = () => _goPast(1);
    } else if (lower.contains('hot') || lower.contains('thermal') || lower.contains('throttling')) {
      effort = 'Now';
      actionLabel = 'Open Vitals';
      action = () => _goNow(1);
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: t.surfaceGlass.withValues(alpha: t.dark ? 0.8 : 1), borderRadius: BorderRadius.circular(16), border: Border.all(color: t.lineHair)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.healing, size: 17, color: t.accentHeat),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(10)),
            child: Text(effort, style: boData(context, size: 10, color: t.textSecondary)),
          ),
        ]),
        const SizedBox(height: 7),
        Text(warning, style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textPrimary)),
        if (action != null) ...[
          const SizedBox(height: 9),
          Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: action, child: Text(actionLabel!))),
        ],
      ]),
    );
  }

  // ---------- NOW: anatomy home ----------
  Widget _anatomy() {
    final t = BOTokens.of(context);
    final h = _health;
    final flaggedApps = scanApps(_apps, {}).length;
    final speech = _deaths > 0
        ? 'I lost power $_deaths time${_deaths == 1 ? '' : 's'} with no clean shutdown. The evidence is in the Past - and a backup belongs in your Next.'
        : h.warnings.isNotEmpty
            ? 'Mostly stable. One thing needs eyes: ${h.warnings.first}'
            : 'Your phone is stable right now. I am recording - if it ever dies without warning, I will have the evidence.';
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 20), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DoctorAvatar(mode: _deaths > 0 ? DoctorMode.hurt : DoctorMode.exam, size: 62, concerned: _deaths > 0),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.surfaceGlass.withValues(alpha: t.dark ? 0.85 : 1), borderRadius: BorderRadius.circular(16), border: Border.all(color: t.lineHair)),
            child: _TypewriterText(key: ValueKey(speech), text: speech, style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textPrimary), lite: _lite),
          ),
        ),
      ]),
      if (_lite)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Lite mode: your phone is hot, low or short on memory, so I have lightened my own effects to avoid adding heat.', style: TextStyle(fontSize: 11.5, color: t.watch)),
        ),
      const SizedBox(height: 8),
      SizedBox(
        height: 348,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: const Size(168, 320), painter: _PhoneBodyPainter(tokens: t, thermalStatus: _thermal?.status ?? 0)),
          Icon(Icons.favorite, size: 40, color: (_battery?.level ?? 100) < 20 ? t.bad : t.ok.withValues(alpha: 0.9)),
          _organ(top: 6, left: 0, icon: Icons.thermostat, label: 'Thermal', value: _battery != null ? '${_battery!.tempC.toStringAsFixed(0)}°C' : '···', color: _thermalColor(t), onTap: () => _goNow(1)),
          _organ(top: 6, right: 0, icon: Icons.storage, label: 'Storage', value: _mem != null ? '${_mem!.storageUsedPct}%' : '···', color: _storageColor(t), onTap: () => _goNow(3)),
          _organ(bottom: 44, left: 0, icon: Icons.battery_charging_full, label: 'Battery', value: _battery != null ? '${_battery!.level}%' : '···', color: _batteryColor(t), onTap: () => _goNow(1)),
          _organ(bottom: 44, right: 0, icon: Icons.apps, label: 'Apps', value: flaggedApps == 0 ? 'clear' : '$flaggedApps flagged', color: flaggedApps == 0 ? t.ok : t.watch, onTap: () => _goNow(2)),
          _organ(bottom: -2, icon: Icons.verified_user, label: 'System', value: _sys == null ? '···' : (_sys!.verifiedBootState == 'green' ? 'verified' : _sys!.verifiedBootState), color: _systemColor(t), onTap: () => _goNow(4)),
        ]),
      ),
      const SizedBox(height: 6),
      Center(child: VitalRing(score: h.score)),
      const SizedBox(height: 6),
      Center(child: Text(h.verdict, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.textPrimary))),
      const SizedBox(height: 7),
      Center(
        child: EvidenceChip(
          kind: Evidence.estimated,
          label: 'Health score',
          source: 'BlackBox MD heuristic',
          why: 'The score combines measured battery, thermal, storage and system values with the recorder\'s reboot evidence. The inputs are measured; the single combined number is an estimate - a guide, not a lab grade. Tap any value in Vitals to see its own label.',
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: _quickCheck, icon: const Icon(Icons.bolt), label: const Text('Quick check')),
      const SizedBox(height: 10),
      Text(
        'Time axis: pull past the top edge for the Past, push past the bottom edge for Next. Hold the glowing core below and drag for Battery, Thermal, Storage, Apps and System. Double-tap it for a Quick Check.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, height: 1.45, color: t.textDim),
      ),
      Center(
        child: TextButton.icon(onPressed: _openAgent, icon: Icon(Icons.smart_toy_outlined, size: 17, color: t.accentPulse), label: Text('Ask Dr. BlackBox', style: TextStyle(color: t.accentPulse, fontWeight: FontWeight.w700))),
      ),
    ]);
  }

  Color _thermalColor(BOTokens t) => (_thermal?.status ?? 0) >= 3 ? t.bad : (_thermal?.status ?? 0) == 2 ? t.watch : t.ok;
  Color _storageColor(BOTokens t) => (_mem?.storageUsedPct ?? 0) >= 95 ? t.bad : (_mem?.storageUsedPct ?? 0) >= 85 ? t.watch : t.ok;
  Color _batteryColor(BOTokens t) => (_battery?.level ?? 100) < 15 ? t.bad : (_battery?.level ?? 100) < 30 || (_battery != null && _battery!.health != 'Good' && _battery!.health != 'Unknown') ? t.watch : t.ok;
  Color _systemColor(BOTokens t) {
    if (_sys == null) return t.ghost;
    if (_sys!.rootSuspected || _sys!.verifiedBootState == 'orange' || _sys!.verifiedBootState == 'red') return t.bad;
    if (_sys!.patchAgeDays > 180) return t.watch;
    return t.ok;
  }

  Widget _organ({double? top, double? bottom, double? left, double? right, required IconData icon, required String label, required String value, required Color color, required VoidCallback onTap}) {
    final t = BOTokens.of(context);
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 92,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.surfaceRaised, border: Border.all(color: color, width: 2)),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.textPrimary)),
            Text(value, style: boData(context, size: 10.5, color: t.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Widget _segChip(String label, bool selected, VoidCallback onTap) {
    final t = BOTokens.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? (t.dark ? const Color(0xFF04222E) : Colors.white) : t.textSecondary),
      selectedColor: t.accentCore,
      backgroundColor: t.surfaceGlass,
      side: BorderSide(color: t.lineHair),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _timeRail() {
    final t = BOTokens.of(context);
    Widget node(int scene, String label) {
      final active = _scene == scene;
      return GestureDetector(
        onTap: () => _goScene(scene),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: active ? 10 : 7,
              height: active ? 10 : 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: active ? t.accentCore : t.ghost, boxShadow: active ? [BoxShadow(color: t.accentCore.withValues(alpha: 0.7), blurRadius: 8)] : null),
            ),
            const SizedBox(height: 4),
            RotatedBox(
              quarterTurns: 3,
              child: Text(label, style: TextStyle(fontSize: 8.5, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: active ? t.accentCore : t.textDim)),
            ),
          ]),
        ),
      );
    }

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.keyboard_arrow_up, size: 15, color: t.textDim),
      node(next, 'NEXT'),
      node(now, 'NOW'),
      node(past, 'PAST'),
      Icon(Icons.keyboard_arrow_down, size: 15, color: t.textDim),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = BOTokens.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final dir = _scene >= _prevScene ? 1.0 : -1.0;
    return Scaffold(
      body: Column(children: [
        VitalsStrip(
          samples: _samples,
          batteryPct: _battery?.level,
          tempC: _battery?.tempC,
          daysRecorded: _daysRecorded,
          recGap: _recGap,
          alertLine: _alertLine,
          lite: _lite,
          onTheme: _showThemes,
          onMenu: _showMenu,
          onShare: _shareReport,
          onRefresh: _load,
        ),
        Expanded(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.only(right: 24, bottom: 92),
              child: _loading && _battery == null
                  ? const Center(child: CircularProgressIndicator())
                  : NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: AnimatedSwitcher(
                        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: reduceMotion ? child : SlideTransition(position: Tween<Offset>(begin: Offset(0, 0.05 * dir), end: Offset.zero).animate(anim), child: child),
                        ),
                        child: KeyedSubtree(key: ValueKey('$_scene-$_pastTab-$_nowPage-$_nextTab'), child: _sceneContent()),
                      ),
                    ),
            ),
            Positioned(right: 1, top: 0, bottom: 92, child: _timeRail()),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: CoreDial(
                  onTap: _openAgent,
                  onDoubleTap: _quickCheck,
                  onSegment: _dialSegment,
                  lite: _lite,
                  alert: _alertLine,
                ),
              ),
            ),
            if (_lite)
              Positioned(
                bottom: 86,
                left: 0,
                right: 0,
                child: Center(child: Text('LITE', style: boData(context, size: 9, color: t.watch))),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Translucent phone body whose glow follows the OS thermal status
/// (battery temperature + thermal status - never a fabricated CPU temp).
class _PhoneBodyPainter extends CustomPainter {
  final BOTokens tokens;
  final int thermalStatus;
  const _PhoneBodyPainter({required this.tokens, required this.thermalStatus});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(30));
    final glow = switch (thermalStatus) {
      >= 3 => tokens.bad,
      2 => tokens.accentHeat,
      1 => tokens.watch,
      _ => tokens.accentCore,
    };
    canvas.drawRRect(rect, Paint()..color = glow.withValues(alpha: 0.13)..style = PaintingStyle.fill);
    canvas.drawRRect(rect, Paint()..color = tokens.surfaceRaised.withValues(alpha: 0.55)..style = PaintingStyle.fill);
    canvas.drawRRect(rect, Paint()..color = glow.withValues(alpha: 0.75)..style = PaintingStyle.stroke..strokeWidth = 2);
    // Speaker slit + camera dot
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width / 2 - 22, 12, 44, 5), const Radius.circular(3)), Paint()..color = tokens.textDim.withValues(alpha: 0.6));
    canvas.drawCircle(Offset(size.width / 2, 30), 4, Paint()..color = tokens.textDim.withValues(alpha: 0.7));
    // Storage fill level along the bottom inside edge
    canvas.drawLine(Offset(18, size.height - 16), Offset(size.width - 18, size.height - 16), Paint()..color = tokens.ghost.withValues(alpha: 0.6)..strokeWidth = 3..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_PhoneBodyPainter old) => old.thermalStatus != thermalStatus;
}

/// Typewriter speech (spec §6.3): 35 ms per character, tap to skip.
/// Static in lite mode or when the system asks for reduced motion.
class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool lite;
  const _TypewriterText({super.key, required this.text, required this.style, required this.lite});
  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.lite) {
      _shown = widget.text.length;
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 35), (tm) {
      if (!mounted) return;
      if (_shown >= widget.text.length) {
        tm.cancel();
        return;
      }
      setState(() => _shown += 2);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return Text(widget.text, style: widget.style);
    final full = _shown >= widget.text.length;
    return GestureDetector(
      onTap: full
          ? null
          : () => setState(() {
                _shown = widget.text.length;
                _timer?.cancel();
              }),
      child: Text(full ? widget.text : widget.text.substring(0, _shown.clamp(0, widget.text.length)), style: widget.style),
    );
  }
}
