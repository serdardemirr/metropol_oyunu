import '../core/constants/game_rules.dart';

/// Satın alınabilir bir karenin oyun içindeki DEĞİŞKEN durumu.
/// Firestore'da `game.tiles.{index}` altında saklanır; sahibi olmayan
/// kareler hiç yazılmaz (doküman küçük kalsın).
class TileState {
  final int index;
  final String? ownerId;

  /// 0 = boş arsa, 1-4 = ev, 5 = gökdelen
  final int level;
  final bool mortgaged;

  const TileState({
    required this.index,
    this.ownerId,
    this.level = 0,
    this.mortgaged = false,
  }) : assert(level >= 0 && level <= GameRules.maxBuildingLevel);

  bool get isOwned => ownerId != null;
  bool get hasSkyscraper => level == GameRules.skyscraperLevel;
  int get houseCount => hasSkyscraper ? 0 : level;

  TileState copyWith({
    String? ownerId,
    bool clearOwner = false,
    int? level,
    bool? mortgaged,
  }) {
    return TileState(
      index: index,
      ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
      level: level ?? this.level,
      mortgaged: mortgaged ?? this.mortgaged,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'level': level,
        'mortgaged': mortgaged,
      };

  factory TileState.fromMap(int index, Map<String, dynamic> map) => TileState(
        index: index,
        ownerId: map['ownerId'] as String?,
        level: (map['level'] as num?)?.toInt() ?? 0,
        mortgaged: map['mortgaged'] as bool? ?? false,
      );
}
