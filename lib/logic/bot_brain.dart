import '../core/constants/game_rules.dart';
import '../models/models.dart';
import 'game_engine.dart';

/// Botun yapabileceği hamle türleri.
enum BotMoveKind {
  orderRoll,
  roll,
  buy,
  decline,
  acknowledgeCard,
  build,
  unmortgage,
  sell,
  mortgage,
  payBail,
  useJailCard,
  endTurn,
  bankrupt,
  bid,
  acceptOffer,
  rejectOffer,
}

/// Botun bir sonraki hamlesi. [BotDriver] bunu kısa bir gecikmeyle uygular.
class BotMove {
  const BotMove(this.botId, this.kind, {this.tile, this.amount, this.offerId});

  final String botId;
  final BotMoveKind kind;
  final int? tile;
  final int? amount;
  final String? offerId;

  /// Başarısız olan hamleyi tekrar denememek için kullanılan anahtar.
  String get key =>
      '$botId:${kind.name}:${tile ?? ''}:${amount ?? ''}:${offerId ?? ''}';

  @override
  String toString() => 'BotMove($key)';
}

/// Botların karar mantığı. Saf fonksiyon: Firebase'e dokunmaz, test edilebilir.
///
/// Basit ve tutarlı bir strateji izler:
/// * Elinde maaş kadar nakit kalacaksa il alır ve bina diker.
/// * Kodeste çıkış kartı varsa kullanır, parası bolsa kefalet öder.
/// * Borçta önce bina satar, sonra ipotek eder, çare kalmazsa iflas eder.
/// * Müzayedede tapu fiyatına kadar artırır.
/// * Takas teklifini ancak aldığı değer verdiğinden belirgin fazlaysa kabul eder.
class BotBrain {
  BotBrain._();

  /// Odadaki herhangi bir botun şu an yapması gereken hamleyi döner.
  /// Bot beklemekteyse `null` döner. [skip] içindeki anahtarlar (daha önce
  /// başarısız olmuş hamleler) atlanır ve bir sonraki güvenli seçenek seçilir.
  static BotMove? decide(Room room, {Set<String> skip = const {}}) {
    if (room.status == RoomStatus.orderDuel) {
      final roller = room.orderDuel?.currentRollerId;
      if (roller != null && _isBot(room, roller)) {
        return _first([BotMove(roller, BotMoveKind.orderRoll)], skip);
      }
      return null;
    }

    final game = room.game;
    if (room.status != RoomStatus.playing ||
        game == null ||
        game.phase == TurnPhase.gameOver) {
      return null;
    }

    // 1) Botlara gelen takas teklifleri.
    for (final offer in game.offers) {
      if (!_isAliveBot(room, offer.toId)) continue;
      final move = _first([
        if (_wantsOffer(room, offer))
          BotMove(offer.toId, BotMoveKind.acceptOffer, offerId: offer.id),
        BotMove(offer.toId, BotMoveKind.rejectOffer, offerId: offer.id),
      ], skip);
      if (move != null) return move;
    }

    // 2) Müzayede sürerken başka hamle yapılamaz; sadece teklif verilir.
    final auction = game.auction;
    if (auction != null) {
      for (final p in room.playersInTurnOrder) {
        if (!p.isBot || p.isBankrupt) continue;
        final amount = _bidFor(game, p, auction);
        if (amount == null) continue;
        final move =
            _first([BotMove(p.id, BotMoveKind.bid, amount: amount)], skip);
        if (move != null) return move;
      }
      return null;
    }

    // 3) Borçlu botlar (sırası gelmese de) borcunu kapatır.
    for (final p in room.playersInTurnOrder) {
      if (!p.isBot || p.isBankrupt || p.money >= 0) continue;
      final move = _first(_debtMoves(room, p), skip);
      if (move != null) return move;
    }

    // 4) Sıra bottaysa.
    final current = room.players[game.currentPlayerId];
    if (current == null || !current.isBot || current.isBankrupt) return null;
    return _first(_turnMoves(room, current), skip);
  }

  /// Botun nakitte tutmak istediği güvenlik payı (bir maaş kadar).
  static int reserveFor(GameState game) => game.speed.salary;

  // ─────────────────────────────────────────────────────────────────

  static List<BotMove> _turnMoves(Room room, Player me) {
    final game = room.game!;
    final reserve = reserveFor(game);
    final id = me.id;
    switch (game.phase) {
      case TurnPhase.awaitingRoll:
        return [
          if (me.inJail && me.jailCardIds.isNotEmpty)
            BotMove(id, BotMoveKind.useJailCard),
          if (me.inJail &&
              me.jailCardIds.isEmpty &&
              me.money - GameRules.jailBail >= reserve * 2)
            BotMove(id, BotMoveKind.payBail),
          BotMove(id, BotMoveKind.roll),
        ];
      case TurnPhase.awaitingBuyDecision:
        final tile = game.board.tile(me.position);
        return [
          if (me.money - tile.price >= reserve) BotMove(id, BotMoveKind.buy),
          BotMove(id, BotMoveKind.decline),
        ];
      case TurnPhase.showingCard:
        return [BotMove(id, BotMoveKind.acknowledgeCard)];
      case TurnPhase.awaitingDebtResolution:
        return _debtMoves(room, me);
      case TurnPhase.awaitingEndTurn:
        return [
          ..._buildMoves(room, me),
          ..._unmortgageMoves(room, me),
          BotMove(id, BotMoveKind.endTurn),
        ];
      case TurnPhase.gameOver:
        return const [];
    }
  }

  /// Borç kapatma sırası: binaları sat → ipotek et → iflas.
  static List<BotMove> _debtMoves(Room room, Player me) {
    final game = room.game!;
    final owned = game.board.tiles
        .where((t) => game.tileState(t.index).ownerId == me.id)
        .toList();
    // En yüksek binadan başla (eşit dağılım kuralına da uyar).
    final sells = owned
        .where((t) => GameEngine.sellError(room, me.id, t.index) == null)
        .toList()
      ..sort((a, b) =>
          game.tileState(b.index).level.compareTo(game.tileState(a.index).level));
    // En ucuz tapuyu önce ipotek et.
    final mortgages = owned
        .where((t) => GameEngine.mortgageError(room, me.id, t.index) == null)
        .toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return [
      for (final t in sells) BotMove(me.id, BotMoveKind.sell, tile: t.index),
      for (final t in mortgages)
        BotMove(me.id, BotMoveKind.mortgage, tile: t.index),
      BotMove(me.id, BotMoveKind.bankrupt),
    ];
  }

  /// Parası yettiği ve güvenlik payı kaldığı sürece en düşük seviyeli
  /// ile bina diker (aynı seviyede pahalı il önce).
  static List<BotMove> _buildMoves(Room room, Player me) {
    final game = room.game!;
    final reserve = reserveFor(game);
    final options = game.board.tiles
        .where((t) =>
            t.isBuildable &&
            game.tileState(t.index).ownerId == me.id &&
            me.money - t.houseCost >= reserve &&
            GameEngine.buildError(room, me.id, t.index) == null)
        .toList()
      ..sort((a, b) {
        final byLevel = game
            .tileState(a.index)
            .level
            .compareTo(game.tileState(b.index).level);
        return byLevel != 0 ? byLevel : b.price.compareTo(a.price);
      });
    return [
      for (final t in options) BotMove(me.id, BotMoveKind.build, tile: t.index),
    ];
  }

  /// Parası çok bolsa ipotekleri kurtarır.
  static List<BotMove> _unmortgageMoves(Room room, Player me) {
    final game = room.game!;
    final reserve = reserveFor(game);
    return [
      for (final t in game.board.tiles)
        if (game.tileState(t.index).ownerId == me.id &&
            game.tileState(t.index).mortgaged &&
            me.money - t.unmortgageCost >= reserve * 2 &&
            GameEngine.unmortgageError(room, me.id, t.index) == null)
          BotMove(me.id, BotMoveKind.unmortgage, tile: t.index),
    ];
  }

  /// Müzayedede verilecek teklif; vermeyecekse `null`.
  /// Tapu fiyatını aşmaz, güvenlik payını korur, 50M adımlarla artırır.
  static int? _bidFor(GameState game, Player me, Auction a) {
    if (a.sellerId == me.id || a.highestBidderId == me.id) return null;
    final price = game.board.tile(a.tileIndex).price;
    final minBid = a.minimumBid;
    if (minBid > price) return null;
    var amount = a.highestBid == null
        ? minBid
        : a.highestBid! + GameRules.auctionQuickBids.first;
    if (amount > price) amount = price;
    if (amount < minBid) amount = minBid;
    if (me.money - amount < reserveFor(game)) return null;
    return amount;
  }

  /// Teklif bota belirgin kâr sağlıyorsa (en az %25 fazla değer) kabul eder.
  static bool _wantsOffer(Room room, TradeOffer o) {
    if (GameEngine.offerError(room, o) != null) return false;
    final game = room.game!;
    final me = room.players[o.toId]!;
    final given = o.requestedTiles.fold<int>(0, (s, i) => s + tileValue(game, i)) +
        (o.cash < 0 ? -o.cash : 0);
    final received =
        o.offeredTiles.fold<int>(0, (s, i) => s + tileValue(game, i)) +
            (o.cash > 0 ? o.cash : 0);
    if (o.cash < 0 && me.money + o.cash < reserveFor(game)) return false;
    if (received <= 0) return false;
    return received * 4 >= given * 5; // received ≥ given × 1.25
  }

  /// Botun bir tapuya biçtiği değer.
  static int tileValue(GameState game, int index) {
    final tile = game.board.tile(index);
    final ts = game.tileState(index);
    if (ts.mortgaged) return tile.price - tile.mortgageValue;
    return tile.price + ts.level * tile.houseCost;
  }

  // ─────────────────────────────────────────────────────────────────

  static bool _isBot(Room room, String id) => room.players[id]?.isBot ?? false;

  static bool _isAliveBot(Room room, String id) {
    final p = room.players[id];
    return p != null && p.isBot && !p.isBankrupt;
  }

  static BotMove? _first(List<BotMove> moves, Set<String> skip) {
    for (final m in moves) {
      if (!skip.contains(m.key)) return m;
    }
    return null;
  }
}
