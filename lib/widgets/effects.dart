import 'dart:math';

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// Uçuşan para metni: "+200M" (yeşil) / "-450M" (kırmızı)
// ═══════════════════════════════════════════════════════════════════

class FloatingMoney extends StatefulWidget {
  const FloatingMoney({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.onDone,
  });

  final String label;
  final int amount;
  final Color color;
  final VoidCallback onDone;

  @override
  State<FloatingMoney> createState() => _FloatingMoneyState();
}

class _FloatingMoneyState extends State<FloatingMoney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positive = widget.amount >= 0;
    final text = '${positive ? '+' : ''}${widget.amount}M';
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final scale = t < 0.15 ? 0.6 + t / 0.15 * 0.6 : 1.2 - (t - 0.15) * 0.25;
        return Opacity(
          opacity: t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, -70 * Curves.easeOut.transform(t)),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.color, width: 2),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '${widget.label}  ',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            TextSpan(
              text: text,
              style: TextStyle(
                color: positive ? Colors.greenAccent : Colors.redAccent,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Kodes: ekranın üzerine demir parmaklık iner
// ═══════════════════════════════════════════════════════════════════

class JailBarsOverlay extends StatefulWidget {
  const JailBarsOverlay({super.key, required this.name, required this.onDone});

  final String name;
  final VoidCallback onDone;

  @override
  State<JailBarsOverlay> createState() => _JailBarsOverlayState();
}

class _JailBarsOverlayState extends State<JailBarsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // 0-0.25 iner (zıplayarak), 0.25-0.8 bekler, 0.8-1 kaybolur
          final drop =
              Curves.bounceOut.transform((t / 0.25).clamp(0.0, 1.0).toDouble());
          final fade =
              t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0).toDouble();
          // Siren ışığı: kırmızı/mavi yanıp sönme
          final flash = (t * 16).floor().isEven ? Colors.red : Colors.blue;

          return Opacity(
            opacity: fade,
            child: LayoutBuilder(
              builder: (context, box) {
                final h = box.maxHeight;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: flash.withValues(alpha: t < 0.8 ? 0.18 : 0),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: -h + h * drop,
                      height: h,
                      child: CustomPaint(painter: _BarsPainter()),
                    ),
                    Center(
                      child: Opacity(
                        opacity: drop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent, width: 3),
                          ),
                          child: Text(
                            '🚨 KODES!\n${widget.name}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const count = 9;
    final gap = size.width / count;
    final bar = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF424242), Color(0xFFBDBDBD), Color(0xFF424242)],
      ).createShader(Rect.fromLTWH(0, 0, 14, size.height));
    for (var i = 0; i < count; i++) {
      final x = gap * (i + 0.5) - 7;
      canvas.save();
      canvas.translate(x, 0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, 14, size.height), const Radius.circular(7)),
        bar,
      );
      canvas.restore();
    }
    final rail = Paint()..color = const Color(0xFF616161);
    for (final y in [size.height * 0.12, size.height * 0.88]) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 16), rail);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// İnşaat: arsa üzerinde toz bulutu
// ═══════════════════════════════════════════════════════════════════

class DustBurst extends StatefulWidget {
  const DustBurst({super.key});

  @override
  State<DustBurst> createState() => _DustBurstState();
}

class _DustBurstState extends State<DustBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final List<_Puff> _puffs = List.generate(14, (i) {
    final r = Random(i * 7919 + DateTime.now().microsecond);
    return _Puff(
      angle: r.nextDouble() * 2 * pi,
      distance: 0.25 + r.nextDouble() * 0.3,
      radius: 0.08 + r.nextDouble() * 0.1,
      shade: 150 + r.nextInt(70),
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _DustPainter(_puffs, Curves.easeOut.transform(_c.value)),
        ),
      ),
    );
  }
}

class _Puff {
  final double angle, distance, radius;
  final int shade;
  const _Puff({
    required this.angle,
    required this.distance,
    required this.radius,
    required this.shade,
  });
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.puffs, this.t);
  final List<_Puff> puffs;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.shortestSide;
    for (final p in puffs) {
      final d = p.distance * s * t;
      final pos = c + Offset(cos(p.angle) * d, sin(p.angle) * d - t * s * 0.1);
      final paint = Paint()
        ..color = Color.fromARGB(
            (200 * (1 - t)).round(), p.shade, p.shade - 20, p.shade - 45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pos, p.radius * s * (0.6 + t), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// Kazanan: konfeti yağmuru
// ═══════════════════════════════════════════════════════════════════

class ConfettiRain extends StatefulWidget {
  const ConfettiRain({super.key});

  @override
  State<ConfettiRain> createState() => _ConfettiRainState();
}

class _ConfettiRainState extends State<ConfettiRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  final _rnd = Random();
  late final List<_Bit> _bits = List.generate(
    90,
    (_) => _Bit(
      x: _rnd.nextDouble(),
      offset: _rnd.nextDouble(),
      speed: 0.6 + _rnd.nextDouble() * 0.8,
      sway: _rnd.nextDouble() * 2 * pi,
      color: Colors.primaries[_rnd.nextInt(Colors.primaries.length)],
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _ConfettiPainter(_bits, _c.value), size: Size.infinite),
      ),
    );
  }
}

class _Bit {
  final double x, offset, speed, sway;
  final Color color;
  const _Bit({
    required this.x,
    required this.offset,
    required this.speed,
    required this.sway,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);
  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final p = (t * b.speed + b.offset) % 1.0;
      final x = b.x * size.width + sin(p * 6 * pi + b.sway) * 18;
      final y = p * (size.height + 40) - 20;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * 8 * pi + b.sway);
      canvas.drawRect(
          const Rect.fromLTWH(-4, -7, 8, 14), Paint()..color = b.color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
