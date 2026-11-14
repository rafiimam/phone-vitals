import 'package:flutter/material.dart';
import '../theme/vital_orbit.dart';

/// The Vitals Strip (VITAL ORBIT §5) replaces the title bar: REC state, a
/// vitals line drawn from REAL recorder samples, and compact numbers.
/// Honesty note (kept in the PAST scene): samples are taken when the app
/// opens and during checks - the recorder runs no 24x7 background service,
/// so the line connects real sample points; it is not a continuous feed.
class VitalsStrip extends StatefulWidget {
  final List<Map<String, dynamic>> samples; // [{ts, pct, temp, thermal}]
  final int? batteryPct;
  final double? tempC;
  final int daysRecorded;
  final bool recGap;
  final bool alertLine;
  final bool lite;
  final VoidCallback onTheme;
  final VoidCallback onMenu;
  final VoidCallback onShare;
  final VoidCallback onRefresh;
  const VitalsStrip({
    super.key,
    required this.samples,
    required this.batteryPct,
    required this.tempC,
    required this.daysRecorded,
    required this.recGap,
    required this.alertLine,
    required this.lite,
    required this.onTheme,
    required this.onMenu,
    required this.onShare,
    required this.onRefresh,
  });
  @override
  State<VitalsStrip> createState() => _VitalsStripState();
}

final _btnStyle = IconButton.styleFrom(minimumSize: const Size(36, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.all(6));

class _VitalsStripState extends State<VitalsStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    if (!widget.lite) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VitalsStrip old) {
    super.didUpdateWidget(old);
    if (widget.lite && _pulse.isAnimating) _pulse.stop();
    if (!widget.lite && !_pulse.isAnimating) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BOTokens.of(context);
    final recColor = widget.alertLine ? t.bad : (widget.recGap ? t.watch : t.ok);
    return Container(
      decoration: BoxDecoration(color: t.bgDeep, border: Border(bottom: BorderSide(color: t.lineHair))),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: 40,
        child: Row(children: [
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recColor.withValues(alpha: widget.lite ? 1 : (0.45 + 0.55 * _pulse.value)),
                boxShadow: [BoxShadow(color: recColor.withValues(alpha: 0.55), blurRadius: 7)],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(widget.recGap ? 'REC GAP' : 'REC', style: boData(context, size: 11, color: recColor)),
          const SizedBox(width: 10),
          Expanded(
            child: CustomPaint(
              painter: _EcgPainter(
                temps: widget.samples.map((s) => (s['temp'] as num?)?.toDouble() ?? 0).toList(),
                color: widget.alertLine ? t.bad : t.accentCore,
                ghost: t.ghost,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${widget.tempC != null ? widget.tempC!.toStringAsFixed(0) : '··'}°C · ${widget.batteryPct ?? '··'}% · ${widget.daysRecorded}d',
            style: boData(context, size: 11.5, color: t.textSecondary),
          ),
          IconButton(style: _btnStyle, onPressed: widget.onTheme, icon: Icon(Icons.palette_outlined, size: 19, color: t.textSecondary), tooltip: 'Theme', visualDensity: VisualDensity.compact),
          IconButton(style: _btnStyle, onPressed: widget.onShare, icon: Icon(Icons.share_outlined, size: 19, color: t.textSecondary), tooltip: 'Share Repair Passport', visualDensity: VisualDensity.compact),
          IconButton(style: _btnStyle, onPressed: widget.onRefresh, icon: Icon(Icons.refresh, size: 19, color: t.textSecondary), tooltip: 'Recheck', visualDensity: VisualDensity.compact),
          IconButton(style: _btnStyle, onPressed: widget.onMenu, icon: Icon(Icons.more_horiz, size: 20, color: t.textSecondary), tooltip: 'All destinations', visualDensity: VisualDensity.compact),
          const SizedBox(width: 4),
        ]),
      ),
    );
  }
}

/// A vital-signs line from battery-temperature samples: each sample is a
/// heartbeat blip whose height follows the temperature. Few samples draw
/// as honest dots - the line never invents data between far-apart points.
class _EcgPainter extends CustomPainter {
  final List<double> temps;
  final Color color;
  final Color ghost;
  const _EcgPainter({required this.temps, required this.color, required this.ghost});

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    if (temps.isEmpty) {
      final p = Paint()..color = ghost..style = PaintingStyle.fill;
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(Offset(6 + i * 12, mid), 1.6, p);
      }
      return;
    }
    final minT = temps.reduce((a, b) => a < b ? a : b);
    final maxT = temps.reduce((a, b) => a > b ? a : b);
    final span = (maxT - minT).clamp(2.0, 30.0);
    final step = size.width / 24;
    final path = Path();
    final pts = <Offset>[];
    final startX = size.width - step * (temps.length - 1) - 4;
    for (var i = 0; i < temps.length; i++) {
      final x = startX + i * step;
      final norm = (temps[i] - minT) / span; // 0..1
      final amp = 2.5 + norm * (size.height / 2 - 4);
      pts.add(Offset(x, mid));
      pts.add(Offset(x + step * 0.3, mid - amp));
      pts.add(Offset(x + step * 0.55, mid + amp * 0.5));
      pts.add(Offset(x + step, mid));
    }
    path.moveTo(0, mid);
    path.lineTo(pts.first.dx, mid);
    for (final o in pts) {
      path.lineTo(o.dx, o.dy);
    }
    path.lineTo(size.width, mid);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeJoin = StrokeJoin.round);
    final dot = Paint()..color = color..style = PaintingStyle.fill;
    for (var i = 0; i < temps.length; i++) {
      canvas.drawCircle(Offset(startX + i * step, mid), 1.8, dot);
    }
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.temps != temps || old.color != color;
}
