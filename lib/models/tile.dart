import 'package:flutter/material.dart';

import '../core/constants/game_rules.dart';

enum TileType {
  start,
  property, // il / arsa
  transport, // ulaşım hattı
  utility, // kamu kurumu
  chance, // Şans
  communityFund, // Kamu Fonu
  tax,
  jail, // Kodes (ziyaret)
  freeParking,
  goToJail,
}

/// Renk grubu (fiyat kademesi). Bir grubun tamamına sahip olan oyuncu
/// inşaat yapabilir. Gruplar haritaya göre üretilir (bkz. BoardLayout).
@immutable
class TileGroup {
  /// 0 = en ucuz kademe.
  final int id;
  final String label;
  final Color color;

  const TileGroup(this.id, this.label, this.color);

  @override
  bool operator ==(Object other) => other is TileGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Tahtadaki bir karenin DEĞİŞMEZ tanımı (fiyat, kira tablosu vb.).
/// Değişen durum (sahip, bina seviyesi, ipotek) [TileState]'te tutulur.
class Tile {
  final int index;
  final String name;
  final TileType type;
  final TileGroup? group;
  final bool isCorner;

  /// İl kareleri için plaka kodu ve bölge adı.
  final int? plate;
  final String? region;

  final int price;

  /// property: [arsa, 1 ev, 2 ev, 3 ev, 4 ev, gökdelen]
  /// transport: [1 hat, 2 hat, ...]
  /// utility: zar çarpanları [1 kurum, 2 kurum, ...]
  final List<int> rents;
  final int houseCost;
  final int taxAmount;

  const Tile({
    required this.index,
    required this.name,
    required this.type,
    this.group,
    this.isCorner = false,
    this.plate,
    this.region,
    this.price = 0,
    this.rents = const [],
    this.houseCost = 0,
    this.taxAmount = 0,
  });

  bool get isBuyable =>
      type == TileType.property ||
      type == TileType.transport ||
      type == TileType.utility;

  bool get isBuildable => type == TileType.property;

  int get mortgageValue => price ~/ 2;

  int get unmortgageCost =>
      (mortgageValue * (1 + GameRules.mortgageInterest)).ceil();

  /// Bina satışında banka yarı fiyat öder.
  int get houseSellValue => houseCost ~/ 2;
}
