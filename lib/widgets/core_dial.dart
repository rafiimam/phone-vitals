import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/vital_orbit.dart';

/// The Core Dial (VITAL ORBIT §4.2): the robot's core orb is the only
/// persistent control. Tap = talk to Dr. BlackBox, double-tap = Quick
/// Check, long-press + drag = a 5-segment radial fan (Battery, Thermal,
/// Storage, Apps, System). An accessible list alternative lives in the
/// shell's menu sheet (spec §10).
class DialSegment {
  final String id;
  final String label;
  final IconData icon;
  const DialSegment(this.id, this.label, this.icon);
}

const dialSegments = <DialSegment>[
  DialSegment('battery', 'Battery', Icons.battery_charging_full),
  DialSegment('thermal', 'Thermal', Icons.thermostat),
  DialSegment('storage', 'Storage', Icons.storage),
  DialSegment('apps', 'Apps', Icons.apps),
  DialSegment('system', 'System', Icons.verified_user),
];

class CoreDial extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<String> onSegment;
  final bool lite;
  final bool alert;
  const CoreDial({super.key, required this.onTap, required this.onDoubleTap, required this.onSegment, required this.lite, required this.alert});
  @override
  State<CoreDial> createState() => _CoreDialState();
}

class _CoreDialState extends State<CoreDial> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  OverlayEntry? _fan;
  final ValueNotifier<int> _activeVN = ValueNotifier<int>(-1);
  int get _activeSeg => _activeVN.value;
  Offset _center = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    if (!widget.lite) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(CoreDial old) {
    super.didUpdateWidget(old);
    if (widget.lite && _pulse.isAnimating) _pulse.stop();
    if (!widget.lite && !_pulse.isAnimating) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _removeFan();
    _activeVN.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // Fan geometry: segments fan above the orb, angles -168°..-12°
  // (screen coords: 0° = +x axis, positive clockwise, y down).
  double _angleFor(int i) => (-168 + i * 39) * math.pi / 180;

  int _hitSegment(Offset pos) {
    final d = pos - _center;
    final dist = d.distance;
    if (dist < 58 || dist > 168) return -1;
    var ang = math.atan2(d.dy, d.dx); // -pi..pi
    var best = -1;
    var bestDiff = 1e9;
    for (var i = 0; i < dialSegments.length; i++) {
      var diff = (ang - _angleFor(i)).abs();
      if (diff > math.pi) diff = 2 * math.pi - diff;
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return bestDiff < 0.42 ? best : -1;
  }

  void _showFan() {
    final box = context.findRenderObject() as RenderBox;
    _center = box.localToGlobal(box.size.center(Offset.zero));
    _activeVN.value = -1;
    final tokens = BOTokens.of(context);
    _fan = OverlayEntry(
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: _activeVN,
        builder: (_, active, __) => _FanOverlay(center: _center, active: active, tokens: tokens),
      ),
    );
    Overlay.of(context).insert(_fan!);
  }

  void _updateFan(Offset pos) {
    final seg = _hitSegment(pos);
    if (seg != _activeSeg) {
      _activeVN.value = seg;
      if (seg >= 0) HapticFeedback.selectionClick();
    }
  }

  void _removeFan() {
    _fan?.remove();
    _fan = null;
  }

  void _endFan() {
    final seg = _activeSeg;
    _removeFan();
    _activeVN.value = -1;
    if (seg >= 0) {
      HapticFeedback.heavyImpact();
      widget.onSegment(dialSegments[seg].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BOTokens.of(context);
    final coreColor = widget.alert ? t.bad : t.accentCore;
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPressStart: (_) => _showFan(),
      onLongPressMoveUpdate: (d) => _updateFan(d.globalPosition),
      onLongPressEnd: (_) => _endFan(),
      onLongPressCancel: _removeFan,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final glow = widget.lite ? 0.35 : (0.3 + 0.45 * _pulse.value);
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.accentCore, t.accentPulse]),
              boxShadow: [BoxShadow(color: coreColor.withValues(alpha: glow), blurRadius: 22, spreadRadius: 2)],
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 32),
          );
        },
      ),
    );
  }
}

class _FanOverlay extends StatelessWidget {
  final Offset center;
  final int active;
  final BOTokens tokens;
  const _FanOverlay({required this.center, required this.active, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Material(
      color: Colors.transparent,
      child: Stack(children: [
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.35))),
        CustomPaint(size: MediaQuery.of(context).size, painter: _FanPainter(center: center, active: active, core: t.accentCore, raised: t.surfaceRaised)),
        for (var i = 0; i < dialSegments.length; i++)
          Positioned(
            left: center.dx + 118 * math.cos((-168 + i * 39) * math.pi / 180) - 42,
            top: center.dy + 118 * math.sin((-168 + i * 39) * math.pi / 180) - 42,
            width: 84,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active == i ? t.accentCore : t.surfaceRaised,
                  border: Border.all(color: t.accentCore.withValues(alpha: 0.6)),
                ),
                child: Icon(dialSegments[i].icon, size: 22, color: active == i ? const Color(0xFF04222E) : t.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(dialSegments[i].label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active == i ? t.accentCore : t.textPrimary)),
            ]),
          ),
        Positioned(
          left: center.dx - 90,
          top: center.dy + 52,
          width: 180,
          child: Text('Drag to a segment, release to open', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
        ),
      ]),
    );
  }
}

class _FanPainter extends CustomPainter {
  final Offset center;
  final int active;
  final Color core;
  final Color raised;
  const _FanPainter({required this.center, required this.active, required this.core, required this.raised});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < dialSegments.length; i++) {
      final a = (-168 + i * 39) * math.pi / 180;
      final isActive = i == active;
      final paint = Paint()
        ..color = (isActive ? core : raised).withValues(alpha: isActive ? 0.5 : 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 30 : 24;
      canvas.drawArc(Rect.fromCircle(center: center, radius: 118), a - 0.30, 0.60, false, paint);
    }
  }

  @override
  bool shouldRepaint(_FanPainter old) => old.active != active || old.center != center;
}
