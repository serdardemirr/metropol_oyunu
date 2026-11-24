import 'package:flutter/material.dart';

/// Haritada oyuncuyu temsil eden sembol. Uzaktan bile ayırt edilebilsin diye
/// insan silüeti yerine belirgin nesneler kullanılır.
enum PawnSymbol {
  car('Araba'),
  plane('Uçak'),
  ship('Gemi'),
  rocket('Roket'),
  crown('Taç'),
  hat('Şapka'),
  diamond('Elmas'),
  anchor('Çapa');

  const PawnSymbol(this.label);
  final String label;

  static PawnSymbol fromName(Object? name) => PawnSymbol.values.firstWhere(
        (s) => s.name == name,
        orElse: () => PawnSymbol.car,
      );
}

/// Piyon rengi. Bir odada her renk ve her sembol tektir.
enum PawnColor {
  red('Kırmızı', Color(0xFFE53935)),
  blue('Mavi', Color(0xFF1E88E5)),
  green('Yeşil', Color(0xFF43A047)),
  yellow('Sarı', Color(0xFFFBC02D)),
  purple('Mor', Color(0xFF8E24AA)),
  orange('Turuncu', Color(0xFFFB8C00)),
  teal('Turkuaz', Color(0xFF00897B)),
  pink('Pembe', Color(0xFFD81B60));

  const PawnColor(this.label, this.color);
  final String label;
  final Color color;

  static PawnColor fromName(Object? name) => PawnColor.values.firstWhere(
        (c) => c.name == name,
        orElse: () => PawnColor.red,
      );
}

/// Sembol + renk çifti.
@immutable
class PawnToken {
  final PawnSymbol symbol;
  final PawnColor tint;

  const PawnToken(this.symbol, this.tint);

  static const PawnToken initial = PawnToken(PawnSymbol.car, PawnColor.red);

  Color get color => tint.color;
  String get label => '${tint.label} ${symbol.label}';

  PawnToken copyWith({PawnSymbol? symbol, PawnColor? tint}) =>
      PawnToken(symbol ?? this.symbol, tint ?? this.tint);

  Map<String, dynamic> toMap() => {'symbol': symbol.name, 'color': tint.name};

  factory PawnToken.fromMap(Object? raw) {
    if (raw is Map) {
      return PawnToken(
        PawnSymbol.fromName(raw['symbol']),
        PawnColor.fromName(raw['color']),
      );
    }
    return initial;
  }

  /// Odadaki diğer piyonlarla çakışmayan bir piyon döner: renk ya da sembol
  /// alınmışsa ilk boştakiyle değiştirir.
  PawnToken resolveAgainst(Iterable<PawnToken> taken) {
    final colors = taken.map((t) => t.tint).toSet();
    final symbols = taken.map((t) => t.symbol).toSet();
    return PawnToken(
      symbols.contains(symbol)
          ? PawnSymbol.values.firstWhere((s) => !symbols.contains(s),
              orElse: () => symbol)
          : symbol,
      colors.contains(tint)
          ? PawnColor.values.firstWhere((c) => !colors.contains(c),
              orElse: () => tint)
          : tint,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PawnToken && other.symbol == symbol && other.tint == tint;

  @override
  int get hashCode => Object.hash(symbol, tint);
}
