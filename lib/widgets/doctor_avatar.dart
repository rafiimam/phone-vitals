import 'package:flutter/material.dart';

/// Dr. BlackBox - the layered-vector doctor.
/// One base character; each problem type swaps the outfit colour, the hat,
/// the chest tool chip and the speech. Layered vector (CustomPainter) keeps
/// the APK tiny and runs on low-end phones; a Rive rig can replace the
/// painter later without changing callers.
enum DoctorMode { exam, storage, battery, heat, cache, notifications, detective, connectivity, hardware, update, hurt, thinking, celebrate }

extension DoctorModeInfo on DoctorMode {
  String get label => switch (this) {
        DoctorMode.exam => 'Check-up',
        DoctorMode.storage => 'Storage treatment',
        DoctorMode.battery => 'Battery clinic',
        DoctorMode.heat => 'Cool-down',
        DoctorMode.cache => 'Cache inspection',
        DoctorMode.notifications => 'Notification repair',
        DoctorMode.detective => 'Crash investigation',
        DoctorMode.connectivity => 'Connectivity',
        DoctorMode.hardware => 'Hardware tests',
        DoctorMode.update => 'Update surgery',
        DoctorMode.hurt => 'Recovering',
        DoctorMode.thinking => 'Thinking',
        DoctorMode.celebrate => 'Treatment verified',
      };
  IconData get icon => switch (this) {
        DoctorMode.exam => Icons.medical_services,
        DoctorMode.storage => Icons.cleaning_services,
        DoctorMode.battery => Icons.battery_charging_full,
        DoctorMode.heat => Icons.thermostat,
        DoctorMode.cache => Icons.search,
        DoctorMode.notifications => Icons.notifications_active,
        DoctorMode.detective => Icons.fingerprint,
        DoctorMode.connectivity => Icons.wifi,
        DoctorMode.hardware => Icons.build,
        DoctorMode.update => Icons.system_update,
        DoctorMode.hurt => Icons.healing,
        DoctorMode.thinking => Icons.psychology_alt,
        DoctorMode.celebrate => Icons.celebration,
      };
  Color get accent => switch (this) {
        DoctorMode.exam => const Color(0xFF17457A),
        DoctorMode.storage => const Color(0xFFF97316),
        DoctorMode.battery => const Color(0xFF2E7D32),
        DoctorMode.heat => const Color(0xFFC62828),
        DoctorMode.cache => const Color(0xFF6A1B9A),
        DoctorMode.notifications => const Color(0xFF00838F),
        DoctorMode.detective => const Color(0xFF5D4037),
        DoctorMode.connectivity => const Color(0xFFF9A825),
        DoctorMode.hardware => const Color(0xFF37474F),
        DoctorMode.update => const Color(0xFF00897B),
        DoctorMode.hurt => const Color(0xFFE5334F),
        DoctorMode.thinking => const Color(0xFF7B61FF),
        DoctorMode.celebrate => const Color(0xFF10B97A),
      };
  Color get outfit => switch (this) {
        DoctorMode.exam => const Color(0xFFFFFFFF),
        DoctorMode.storage => const Color(0xFFFB923C),
        DoctorMode.battery => const Color(0xFFFFFFFF),
        DoctorMode.heat => const Color(0xFFFEE2E2),
        DoctorMode.cache => const Color(0xFFEDE9FE),
        DoctorMode.notifications => const Color(0xFFE0F7FA),
        DoctorMode.detective => const Color(0xFFD7CCC8),
        DoctorMode.connectivity => const Color(0xFFFFF3E0),
        DoctorMode.hardware => const Color(0xFFFFFFFF),
        DoctorMode.update => const Color(0xFFB2DFDB),
        DoctorMode.hurt => const Color(0xFFE8EDF5),
        DoctorMode.thinking => const Color(0xFFEDE9FE),
        DoctorMode.celebrate => const Color(0xFFFFFFFF),
      };
}

class DoctorAvatar extends StatelessWidget {
  final DoctorMode mode;
  final double size;
  final bool happy;
  final bool concerned;
  const DoctorAvatar({super.key, required this.mode, this.size = 110, this.happy = false, this.concerned = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.2,
      child: Stack(children: [
        CustomPaint(painter: _DoctorPainter(mode: mode, happy: happy, concerned: concerned), size: Size(size, size * 1.2)),
        Positioned(
          right: size * 0.01,
          bottom: size * 0.05,
          child: Container(
            width: size * 0.30,
            height: size * 0.30,
            decoration: BoxDecoration(color: mode.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: Icon(mode.icon, color: Colors.white, size: size * 0.17),
          ),
        ),
      ]),
    );
  }
}

/// The doctor beside a speech bubble - the standard "the doctor is working /
/// the doctor has a verdict" block used across the app.
class DoctorCard extends StatelessWidget {
  final DoctorMode mode;
  final String speech;
  final bool happy;
  final bool concerned;
  final Color? cardColor;
  const DoctorCard({super.key, required this.mode, required this.speech, this.happy = false, this.concerned = false, this.cardColor});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DoctorAvatar(mode: mode, size: 76, happy: happy, concerned: concerned),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dr. BlackBox - ${mode.label}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF12283F))),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF3F6FA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDFE8F1))),
                child: Text(speech, style: const TextStyle(fontSize: 13.5, height: 1.35, color: Color(0xFF12283F))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DoctorPainter extends CustomPainter {
  final DoctorMode mode;
  final bool happy;
  final bool concerned;
  _DoctorPainter({required this.mode, required this.happy, required this.concerned});
  static const _navy = Color(0xFF17457A);
  static const _ink = Color(0xFF12283F);
  static const _skin = Color(0xFFFFFFFF);
  static const _orange = Color(0xFFF97316);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 240);
    final outline = Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 4.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;

    // Ground shadow
    canvas.drawOval(const Rect.fromLTWH(38, 226, 124, 10), Paint()..color = Colors.black.withOpacity(0.10));

    // Shoes + legs
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(64, 214, 30, 16), const Radius.circular(6)), fill(_navy));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(106, 214, 30, 16), const Radius.circular(6)), fill(_navy));

    // Arms (behind body)
    final armPaint = Paint()..color = mode.outfit..style = PaintingStyle.stroke..strokeWidth = 13..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(56, 158), const Offset(36, 196), armPaint);
    canvas.drawLine(const Offset(144, 158), const Offset(164, 196), armPaint);
    canvas.drawCircle(const Offset(36, 198), 7, fill(_skin));
    canvas.drawCircle(const Offset(164, 198), 7, fill(_skin));

    // Body / outfit
    final bodyRect = RRect.fromRectAndRadius(const Rect.fromLTWH(52, 146, 96, 74), const Radius.circular(16));
    canvas.drawRRect(bodyRect, fill(mode.outfit));
    canvas.drawRRect(bodyRect, outline);
    if (mode == DoctorMode.exam || mode == DoctorMode.battery || mode == DoctorMode.hardware) {
      // Coat: shirt V + centre line + pocket ECG
      final v = Path()..moveTo(84, 148)..lineTo(116, 148)..lineTo(100, 172)..close();
      canvas.drawPath(v, fill(_navy));
      canvas.drawLine(const Offset(100, 172), const Offset(100, 218), Paint()..color = _ink..strokeWidth = 2.5);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(114, 188, 24, 18), const Radius.circular(4)), outline..strokeWidth = 2.5);
      final ecg = Path()..moveTo(117, 197)..lineTo(123, 197)..lineTo(126, 191)..lineTo(130, 202)..lineTo(133, 197)..lineTo(136, 197);
      canvas.drawPath(ecg, Paint()..color = _orange..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
    if (mode == DoctorMode.exam || mode == DoctorMode.battery) {
      // Stethoscope
      final st = Paint()..color = _navy..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
      canvas.drawArc(const Rect.fromLTWH(78, 150, 44, 40), 0.3, 2.6, false, st);
      canvas.drawCircle(const Offset(122, 190), 7, fill(const Color(0xFFB0BEC5)));
      canvas.drawCircle(const Offset(122, 190), 7, outline..strokeWidth = 2.5);
    }

    // Ears
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 66, 16, 36), const Radius.circular(7)), fill(_skin));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 66, 16, 36), const Radius.circular(7)), outline);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(160, 66, 16, 36), const Radius.circular(7)), fill(_skin));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(160, 66, 16, 36), const Radius.circular(7)), outline);

    // Head
    final headRect = RRect.fromRectAndRadius(const Rect.fromLTWH(38, 30, 124, 104), const Radius.circular(34));
    canvas.drawRRect(headRect, fill(_skin));
    canvas.drawRRect(headRect, outline);

    // Hat / headgear per mode
    switch (mode) {
      case DoctorMode.detective:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 34, 140, 10), const Radius.circular(5)), fill(const Color(0xFF5D4037)));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(62, 8, 76, 30), const Radius.circular(12)), fill(const Color(0xFF795548)));
        break;
      case DoctorMode.connectivity:
        canvas.drawArc(const Rect.fromLTWH(52, 2, 96, 52), 3.14, 3.14, false, fill(const Color(0xFFF9A825)));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 30, 108, 9), const Radius.circular(4)), fill(const Color(0xFFF9A825)));
        break;
      case DoctorMode.update:
        canvas.drawArc(const Rect.fromLTWH(54, 4, 92, 46), 3.14, 3.14, false, fill(const Color(0xFF00897B)));
        break;
      case DoctorMode.storage:
        canvas.drawArc(const Rect.fromLTWH(54, 4, 92, 46), 3.14, 3.14, false, fill(_orange));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(96, 26, 52, 8), const Radius.circular(4)), fill(_orange));
        break;
      default:
        // Doctor head mirror
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(40, 40, 120, 13), const Radius.circular(6)), fill(_navy));
        canvas.drawCircle(const Offset(100, 30), 19, fill(const Color(0xFFECEFF1)));
        canvas.drawCircle(const Offset(100, 30), 19, outline);
        canvas.drawCircle(const Offset(100, 30), 11, fill(const Color(0xFFB0BEC5)));
    }

    // Face
    final eye = fill(_ink);
    canvas.drawCircle(const Offset(76, 88), 8.5, eye);
    canvas.drawCircle(const Offset(124, 88), 8.5, eye);
    canvas.drawCircle(const Offset(79, 85), 3, fill(Colors.white));
    canvas.drawCircle(const Offset(127, 85), 3, fill(Colors.white));
    final brow = Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    if (concerned) {
      canvas.drawLine(const Offset(66, 70), const Offset(84, 75), brow);
      canvas.drawLine(const Offset(134, 70), const Offset(116, 75), brow);
    } else {
      canvas.drawArc(const Rect.fromLTWH(65, 64, 22, 12), 3.4, 2.2, false, brow);
      canvas.drawArc(const Rect.fromLTWH(113, 64, 22, 12), 3.7, 2.2, false, brow);
    }
    final mouth = Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    if (concerned) {
      canvas.drawLine(const Offset(90, 114), const Offset(110, 114), mouth);
    } else if (happy) {
      canvas.drawArc(const Rect.fromLTWH(84, 100, 32, 22), 0.15, 2.85, false, mouth..strokeWidth = 4);
    } else {
      canvas.drawArc(const Rect.fromLTWH(86, 102, 28, 16), 0.3, 2.5, false, mouth);
    }
    // State overlays (VITAL ORBIT §6.1)
    if (mode == DoctorMode.hurt) {
      // Bandage across the forehead: "I lost power. Here's what I saw."
      canvas.save();
      canvas.translate(100, 56);
      canvas.rotate(-0.13);
      final band = RRect.fromRectAndRadius(const Rect.fromLTWH(-46, -10, 92, 20), const Radius.circular(7));
      canvas.drawRRect(band, fill(const Color(0xFFF2D492)));
      canvas.drawRRect(band, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
      final stitch = Paint()..color = const Color(0xFFC9A24D)..strokeWidth = 2.4..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-30, -5), const Offset(-30, 5), stitch);
      canvas.drawLine(const Offset(0, -5), const Offset(0, 5), stitch);
      canvas.drawLine(const Offset(30, -5), const Offset(30, 5), stitch);
      canvas.restore();
    }
    if (mode == DoctorMode.thinking) {
      // Orbiting dots around the head
      final dot = fill(const Color(0xFF7B61FF));
      canvas.drawCircle(const Offset(170, 24), 5.5, dot);
      canvas.drawCircle(const Offset(186, 46), 4.2, dot);
      canvas.drawCircle(const Offset(158, 6), 3.4, dot);
    }
    if (mode == DoctorMode.celebrate) {
      // Sparkles
      final gold = fill(const Color(0xFFFFC93D));
      for (final (cx, cy, s) in [(26.0, 22.0, 9.0), (176.0, 14.0, 11.0), (188.0, 74.0, 7.0)]) {
        final star = Path()
          ..moveTo(cx, cy - s)
          ..lineTo(cx + s * 0.28, cy - s * 0.28)
          ..lineTo(cx + s, cy)
          ..lineTo(cx + s * 0.28, cy + s * 0.28)
          ..lineTo(cx, cy + s)
          ..lineTo(cx - s * 0.28, cy + s * 0.28)
          ..lineTo(cx - s, cy)
          ..lineTo(cx - s * 0.28, cy - s * 0.28)
          ..close();
        canvas.drawPath(star, gold);
      }
    }

    // Cheeks
    canvas.drawCircle(const Offset(58, 104), 6, Paint()..color = _orange.withOpacity(0.35));
    canvas.drawCircle(const Offset(142, 104), 6, Paint()..color = _orange.withOpacity(0.35));
  }

  @override
  bool shouldRepaint(covariant _DoctorPainter old) => old.mode != mode || old.happy != happy || old.concerned != concerned;
}
