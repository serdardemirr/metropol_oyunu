import 'game_speed.dart';
import 'game_state.dart';
import 'order_duel.dart';
import 'player.dart';

enum RoomStatus {
  /// Bekleme odası — oyuncular katılıyor.
  waiting,

  /// Zar düellosu ile sıra belirleniyor.
  orderDuel,

  /// Oyun sürüyor.
  playing,

  /// Oyun bitti.
  finished,
}

/// Firestore'daki `rooms/{code}` dokümanı.
///
/// Tüm oda durumu TEK dokümanda tutulur. Böylece her hamle tek bir
/// transaction ile atomik olarak yazılır ve tüm telefonlar aynı anda
/// tek bir snapshot ile güncellenir.
class Room {
  final String code;
  final String hostId;
  final RoomStatus status;
  final Map<String, Player> players;
  final int createdAtMs;
  final int updatedAtMs;
  final OrderDuel? orderDuel;
  final GameState? game;

  /// Kurucunun seçtiği oyun hızı / süre modu.
  final GameSettings settings;

  const Room({
    required this.code,
    required this.hostId,
    required this.status,
    required this.players,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.orderDuel,
    this.game,
    this.settings = const GameSettings(),
  });

  /// Oyuncular katılma sırasına göre.
  List<Player> get playersByJoinOrder =>
      players.values.toList()..sort((a, b) => a.joinedAtMs.compareTo(b.joinedAtMs));

  /// Oyun başladıysa oyun sırasına göre, değilse katılma sırasına göre.
  List<Player> get playersInTurnOrder {
    final order = game?.turnOrder;
    if (order == null) return playersByJoinOrder;
    return [
      for (final id in order)
        if (players[id] != null) players[id]!,
    ];
  }

  Player? player(String id) => players[id];
  bool isHost(String uid) => hostId == uid;

  Room copyWith({
    String? hostId,
    RoomStatus? status,
    Map<String, Player>? players,
    int? updatedAtMs,
    OrderDuel? orderDuel,
    bool clearOrderDuel = false,
    GameState? game,
    bool clearGame = false,
    GameSettings? settings,
  }) {
    return Room(
      code: code,
      createdAtMs: createdAtMs,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      players: players ?? this.players,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      orderDuel: clearOrderDuel ? null : (orderDuel ?? this.orderDuel),
      game: clearGame ? null : (game ?? this.game),
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'hostId': hostId,
        'status': status.name,
        'players': {for (final e in players.entries) e.key: e.value.toMap()},
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'orderDuel': orderDuel?.toMap(),
        'game': game?.toMap(),
        'settings': settings.toMap(),
      };

  factory Room.fromMap(Map<String, dynamic> map) {
    final rawPlayers = Map<String, dynamic>.from(map['players'] as Map? ?? {});
    final rawDuel = map['orderDuel'];
    final rawGame = map['game'];
    return Room(
      code: map['code'] as String,
      hostId: map['hostId'] as String,
      status: RoomStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => RoomStatus.waiting,
      ),
      players: {
        for (final e in rawPlayers.entries)
          e.key: Player.fromMap(Map<String, dynamic>.from(e.value as Map)),
      },
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (map['updatedAtMs'] as num?)?.toInt() ?? 0,
      orderDuel: rawDuel == null
          ? null
          : OrderDuel.fromMap(Map<String, dynamic>.from(rawDuel as Map)),
      game: rawGame == null
          ? null
          : GameState.fromMap(Map<String, dynamic>.from(rawGame as Map)),
      settings: GameSettings.fromMap(map['settings']),
    );
  }
}
