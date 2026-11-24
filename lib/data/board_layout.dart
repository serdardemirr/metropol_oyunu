import 'dart:math';

import 'package:flutter/material.dart';

import '../models/tile.dart';
import 'cities_data.dart';

/// Harita boyutu — odadaki oyuncu sayısına göre otomatik seçilir.
enum BoardSize {
  compact('Kompakt Harita', '2-3 oyuncu · 16 il · hızlı tempo'),
  standard('Standart Harita', '4-5 oyuncu · 7 bölgeden 25 il'),
  giant('Dev Türkiye Haritası', '6+ oyuncu · 81 ilin tamamı · maraton');

  const BoardSize(this.label, this.description);
  final String label;
  final String description;

  static BoardSize forPlayerCount(int players) {
    if (players <= 3) return BoardSize.compact;
    if (players <= 5) return BoardSize.standard;
    return BoardSize.giant;
  }

  static BoardSize fromName(Object? name) => BoardSize.values.firstWhere(
        (b) => b.name == name,
        orElse: () => BoardSize.standard,
      );
}

/// Bir haritanın tasarım parametreleri.
class _Spec {
  final int tiles;
  final List<City> cities;
  final List<int> groupSizes;
  final int transports, utilities, chances, funds, taxes;
  final List<int> transportRents;
  final List<int> utilityMultipliers;

  const _Spec({
    required this.tiles,
    required this.cities,
    required this.groupSizes,
    required this.transports,
    required this.utilities,
    required this.chances,
    required this.funds,
    required this.taxes,
    required this.transportRents,
    required this.utilityMultipliers,
  });
}

/// Üretilmiş bir oyun tahtası: kareler, renk grupları, ekonomi.
///
/// Kare dizilimi bir şablondan matematiksel olarak üretilir:
///  * Köşeler: 0 Başlangıç · N/4 Kodes · N/2 Ücretsiz Otopark · 3N/4 Kodese Git
///  * Ulaşım hatları tahtaya eşit aralıklarla, diğer özel kareler kalan
///    boşluklara eşit aralıklarla yerleştirilir.
///  * Kalan karelere iller UCUZDAN PAHALIYA sırayla dizilir ve ardışık
///    iller renk gruplarına bölünür.
///  * Fiyat, kira ve inşaat maliyeti grubun kademesine göre bir formülle
///    hesaplanır (bkz. [_basePrice], [_rentsFor], [_houseCost]).
class BoardLayout {
  BoardLayout._(this.size, this.tiles, this.groups);

  final BoardSize size;
  final List<Tile> tiles;
  final List<TileGroup> groups;

  int get length => tiles.length;
  int get tilesPerSide => length ~/ 4; // köşe dahil
  int get startIndex => 0;
  int get jailIndex => length ~/ 4;
  int get freeParkingIndex => length ~/ 2;
  int get goToJailIndex => length * 3 ~/ 4;

  Tile tile(int index) => tiles[index % length];

  List<Tile> tilesInGroup(TileGroup group) =>
      tiles.where((t) => t.group == group).toList();

  /// [from] konumundan ileri doğru en yakın [type] karesi.
  int nearestForward(int from, TileType type) {
    for (var step = 1; step <= length; step++) {
      final i = (from + step) % length;
      if (tiles[i].type == type) return i;
    }
    return from;
  }

  int? indexOfCity(String name) {
    for (final t in tiles) {
      if (t.name == name) return t.index;
    }
    return null;
  }

  // ───────────────────────── Önbellek ─────────────────────────

  static final Map<BoardSize, BoardLayout> _cache = {};

  static BoardLayout of(BoardSize size) =>
      _cache.putIfAbsent(size, () => _generate(size, _specs[size]!));

  static final Map<BoardSize, _Spec> _specs = {
    BoardSize.compact: _Spec(
      tiles: 28,
      cities: CitiesData.compact,
      groupSizes: const [2, 3, 3, 3, 3, 2],
      transports: 2,
      utilities: 1,
      chances: 2,
      funds: 2,
      taxes: 1,
      transportRents: const [50, 150],
      utilityMultipliers: const [6],
    ),
    BoardSize.standard: _Spec(
      tiles: 44,
      cities: CitiesData.standard,
      groupSizes: const [2, 3, 3, 3, 3, 3, 3, 3, 2],
      transports: 4,
      utilities: 3,
      chances: 3,
      funds: 3,
      taxes: 2,
      transportRents: const [25, 50, 100, 200],
      utilityMultipliers: const [4, 10, 20],
    ),
    BoardSize.giant: _Spec(
      tiles: 108,
      cities: CitiesData.all,
      groupSizes: [2, for (var i = 0; i < 19; i++) 4, 3],
      transports: 6,
      utilities: 3,
      chances: 5,
      funds: 5,
      taxes: 4,
      transportRents: const [25, 50, 100, 175, 250, 350],
      utilityMultipliers: const [4, 10, 20],
    ),
  };

  static const _transportNames = [
    'Haydarpaşa Garı',
    'Kabataş İskelesi',
    'Ankara YHT Garı',
    'İstanbul Havalimanı',
    'İzmir Limanı',
    'Sirkeci Garı',
  ];
  static const _utilityNames = [
    'Elektrik İdaresi',
    'Su İdaresi',
    'Doğalgaz İdaresi',
  ];
  static const _taxes = [
    ('Gelir Vergisi', 200),
    ('Lüks Vergisi', 150),
    ('Emlak Vergisi', 200),
    ('ÖTV', 150),
  ];

  /// Klasik renk sırası (ucuz → pahalı); grup sayısı farklıysa ara renkler
  /// doğrusal olarak türetilir.
  static const _palette = [
    Color(0xFF795548), // kahverengi
    Color(0xFF81D4FA), // açık mavi
    Color(0xFFF06292), // pembe
    Color(0xFFFF9800), // turuncu
    Color(0xFFE53935), // kırmızı
    Color(0xFFFFEB3B), // sarı
    Color(0xFF43A047), // yeşil
    Color(0xFF7E57C2), // mor
    Color(0xFF1A237E), // lacivert
  ];

  static Color _groupColor(int g, int groupCount) {
    if (groupCount <= 1) return _palette.first;
    final pos = g / (groupCount - 1) * (_palette.length - 1);
    final i = min(max(pos.floor(), 0), _palette.length - 2);
    return Color.lerp(_palette[i], _palette[i + 1], pos - i)!;
  }

  // ───────────────────────── Ekonomi formülleri ─────────────────────────

  static int _round(num v, int step) => max(step, (v / step).round() * step);

  /// Kademe [t] (0 = en ucuz, 1 = en pahalı) için baz arsa fiyatı: 60M → 400M.
  static int _basePrice(double t) => _round(60 + 340 * pow(t, 1.15), 10);

  /// Grubun son ili (klasik oyundaki gibi) biraz daha pahalıdır; ama prim,
  /// bir sonraki kademenin fiyatını asla geçmez (en fazla aradaki farkın yarısı).
  static int _lastInGroupBonus(int g, int groupCount) {
    if (g == groupCount - 1) return 20;
    final gap = _basePrice((g + 1) / (groupCount - 1)) -
        _basePrice(g / (groupCount - 1));
    return min(20, (gap ~/ 2) ~/ 10 * 10);
  }

  /// Kira = fiyat × seviye çarpanı. Her seviye kirayı katlayarak artırır.
  static const _rentMultipliers = [0.08, 0.4, 1.15, 2.9, 3.7, 4.5];

  static List<int> _rentsFor(int price) => [
        for (final m in _rentMultipliers)
          price * m < 10 ? max(2, (price * m).round()) : _round(price * m, 5),
      ];

  /// Ev/gökdelen maliyeti kademeyle 50M → 200M artar.
  static int _houseCost(double t) => _round(50 + 150 * t, 50);

  // ───────────────────────── Üretici ─────────────────────────

  static BoardLayout _generate(BoardSize size, _Spec spec) {
    final n = spec.tiles;
    assert(n % 4 == 0);
    final specialCount = spec.transports +
        spec.utilities +
        spec.chances +
        spec.funds +
        spec.taxes;
    assert(spec.cities.length + specialCount + 4 == n,
        '${size.name}: kare sayısı tutmuyor');
    assert(spec.groupSizes.fold<int>(0, (a, b) => a + b) ==
        spec.cities.length);

    final corners = {0, n ~/ 4, n ~/ 2, n * 3 ~/ 4};
    final slots = List<TileType?>.filled(n, null);
    slots[0] = TileType.start;
    slots[n ~/ 4] = TileType.jail;
    slots[n ~/ 2] = TileType.freeParking;
    slots[n * 3 ~/ 4] = TileType.goToJail;

    // 1) Ulaşım hatları: tahta boyunca eşit aralıklı (her kenarın ortası).
    for (var k = 0; k < spec.transports; k++) {
      var g = ((k + 0.5) * n / spec.transports).round() % n;
      while (corners.contains(g) || slots[g] != null) {
        g = (g + 1) % n;
      }
      slots[g] = TileType.transport;
    }

    // 2) Diğer özel kareler: tür tür sırayla, boş yerlere eşit aralıklı.
    final remaining = {
      TileType.communityFund: spec.funds,
      TileType.tax: spec.taxes,
      TileType.chance: spec.chances,
      TileType.utility: spec.utilities,
    };
    final specials = <TileType>[];
    while (remaining.values.any((v) => v > 0)) {
      for (final type in remaining.keys) {
        if (remaining[type]! > 0) {
          specials.add(type);
          remaining[type] = remaining[type]! - 1;
        }
      }
    }
    final free = [
      for (var i = 0; i < n; i++)
        if (slots[i] == null) i
    ];
    for (var j = 0; j < specials.length; j++) {
      slots[free[((j + 0.5) * free.length / specials.length).floor()]] =
          specials[j];
    }

    // 3) Renk grupları
    final groupCount = spec.groupSizes.length;
    final groups = [
      for (var g = 0; g < groupCount; g++)
        TileGroup(g, '${g + 1}. Kademe', _groupColor(g, groupCount)),
    ];
    final cityGroup = <int>[]; // il sırası → grup no
    final lastOfGroup = <bool>[];
    for (var g = 0; g < groupCount; g++) {
      for (var k = 0; k < spec.groupSizes[g]; k++) {
        cityGroup.add(g);
        lastOfGroup.add(k == spec.groupSizes[g] - 1);
      }
    }

    // 4) Kareleri oluştur
    final tiles = <Tile>[];
    var city = 0, transport = 0, utility = 0, tax = 0;
    for (var i = 0; i < n; i++) {
      final type = slots[i] ?? TileType.property;
      final isCorner = corners.contains(i);
      switch (type) {
        case TileType.property:
          final c = spec.cities[city];
          final g = cityGroup[city];
          final t = groupCount == 1 ? 0.0 : g / (groupCount - 1);
          final isLast = lastOfGroup[city] && spec.groupSizes[g] > 1;
          final price = _basePrice(t) +
              (isLast ? _lastInGroupBonus(g, groupCount) : 0);
          tiles.add(Tile(
            index: i,
            name: c.name,
            type: type,
            group: groups[g],
            plate: c.plate,
            region: c.region.label,
            price: price,
            rents: _rentsFor(price),
            houseCost: _houseCost(t),
          ));
          city++;
        case TileType.transport:
          tiles.add(Tile(
            index: i,
            name: _transportNames[transport++ % _transportNames.length],
            type: type,
            price: 200,
            rents: spec.transportRents,
          ));
        case TileType.utility:
          tiles.add(Tile(
            index: i,
            name: _utilityNames[utility++ % _utilityNames.length],
            type: type,
            price: 150,
            rents: spec.utilityMultipliers,
          ));
        case TileType.tax:
          final (name, amount) = _taxes[tax++ % _taxes.length];
          tiles.add(Tile(index: i, name: name, type: type, taxAmount: amount));
        case TileType.start:
          tiles.add(Tile(index: i, name: 'Başlangıç', type: type, isCorner: true));
        case TileType.jail:
          tiles.add(Tile(index: i, name: 'Kodes', type: type, isCorner: true));
        case TileType.freeParking:
          tiles.add(Tile(
              index: i, name: 'Ücretsiz Otopark', type: type, isCorner: true));
        case TileType.goToJail:
          tiles.add(
              Tile(index: i, name: 'Kodese Git', type: type, isCorner: true));
        case TileType.chance:
          tiles.add(Tile(index: i, name: 'Şans', type: type, isCorner: isCorner));
        case TileType.communityFund:
          tiles.add(Tile(
              index: i, name: 'Kamu Fonu', type: type, isCorner: isCorner));
      }
    }
    return BoardLayout._(
      size,
      List.unmodifiable(tiles),
      List.unmodifiable(groups),
    );
  }
}
