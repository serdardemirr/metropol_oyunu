import 'package:flutter/material.dart';

/// Basit 2D zar yüzü. (3D dönen zar animasyonu Adım 3'te eklenecek.)
class DiceFace extends StatelessWidget {
  const DiceFace({super.key, required this.value, this.size = 56});

  final int value; // 1-6, 0 = boş
  final double size;

  // 3x3 ızgarada hangi noktaların dolu olduğu (0-8).
  static const Map<int, List<int>> _pips = {
    0: [],
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _pips[value] ?? const <int>[];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(2, 3)),
        ],
      ),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (var i = 0; i < 9; i++)
            Center(
              child: pips.contains(i)
                  ? Container(
                      width: size * 0.16,
                      height: size * 0.16,
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
