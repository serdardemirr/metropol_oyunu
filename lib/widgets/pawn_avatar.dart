import 'package:flutter/material.dart';

import '../models/pawn_token.dart';

/// Renkli daire içinde beyaz piyon sembolü.
class PawnAvatar extends StatelessWidget {
  const PawnAvatar({
    super.key,
    required this.pawn,
    this.size = 40,
    this.selected = false,
    this.dimmed = false,
  });

  final PawnToken pawn;
  final double size;
  final bool selected;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pawn.color.withValues(alpha: dimmed ? 0.3 : 1),
        border: Border.all(
          color: selected ? Colors.white : Colors.black45,
          width: selected ? 3 : 1.5,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(color: pawn.color.withValues(alpha: 0.7), blurRadius: 14)
          else
            const BoxShadow(
                color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: PawnSymbolIcon(symbol: pawn.symbol, size: size * 0.6),
    );
  }
}

/// Bir sembolü çizer. Material'da karşılığı olmayan Taç ve Şapka elle çizilir.
class PawnSymbolIcon extends StatelessWidget {
  const PawnSymbolIcon({
    super.key,
    required this.symbol,
    required this.size,
    this.color = Colors.white,
  });

  final PawnSymbol symbol;
  final double size;
  final Color color;

  static IconData? _icon(PawnSymbol s) => switch (s) {
        PawnSymbol.car => Icons.directions_car_filled,
        PawnSymbol.plane => Icons.flight,
        PawnSymbol.ship => Icons.directions_boat_filled,
        PawnSymbol.rocket => Icons.rocket_launch,
        PawnSymbol.diamond => Icons.diamond,
        PawnSymbol.anchor => Icons.anchor,
        PawnSymbol.crown || PawnSymbol.hat => null,
      };

  @override
  Widget build(BuildContext context) {
    final icon = _icon(symbol);
    if (icon != null) {
      return Icon(icon, size: size, color: color, shadows: const [
        Shadow(color: Colors.black54, blurRadius: 2),
      ]);
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _SymbolPainter(symbol, color),
    );
  }
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.symbol, this.color);
  final PawnSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final fill = Paint()..color = color;
    final shadow = Paint()
      ..color = Colors.black45
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    Path path;
    if (symbol == PawnSymbol.crown) {
      path = Path()
        ..moveTo(w * 0.1, h * 0.78)
        ..lineTo(w * 0.1, h * 0.32)
        ..lineTo(w * 0.32, h * 0.55)
        ..lineTo(w * 0.5, h * 0.2)
        ..lineTo(w * 0.68, h * 0.55)
        ..lineTo(w * 0.9, h * 0.32)
        ..lineTo(w * 0.9, h * 0.78)
        ..close();
    } else {
      // Silindir şapka
      path = Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.27, h * 0.12, w * 0.46, h * 0.58),
            Radius.circular(w * 0.05)))
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, h * 0.68, w * 0.84, h * 0.14),
            Radius.circular(w * 0.07)));
    }
    canvas.drawPath(path.shift(const Offset(0.8, 1.2)), shadow);
    canvas.drawPath(path, fill);

    if (symbol == PawnSymbol.crown) {
      final dot = Paint()..color = color;
      for (final x in [0.1, 0.5, 0.9]) {
        canvas.drawCircle(
            Offset(w * x, x == 0.5 ? h * 0.18 : h * 0.3), w * 0.07, dot);
      }
    } else {
      // Şapka bandı
      canvas.drawRect(Rect.fromLTWH(w * 0.27, h * 0.55, w * 0.46, h * 0.08),
          Paint()..color = Colors.black38);
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) =>
      old.symbol != symbol || old.color != color;
}
