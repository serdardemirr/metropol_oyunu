import '../core/constants/game_rules.dart';
import 'pawn_token.dart';

/// Bir oyuncunun odadaki/oyundaki anlık durumu.
/// Firestore'da `rooms/{code}.players.{id}` altında saklanır.
/// Arsa sahiplikleri burada değil, [GameState.tiles] içinde tutulur
/// (tek gerçek kaynak — çift kayıt tutarsızlığı olmasın diye).
class Player {
  final String id; // Firebase Auth uid (botlarda 'bot_...')
  final String name;
  final PawnToken pawn;
  final bool isHost;
  final int joinedAtMs;

  /// Bilgisayar oyuncusu mu? Botların hamlelerini kurucunun telefonu yapar
  /// (bkz. BotDriver). Botların Firebase hesabı ve bağlantı durumu yoktur.
  final bool isBot;

  // Oyun içi alanlar
  final int money;
  final int position;
  final bool inJail;
  final int jailTurns; // kodeste geçirilen tur sayısı
  /// Elinde tuttuğu "Kodesten Çıkış" kartlarının id'leri.
  final List<int> jailCardIds;
  final bool isBankrupt;

  const Player({
    required this.id,
    required this.name,
    required this.pawn,
    required this.joinedAtMs,
    this.isHost = false,
    this.isBot = false,
    this.money = GameRules.startingMoney,
    this.position = 0,
    this.inJail = false,
    this.jailTurns = 0,
    this.jailCardIds = const [],
    this.isBankrupt = false,
  });

  int get jailFreeCards => jailCardIds.length;

  Player copyWith({
    String? name,
    PawnToken? pawn,
    bool? isHost,
    int? money,
    int? position,
    bool? inJail,
    int? jailTurns,
    List<int>? jailCardIds,
    bool? isBankrupt,
  }) {
    return Player(
      id: id,
      joinedAtMs: joinedAtMs,
      isBot: isBot,
      name: name ?? this.name,
      pawn: pawn ?? this.pawn,
      isHost: isHost ?? this.isHost,
      money: money ?? this.money,
      position: position ?? this.position,
      inJail: inJail ?? this.inJail,
      jailTurns: jailTurns ?? this.jailTurns,
      jailCardIds: jailCardIds ?? this.jailCardIds,
      isBankrupt: isBankrupt ?? this.isBankrupt,
    );
  }

  /// Oyun başlarken oyuncuyu başlangıç değerlerine sıfırlar.
  /// Başlangıç parası haritaya göre değişir (bkz. BoardLayout).
  Player resetForNewGame([int startingMoney = GameRules.startingMoney]) =>
      copyWith(
        money: startingMoney,
        position: 0,
        inJail: false,
        jailTurns: 0,
        jailCardIds: const [],
        isBankrupt: false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'pawn': pawn.toMap(),
        'isHost': isHost,
        'joinedAtMs': joinedAtMs,
        'isBot': isBot,
        'money': money,
        'position': position,
        'inJail': inJail,
        'jailTurns': jailTurns,
        'jailCardIds': jailCardIds,
        'isBankrupt': isBankrupt,
      };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Oyuncu',
        pawn: PawnToken.fromMap(map['pawn']),
        isHost: map['isHost'] as bool? ?? false,
        joinedAtMs: (map['joinedAtMs'] as num?)?.toInt() ?? 0,
        isBot: map['isBot'] as bool? ?? false,
        money: (map['money'] as num?)?.toInt() ?? GameRules.startingMoney,
        position: (map['position'] as num?)?.toInt() ?? 0,
        inJail: map['inJail'] as bool? ?? false,
        jailTurns: (map['jailTurns'] as num?)?.toInt() ?? 0,
        jailCardIds: [
          for (final v in (map['jailCardIds'] as List? ?? const []))
            (v as num).toInt()
        ],
        isBankrupt: map['isBankrupt'] as bool? ?? false,
      );
}
