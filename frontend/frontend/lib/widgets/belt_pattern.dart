import 'package:flutter/material.dart';

/// Marka alanının arka planında görünen, çok düşük opasiteli, yavaşça
/// kayan çapraz çizgi deseni. "Bant" (üretim hattı) temasına ince bir
/// gönderme yapar; dikkat dağıtmayacak kadar sakin tutulmuştur.
///
/// Erişilebilirlik: cihazda hareket azaltma açıksa animasyon durur.
class BeltPattern extends StatefulWidget {
  const BeltPattern({super.key});

  @override
  State<BeltPattern> createState() => _BeltPatternState();
}

class _BeltPatternState extends State<BeltPattern>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (reduceMotion) {
      return CustomPaint(
        painter: _BeltPainter(offset: 0),
        child: const SizedBox.expand(),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _BeltPainter(offset: _controller.value * 26),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BeltPainter extends CustomPainter {
  _BeltPainter({required this.offset});

  final double offset;
  static const double _spacing = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 2;

    // 35 derece açıyla çapraz çizgiler; genişlik + yükseklik kadar
    // taşarak tuvalin her yerini kaplar, offset ile yatayda kayar.
    final diagonal = size.width + size.height;
    final count = (diagonal / _spacing).ceil() + 2;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = -2; i < count; i++) {
      final x = (i * _spacing) + (offset % _spacing) - size.height;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeltPainter oldDelegate) =>
      oldDelegate.offset != offset;
}
