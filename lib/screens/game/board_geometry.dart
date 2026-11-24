import 'package:flutter/widgets.dart';

import '../../data/board_layout.dart';

/// Kare tahtanın piksel geometrisi (tahta koordinatlarında).
///
/// Kare sayısı haritaya göre değişir (28 / 44 / 108); kare boyutu sabit
/// kalır, tahta büyür. Başlangıç (0) sağ-alt köşededir. Alt kenar sola,
/// sol kenar yukarı, üst kenar sağa, sağ kenar aşağı doğru ilerler.
class BoardGeometry {
  BoardGeometry(this.layout)
      : perSide = layout.tilesPerSide,
        cellsPerSide = layout.tilesPerSide - 1,
        size = 2 * corner + (layout.tilesPerSide - 1) * cell;

  final BoardLayout layout;
  final int perSide; // köşe dahil
  final int cellsPerSide;
  final double size;

  static const double corner = 150;
  static const double cell = 90;
  static const double band = 24; // renk şeridi kalınlığı

  Rect rectOf(int index) {
    final i = index % layout.length;
    final side = i ~/ perSide;
    final k = i % perSide;

    if (k == 0) {
      switch (side) {
        case 0:
          return Rect.fromLTWH(size - corner, size - corner, corner, corner);
        case 1:
          return Rect.fromLTWH(0, size - corner, corner, corner);
        case 2:
          return const Rect.fromLTWH(0, 0, corner, corner);
        default:
          return Rect.fromLTWH(size - corner, 0, corner, corner);
      }
    }

    switch (side) {
      case 0: // alt kenar, sağdan sola
        return Rect.fromLTWH(size - corner - k * cell, size - corner, cell, corner);
      case 1: // sol kenar, aşağıdan yukarı
        return Rect.fromLTWH(0, size - corner - k * cell, corner, cell);
      case 2: // üst kenar, soldan sağa
        return Rect.fromLTWH(corner + (k - 1) * cell, 0, cell, corner);
      default: // sağ kenar, yukarıdan aşağı
        return Rect.fromLTWH(size - corner, corner + (k - 1) * cell, corner, cell);
    }
  }

  Rect get centerRect =>
      Rect.fromLTWH(corner, corner, size - 2 * corner, size - 2 * corner);

  /// Karenin tahtanın içine bakan kenarı (renk şeridi buraya çizilir).
  AxisDirection innerEdge(int index) {
    switch ((index % layout.length) ~/ perSide) {
      case 0:
        return AxisDirection.up;
      case 1:
        return AxisDirection.right;
      case 2:
        return AxisDirection.down;
      default:
        return AxisDirection.left;
    }
  }
}
