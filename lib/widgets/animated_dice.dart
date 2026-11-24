import 'dart:math';

import 'package:flutter/material.dart';

import 'dice_face.dart';

/// 3D hissi veren, havada dönen zar çifti.
/// [rollKey] her değiştiğinde (yeni atış) animasyon baştan oynar ve
/// sonunda [die1]/[die2] değerlerinde durur.
class AnimatedDicePair extends StatefulWidget {
  const AnimatedDicePair({
    super.key,
    required this.die1,
    required this.die2,
    required this.rollKey,
    this.size = 64,
  });

  final int die1;
  final int die2;
  final int rollKey;
  final double size;

  @override
  State<AnimatedDicePair> createState() => _AnimatedDicePairState();
}

class _AnimatedDicePairState extends State<AnimatedDicePair>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(_tick);
  final _rnd = Random();
  int _f1 = 1, _f2 = 1;
  int _lastSwap = 0;

  @override
  void initState() {
    super.initState();
    _f1 = _face(widget.die1);
    _f2 = _face(widget.die2);
  }

  @override
  void didUpdateWidget(covariant AnimatedDicePair old) {
    super.didUpdateWidget(old);
    if (widget.rollKey != old.rollKey) {
      _c.forward(from: 0);
    } else if (!_c.isAnimating) {
      _f1 = _face(widget.die1);
      _f2 = _face(widget.die2);
    }
  }

  static int _face(int v) => v < 1 ? 1 : (v > 6 ? 6 : v);

  void _tick() {
    // Dönerken yüzleri değiştir; son %20'de gerçek sonuca otur.
    if (_c.value > 0.8) {
      _f1 = _face(widget.die1);
      _f2 = _face(widget.die2);
      return;
    }
    final step = (_c.value * 12).floor();
    if (step != _lastSwap) {
      _lastSwap = step;
      _f1 = _rnd.nextInt(6) + 1;
      _f2 = _rnd.nextInt(6) + 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _die(int face, double phase) {
    final t = Curves.easeOutCubic.transform(_c.value);
    final spin = (1 - t) * pi * 4;
    final hop = sin(t * pi) * -widget.size * 0.6; // havaya zıplama
    return Transform.translate(
      offset: Offset(0, _c.isAnimating ? hop : 0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0025) // perspektif
          ..rotateX(spin + phase)
          ..rotateY(spin * 0.7 - phase)
          ..rotateZ(spin * 0.3),
        child: DiceFace(value: face, size: widget.size),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _die(_f1, 0),
          SizedBox(width: widget.size * 0.35),
          _die(_f2, 0.6 * (1 - _c.value)),
        ],
      ),
    );
  }
}
