import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/vital_orbit.dart';

/// VitalRing (VITAL ORBIT §7): circular gauge, gradient stroke, mono number
/// at the center, caption under it. The score is a heuristic, never a bare
/// number - the shell always pairs it with a plain-language verdict and an
/// ESTIMATED evidence chip (see anatomy home).
class VitalRing extends StatelessWidget {
  final int score; // 0..100
  final double size;
  final String? centerLabel;
  const VitalRing({super.key, required this.score, this.size = 148, this.centerLabel});

  @override
  Widget build(BuildContext context) {
    final t = BOTokens.of(context);
    final frac = (score / 100).clamp(0.0, 1.0);
    return Semantics(
      label: 'Health score $score out of 100, estimated',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size(size, size), painter: _RingPainter(frac: frac, tokens: t)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$score', style: boData(context, size: size * 0.34, color: t.textPrimary, weight: FontWeight.w700)),
            Text(centerLabel ?? 'HEALTH', style: TextStyle(fontSize: 10.5, letterSpacing: 2.2, color: t.textSecondary, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final BOTokens tokens;
  const _RingPainter({required this.frac, required this.tokens});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 7;
    final track = Paint()
      ..color = tokens.ghost.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    if (frac <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Heat gradient when worsening (spec §8.2): low score sweeps red-ward.
    final colors = frac >= 0.75
        ? [tokens.accentCore, tokens.ok]
        : frac >= 0.5
            ? [tokens.watch, tokens.accentHeat]
            : [tokens.accentHeat, tokens.bad];
    final paint = Paint()
      ..shader = SweepGradient(startAngle: -math.pi / 2, endAngle: math.pi * 1.5, colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * frac, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac;
}
