import '../core/constants/game_rules.dart';
import '../core/utils/dice.dart';
import '../data/board_layout.dart';
import 'auction.dart';
import 'game_speed.dart';
import 'tile_state.dart';
import 'trade_offer.dart';

/// Sıradaki oyuncunun hangi aşamada olduğu.
enum TurnPhase {
  /// Zar atmayı bekliyor (kodesteyse kodes seçenekleri de sunulur).
  awaitingRoll,

  /// Boş bir arsaya geldi; Satın Al / Pas Geç kararı bekleniyor.
  awaitingBuyDecision,

  /// Şans/Kamu Fonu kartı gösteriliyor; onay bekleniyor.
  showingCard,

  /// Borç ödenemiyor; ipotek/satış ile para bulması ya da iflas etmesi gerekiyor.
  awaitingDebtResolution,

  /// Hamle bitti; inşaat/takas/ipotek yapabilir, ardından sırayı devreder.
  awaitingEndTurn,

  gameOver,
}

/// Günlük satırının türü. Tüm telefonlar aynı efekti (ses, animasyon)
/// bu türe bakarak oynatır.
enum LogKind {
  info,
  dice,
  move,
  money,
  buy,
  build,
  card,
  jail,
  bankrupt,
  win,
  auction,
  trade,
}

/// Oyun günlüğü satırı (ekrandaki akış ve "+200M" gibi efektler için).
class GameLogEntry {
  /// Oyun boyunca artan benzersiz sıra numarası. İstemciler hangi
  /// olayları daha önce oynattığını bununla takip eder.
  final int seq;
  final int atMs;
  final String text;
  final LogKind kind;
  final String? playerId;

  /// Bu olaydaki para değişimi (+/-). Uçuşan metin animasyonu için.
  final int? moneyDelta;

  /// İnşaat gibi bir kareye bağlı olaylarda kare numarası.
  final int? tileIndex;

  const GameLogEntry({
    required this.seq,
    required this.atMs,
    required this.text,
    this.kind = LogKind.info,
    this.playerId,
    this.moneyDelta,
    this.tileIndex,
  });

  Map<String, dynamic> toMap() => {
        'seq': seq,
        'atMs': atMs,
        'text': text,
        'kind': kind.name,
        'playerId': playerId,
        'moneyDelta': moneyDelta,
        'tileIndex': tileIndex,
      };

  factory GameLogEntry.fromMap(Map<String, dynamic> map) => GameLogEntry(
        seq: (map['seq'] as num?)?.toInt() ?? 0,
        atMs: (map['atMs'] as num?)?.toInt() ?? 0,
        text: map['text'] as String? ?? '',
        kind: LogKind.values.firstWhere(
          (k) => k.name == map['kind'],
          orElse: () => LogKind.info,
        ),
        playerId: map['playerId'] as String?,
        moneyDelta: (map['moneyDelta'] as num?)?.toInt(),
        tileIndex: (map['tileIndex'] as num?)?.toInt(),
      );
}

/// Oyun başladıktan sonraki tüm paylaşılan durum.
/// Firestore'da `rooms/{code}.game` alanında saklanır.
class GameState {
  /// Oyuncu sayısına (ya da maraton moduna) göre seçilen harita.
  final BoardSize boardSize;

  /// Oyun hızı: para, maaş, inşaat ve bitiş kuralları buna göre.
  final GameSpeed speed;

  /// Oyunun başladığı an ve (süre sınırı varsa) biteceği an — ms.
  final int startedAtMs;
  final int? endsAtMs;

  /// Oyun bittiyse nedeni.
  final GameEndReason? endReason;

  /// Zar düellosuyla belirlenen kesin oyun sırası (oyuncu id'leri).
  final List<String> turnOrder;
  final int currentTurnIndex;
  final TurnPhase phase;
  final int turnNumber;

  /// Sadece sahibi olan kareler: index -> durum.
  final Map<int, TileState> tiles;

  final DiceRoll? lastDice;
  final int doublesInRow;

  /// Karıştırılmış deste sırası (kart id'leri) ve sıradaki kartın konumu.
  final List<int> chanceDeck;
  final int chanceCursor;
  final List<int> fundDeck;
  final int fundCursor;

  /// Ekranda gösterilen son çekilen kart.
  final int? activeCardId;

  final List<GameLogEntry> log;

  /// Son verilen günlük sıra numarası.
  final int eventSeq;
  final String? winnerId;

  /// Süren açık artırma (aynı anda en fazla bir tane).
  final Auction? auction;

  /// Bekleyen oyuncular arası teklifler.
  final List<TradeOffer> offers;

  const GameState({
    required this.turnOrder,
    this.boardSize = BoardSize.standard,
    this.speed = GameSpeed.normal,
    this.startedAtMs = 0,
    this.endsAtMs,
    this.endReason,
    required this.chanceDeck,
    required this.fundDeck,
    this.currentTurnIndex = 0,
    this.phase = TurnPhase.awaitingRoll,
    this.turnNumber = 1,
    this.tiles = const {},
    this.lastDice,
    this.doublesInRow = 0,
    this.chanceCursor = 0,
    this.fundCursor = 0,
    this.activeCardId,
    this.log = const [],
    this.eventSeq = 0,
    this.winnerId,
    this.auction,
    this.offers = const [],
  });

  BoardLayout get board => BoardLayout.of(boardSize);

  /// Başlangıç'tan geçince alınan maaş.
  int get salary => speed.salary;

  String get currentPlayerId => turnOrder[currentTurnIndex];

  TileState tileState(int index) => tiles[index] ?? TileState(index: index);

  List<TileState> tilesOwnedBy(String playerId) =>
      tiles.values.where((t) => t.ownerId == playerId).toList();

  GameState copyWith({
    List<String>? turnOrder,
    int? currentTurnIndex,
    TurnPhase? phase,
    int? turnNumber,
    Map<int, TileState>? tiles,
    DiceRoll? lastDice,
    int? doublesInRow,
    List<int>? chanceDeck,
    int? chanceCursor,
    List<int>? fundDeck,
    int? fundCursor,
    int? activeCardId,
    bool clearActiveCard = false,
    List<GameLogEntry>? log,
    int? eventSeq,
    String? winnerId,
    Auction? auction,
    bool clearAuction = false,
    List<TradeOffer>? offers,
    GameEndReason? endReason,
  }) {
    return GameState(
      boardSize: boardSize,
      speed: speed,
      startedAtMs: startedAtMs,
      endsAtMs: endsAtMs,
      endReason: endReason ?? this.endReason,
      turnOrder: turnOrder ?? this.turnOrder,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      phase: phase ?? this.phase,
      turnNumber: turnNumber ?? this.turnNumber,
      tiles: tiles ?? this.tiles,
      lastDice: lastDice ?? this.lastDice,
      doublesInRow: doublesInRow ?? this.doublesInRow,
      chanceDeck: chanceDeck ?? this.chanceDeck,
      chanceCursor: chanceCursor ?? this.chanceCursor,
      fundDeck: fundDeck ?? this.fundDeck,
      fundCursor: fundCursor ?? this.fundCursor,
      activeCardId:
          clearActiveCard ? null : (activeCardId ?? this.activeCardId),
      log: log ?? this.log,
      eventSeq: eventSeq ?? this.eventSeq,
      winnerId: winnerId ?? this.winnerId,
      auction: clearAuction ? null : (auction ?? this.auction),
      offers: offers ?? this.offers,
    );
  }

  /// Günlüğe satır ekler; en fazla [GameRules.maxLogEntries] satır tutar.
  GameState addLog(
    String text, {
    LogKind kind = LogKind.info,
    String? playerId,
    int? moneyDelta,
    int? tileIndex,
  }) {
    final seq = eventSeq + 1;
    final entry = GameLogEntry(
      seq: seq,
      atMs: DateTime.now().millisecondsSinceEpoch,
      text: text,
      kind: kind,
      playerId: playerId,
      moneyDelta: moneyDelta,
      tileIndex: tileIndex,
    );
    final newLog = [...log, entry];
    final overflow = newLog.length - GameRules.maxLogEntries;
    return copyWith(
      log: overflow > 0 ? newLog.sublist(overflow) : newLog,
      eventSeq: seq,
    );
  }

  Map<String, dynamic> toMap() => {
        'boardSize': boardSize.name,
        'speed': speed.name,
        'startedAtMs': startedAtMs,
        'endsAtMs': endsAtMs,
        'endReason': endReason?.name,
        'turnOrder': turnOrder,
        'currentTurnIndex': currentTurnIndex,
        'phase': phase.name,
        'turnNumber': turnNumber,
        // Firestore map anahtarları string olmalı.
        'tiles': {
          for (final e in tiles.entries) e.key.toString(): e.value.toMap()
        },
        'lastDice': lastDice?.toMap(),
        'doublesInRow': doublesInRow,
        'chanceDeck': chanceDeck,
        'chanceCursor': chanceCursor,
        'fundDeck': fundDeck,
        'fundCursor': fundCursor,
        'activeCardId': activeCardId,
        'log': [for (final l in log) l.toMap()],
        'eventSeq': eventSeq,
        'winnerId': winnerId,
        'auction': auction?.toMap(),
        'offers': [for (final o in offers) o.toMap()],
      };

  factory GameState.fromMap(Map<String, dynamic> map) {
    final rawTiles = Map<String, dynamic>.from(map['tiles'] as Map? ?? {});
    final rawDice = map['lastDice'];
    final rawAuction = map['auction'];
    return GameState(
      boardSize: BoardSize.fromName(map['boardSize']),
      speed: GameSpeed.fromName(map['speed']),
      startedAtMs: (map['startedAtMs'] as num?)?.toInt() ?? 0,
      endsAtMs: (map['endsAtMs'] as num?)?.toInt(),
      endReason: GameEndReason.fromName(map['endReason']),
      turnOrder: List<String>.from(map['turnOrder'] as List? ?? const []),
      currentTurnIndex: (map['currentTurnIndex'] as num?)?.toInt() ?? 0,
      phase: TurnPhase.values.firstWhere(
        (p) => p.name == map['phase'],
        orElse: () => TurnPhase.awaitingRoll,
      ),
      turnNumber: (map['turnNumber'] as num?)?.toInt() ?? 1,
      tiles: {
        for (final e in rawTiles.entries)
          int.parse(e.key): TileState.fromMap(
            int.parse(e.key),
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
      lastDice: rawDice == null
          ? null
          : DiceRoll.fromMap(Map<String, dynamic>.from(rawDice as Map)),
      doublesInRow: (map['doublesInRow'] as num?)?.toInt() ?? 0,
      chanceDeck: _intList(map['chanceDeck']),
      chanceCursor: (map['chanceCursor'] as num?)?.toInt() ?? 0,
      fundDeck: _intList(map['fundDeck']),
      fundCursor: (map['fundCursor'] as num?)?.toInt() ?? 0,
      activeCardId: (map['activeCardId'] as num?)?.toInt(),
      log: [
        for (final l in (map['log'] as List? ?? const []))
          GameLogEntry.fromMap(Map<String, dynamic>.from(l as Map)),
      ],
      eventSeq: (map['eventSeq'] as num?)?.toInt() ?? 0,
      winnerId: map['winnerId'] as String?,
      auction: rawAuction == null
          ? null
          : Auction.fromMap(Map<String, dynamic>.from(rawAuction as Map)),
      offers: [
        for (final o in (map['offers'] as List? ?? const []))
          TradeOffer.fromMap(Map<String, dynamic>.from(o as Map)),
      ],
    );
  }

  static List<int> _intList(Object? raw) =>
      [for (final v in (raw as List? ?? const [])) (v as num).toInt()];
}
