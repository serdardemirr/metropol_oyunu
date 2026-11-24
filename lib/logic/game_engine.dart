import 'dart:math';

import '../core/constants/game_rules.dart';
import '../core/errors.dart';
import '../core/utils/dice.dart';
import '../data/board_layout.dart';
import '../data/card_data.dart';
import '../models/models.dart';

/// Oyunun tüm kuralları — saf (pure) fonksiyonlar.
///
/// Her hamle bir [Room] alır ve yeni bir [Room] döner; Firebase'e hiç
/// dokunmaz. Böylece kurallar birim testleriyle doğrulanabilir ve
/// [RoomRepository.updateRoom] transaction'ı içinde atomik çalışır.
/// Kural ihlalinde [GameException] fırlatır.
class GameEngine {
  GameEngine._();

  /// İnşaat/ipotek/satış yapılabilen aşamalar.
  static const Set<TurnPhase> managePhases = {
    TurnPhase.awaitingRoll,
    TurnPhase.awaitingEndTurn,
    TurnPhase.awaitingDebtResolution,
  };

  // ═════════════════════════════════════════════════════════════════
  // Hamleler
  // ═════════════════════════════════════════════════════════════════

  static Room rollDice(Room room, String uid, DiceRoll roll) {
    final t = _Turn(room);
    t.requireTurn(uid);
    t.requirePhase({TurnPhase.awaitingRoll});
    final me = t.p(uid);
    if (me.money < 0) {
      throw const GameException('Zar atmadan önce borcunu kapatmalısın.');
    }

    t.game = t.game.copyWith(lastDice: roll);
    t.log('${me.name} zar attı: ${roll.die1} + ${roll.die2} = ${roll.total}'
        '${roll.isDouble ? ' (çift!)' : ''}',
        kind: LogKind.dice, playerId: uid);

    if (me.inJail) {
      _jailRoll(t, uid, roll);
    } else {
      final doubles = roll.isDouble ? t.game.doublesInRow + 1 : 0;
      if (doubles >= GameRules.doublesToJail) {
        t.log('${me.name} üst üste ${GameRules.doublesToJail} kez çift attı!',
            playerId: uid);
        _sendToJail(t, uid);
      } else {
        t.game = t.game.copyWith(doublesInRow: doubles);
        _moveBy(t, uid, roll.total);
      }
    }
    return t.build();
  }

  static void _jailRoll(_Turn t, String uid, DiceRoll roll) {
    final me = t.p(uid);
    t.game = t.game.copyWith(doublesInRow: 0); // kodesten çıkış çifti tekrar attırmaz

    if (roll.isDouble) {
      t.setP(me.copyWith(inJail: false, jailTurns: 0));
      t.log('${me.name} çift atarak kodesten çıktı!', playerId: uid);
      _moveBy(t, uid, roll.total);
      return;
    }

    final turns = me.jailTurns + 1;
    if (turns >= GameRules.maxJailTurns) {
      t.setP(me.copyWith(inJail: false, jailTurns: 0));
      t.pay(uid, null, GameRules.jailBail,
          '${me.name} ${GameRules.maxJailTurns}. denemede de çıkamadı, kefalet ödedi');
      _moveBy(t, uid, roll.total);
      return;
    }

    t.setP(me.copyWith(jailTurns: turns));
    t.log('${me.name} çift atamadı. Kodeste $turns/${GameRules.maxJailTurns}. tur.',
        playerId: uid);
    t.game = t.game.copyWith(phase: TurnPhase.awaitingEndTurn);
  }

  static Room buyProperty(Room room, String uid) {
    final t = _Turn(room);
    t.requireTurn(uid);
    t.requirePhase({TurnPhase.awaitingBuyDecision});
    final me = t.p(uid);
    final tile = t.board.tile(me.position);
    if (!tile.isBuyable || t.game.tileState(tile.index).isOwned) {
      throw const GameException('Bu kare satın alınamaz.');
    }
    if (me.money < tile.price) {
      throw const GameException('Bu arsa için paran yetmiyor.');
    }
    t.pay(uid, null, tile.price, '${me.name}, ${tile.name} tapusunu aldı',
        kind: LogKind.buy, tileIndex: tile.index);
    t.setTile(TileState(index: tile.index, ownerId: uid));
    _finishMove(t, uid);
    return t.build();
  }

  static Room declineProperty(Room room, String uid) {
    final t = _Turn(room);
    t.requireTurn(uid);
    t.requirePhase({TurnPhase.awaitingBuyDecision});
    final me = t.p(uid);
    t.log('${me.name}, ${t.board.tile(me.position).name} için pas geçti.',
        playerId: uid);
    _finishMove(t, uid);
    return t.build();
  }

  static Room acknowledgeCard(Room room, String uid) {
    final t = _Turn(room);
    t.requireTurn(uid);
    t.requirePhase({TurnPhase.showingCard});
    final cardId = t.game.activeCardId;
    t.game = t.game.copyWith(clearActiveCard: true);
    if (cardId == null) {
      _finishMove(t, uid);
    } else {
      _applyCard(t, uid, CardData.byId(cardId));
    }
    return t.build();
  }

  static Room buildHouse(Room room, String uid, int tileIndex) {
    final err = buildError(room, uid, tileIndex);
    if (err != null) throw GameException(err);
    final t = _Turn(room);
    final tile = t.board.tile(tileIndex);
    final ts = t.game.tileState(tileIndex);
    final newLevel = ts.level + 1;
    t.pay(
      uid,
      null,
      tile.houseCost,
      newLevel == GameRules.skyscraperLevel
          ? '${t.p(uid).name}, ${tile.name}\'e GÖKDELEN dikti'
          : '${t.p(uid).name}, ${tile.name}\'e $newLevel. evi dikti',
      kind: LogKind.build,
      tileIndex: tileIndex,
    );
    t.setTile(ts.copyWith(level: newLevel));
    return t.build();
  }

  static Room sellBuilding(Room room, String uid, int tileIndex) {
    final err = sellError(room, uid, tileIndex);
    if (err != null) throw GameException(err);
    final t = _Turn(room);
    final tile = t.board.tile(tileIndex);
    final ts = t.game.tileState(tileIndex);
    t.receive(uid, tile.houseSellValue,
        '${t.p(uid).name}, ${tile.name}\'deki bir binayı sattı');
    t.setTile(ts.copyWith(level: ts.level - 1));
    _resumeAfterDebt(t, uid);
    return t.build();
  }

  static Room mortgage(Room room, String uid, int tileIndex) {
    final err = mortgageError(room, uid, tileIndex);
    if (err != null) throw GameException(err);
    final t = _Turn(room);
    final tile = t.board.tile(tileIndex);
    t.receive(uid, tile.mortgageValue,
        '${t.p(uid).name}, ${tile.name}\'i ipotek etti');
    t.setTile(t.game.tileState(tileIndex).copyWith(mortgaged: true));
    _resumeAfterDebt(t, uid);
    return t.build();
  }

  static Room unmortgage(Room room, String uid, int tileIndex) {
    final err = unmortgageError(room, uid, tileIndex);
    if (err != null) throw GameException(err);
    final t = _Turn(room);
    final tile = t.board.tile(tileIndex);
    t.pay(uid, null, tile.unmortgageCost,
        '${t.p(uid).name}, ${tile.name} ipoteğini kaldırdı');
    t.setTile(t.game.tileState(tileIndex).copyWith(mortgaged: false));
    return t.build();
  }

  static Room payBail(Room room, String uid) {
    final t = _Turn(room);
    t.requireTurn(uid);
    t.requirePhase({TurnPhase.awaitingRoll});
    final me = t.p(uid);
    if (!me.inJail) throw const GameException('Kodeste değilsin.');
    if (me.money < GameRules.jailBail) {
      throw const GameException('Kefalet için paran yetmiyor.');
    }
    t.setP(me.copyWith(inJail: false, jailTurns: 0));
    t.pay(uid, null, GameRules.jailBail, '${me.name} kefalet ödeyip kodesten çıktı');
    return t.build();
  }

  static Room useJailCard(Room room, String uid) {
    final t = _Turn(room);
    t.requireTurn(uid);
    t.requirePhase({TurnPhase.awaitingRoll});
    final me = t.p(uid);
    if (!me.inJail) throw const GameException('Kodeste değilsin.');
    if (me.jailCardIds.isEmpty) {
      throw const GameException('Kodesten Çıkış Kartın yok.');
    }
    t.setP(me.copyWith(
      inJail: false,
      jailTurns: 0,
      jailCardIds: me.jailCardIds.sublist(1),
    ));
    t.log('${me.name} Kodesten Çıkış Kartı\'nı kullandı.', playerId: uid);
    return t.build();
  }

  static Room endTurn(Room room, String uid) {
    final t = _Turn(room);
    t.requireTurn(uid);
    t.requirePhase({TurnPhase.awaitingEndTurn});
    if (t.p(uid).money < 0) {
      throw const GameException('Sırayı devretmeden önce borcunu kapatmalısın.');
    }
    _advanceTurn(t);
    return t.build();
  }

  /// Borcunu ödeyemeyen oyuncu iflas eder.
  static Room declareBankruptcy(Room room, String uid) {
    final me = room.players[uid];
    if (me == null || me.isBankrupt) {
      throw const GameException('Zaten oyunda değilsin.');
    }
    if (me.money >= 0) {
      throw const GameException('Sadece borcunu ödeyemediğinde iflas edebilirsin.');
    }
    return eliminate(room, uid, reason: '${me.name} İFLAS ETTİ!');
  }

  /// Oyuncuyu oyundan çıkarır (iflas ya da odadan ayrılma). Arsaları ve
  /// binaları bankaya döner. Tek oyuncu kalırsa oyun biter.
  static Room eliminate(Room room, String uid, {required String reason}) {
    final game = room.game;
    final me = room.players[uid];
    if (game == null || me == null || me.isBankrupt) return room;

    final t = _Turn(room);
    t.setP(me.copyWith(isBankrupt: true, money: 0, jailCardIds: const []));
    final tiles = Map<int, TileState>.from(t.game.tiles)
      ..removeWhere((_, s) => s.ownerId == uid);
    final auction = t.game.auction;
    t.game = t.game.copyWith(
      tiles: tiles,
      offers: t.game.offers.where((o) => !o.involves(uid)).toList(),
      clearAuction: auction != null && auction.sellerId == uid,
    );
    t.log(reason, kind: LogKind.bankrupt, playerId: uid);

    final alive = t.alivePlayerIds;
    if (alive.length <= 1) {
      _endGame(t, GameEndReason.lastStanding);
    } else if (t.game.speed.endOnFirstBankruptcy) {
      _endGame(t, GameEndReason.firstBankruptcy);
    } else if (t.game.currentPlayerId == uid) {
      _advanceTurn(t);
    }
    return t.build();
  }

  /// Süre sınırı dolduysa oyunu Net Varlık sıralamasıyla bitirir. Her istemci
  /// çağırabilir; süre dolmadıysa ya da oyun bittiyse odayı değiştirmez.
  static Room finishByTime(Room room, int nowMs) {
    final endsAt = room.game?.endsAtMs;
    if (room.status != RoomStatus.playing || endsAt == null || nowMs < endsAt) {
      return room;
    }
    final t = _Turn(room);
    t.log('⏰ Süre doldu!', kind: LogKind.info);
    _endGame(t, GameEndReason.timeUp);
    return t.build();
  }

  /// Oyunu bitirir. Son kalan oyuncu yoksa kazanan Net Varlığı en yüksek olandır.
  static void _endGame(_Turn t, GameEndReason reason) {
    final ranking = netWorthRanking(t.game, t.players);
    final winner = ranking.isEmpty ? null : ranking.first.player.id;
    t.game = t.game.copyWith(
      phase: TurnPhase.gameOver,
      winnerId: winner,
      endReason: reason,
      clearAuction: true,
      clearActiveCard: true,
      offers: const [],
    );
    t.status = RoomStatus.finished;
    if (winner != null) {
      final w = ranking.first;
      t.log(
          reason == GameEndReason.lastStanding
              ? '🏆 ${w.player.name} oyunu kazandı!'
              : '🏆 ${w.player.name} ${w.total}M Net Varlıkla kazandı! '
                  '(${reason.label})',
          kind: LogKind.win,
          playerId: winner);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // Net Varlık
  // ═════════════════════════════════════════════════════════════════

  /// Nakit + tapu değeri (ipotekliyse ipotek düşülmüş hali) + bina maliyetleri.
  static NetWorth netWorthOf(GameState game, Player p) {
    var deeds = 0;
    var buildings = 0;
    for (final s in game.tilesOwnedBy(p.id)) {
      final tile = game.board.tile(s.index);
      deeds += s.mortgaged ? tile.price - tile.mortgageValue : tile.price;
      buildings += s.level * tile.houseCost;
    }
    return NetWorth(p, p.money, deeds, buildings);
  }

  /// İflas etmemiş oyuncular, Net Varlığa göre büyükten küçüğe.
  static List<NetWorth> netWorthRanking(
      GameState game, Map<String, Player> players) {
    return [
      for (final id in game.turnOrder)
        if (players[id] case final p? when !p.isBankrupt) netWorthOf(game, p),
    ]..sort((a, b) => b.total.compareTo(a.total));
  }

  // ═════════════════════════════════════════════════════════════════
  // Hareket ve iniş
  // ═════════════════════════════════════════════════════════════════

  static void _moveBy(_Turn t, String uid, int steps) {
    final me = t.p(uid);
    final raw = me.position + steps;
    final target = raw % t.board.length;
    t.setP(me.copyWith(position: target));
    t.log('${me.name} → ${t.board.tile(target).name}',
        kind: LogKind.move, playerId: uid, tileIndex: target);
    if (raw >= t.board.length) {
      t.receive(uid, t.game.salary, '${me.name} Başlangıç\'tan geçti, maaş aldı');
    }
    _land(t, uid);
  }

  static void _moveTo(_Turn t, String uid, int target) {
    final me = t.p(uid);
    final passesStart = target < me.position || target == t.board.startIndex;
    t.setP(me.copyWith(position: target));
    t.log('${me.name} → ${t.board.tile(target).name}',
        kind: LogKind.move, playerId: uid, tileIndex: target);
    if (passesStart) {
      t.receive(uid, t.game.salary, '${me.name} Başlangıç\'tan geçti, maaş aldı');
    }
    _land(t, uid);
  }

  static void _sendToJail(_Turn t, String uid) {
    final me = t.p(uid);
    t.setP(me.copyWith(
      position: t.board.jailIndex,
      inJail: true,
      jailTurns: 0,
    ));
    t.game = t.game.copyWith(
      doublesInRow: 0,
      phase: TurnPhase.awaitingEndTurn,
    );
    t.log('🚨 ${me.name} KODESE girdi!',
        kind: LogKind.jail, playerId: uid, tileIndex: t.board.jailIndex);
  }

  static void _land(_Turn t, String uid) {
    final me = t.p(uid);
    final tile = t.board.tile(me.position);

    switch (tile.type) {
      case TileType.start:
      case TileType.jail:
      case TileType.freeParking:
        _finishMove(t, uid);

      case TileType.goToJail:
        _sendToJail(t, uid);

      case TileType.tax:
        t.pay(uid, null, tile.taxAmount, '${me.name} ${tile.name} ödedi');
        _finishMove(t, uid);

      case TileType.chance:
      case TileType.communityFund:
        _drawCard(t, uid,
            tile.type == TileType.chance ? CardDeck.chance : CardDeck.communityFund);

      case TileType.property:
      case TileType.transport:
      case TileType.utility:
        final ts = t.game.tileState(tile.index);
        if (!ts.isOwned) {
          t.game = t.game.copyWith(phase: TurnPhase.awaitingBuyDecision);
          return;
        }
        if (ts.ownerId != uid && !ts.mortgaged) {
          final rent = rentFor(
            t.game,
            tile.index,
            diceTotal: t.game.lastDice?.total ?? 7,
            transportMultiplier: t.transportMultiplier,
            utilityMultiplier: t.utilityMultiplier,
          );
          final owner = t.p(ts.ownerId!);
          t.pay(uid, owner.id, rent,
              '${me.name}, ${owner.name}\'e ${tile.name} kirası ödedi');
        }
        _finishMove(t, uid);
    }
  }

  static void _drawCard(_Turn t, String uid, CardDeck deck) {
    final isChance = deck == CardDeck.chance;
    final ids = isChance ? t.game.chanceDeck : t.game.fundDeck;
    var cursor = isChance ? t.game.chanceCursor : t.game.fundCursor;

    // Birinin elinde duran "Kodesten Çıkış" kartı desteden tekrar çekilmez.
    final held = {for (final p in t.players.values) ...p.jailCardIds};
    int? drawn;
    for (var i = 0; i < ids.length; i++) {
      final id = ids[cursor % ids.length];
      cursor++;
      if (!held.contains(id)) {
        drawn = id;
        break;
      }
    }
    t.game = isChance
        ? t.game.copyWith(chanceCursor: cursor % ids.length)
        : t.game.copyWith(fundCursor: cursor % ids.length);

    if (drawn == null) {
      _finishMove(t, uid);
      return;
    }
    final card = CardData.byId(drawn);
    t.game = t.game.copyWith(activeCardId: drawn, phase: TurnPhase.showingCard);
    t.log('${t.p(uid).name} ${isChance ? 'Şans' : 'Kamu Fonu'} kartı çekti: '
        '"${card.text}"',
        kind: LogKind.card, playerId: uid);
  }

  static void _applyCard(_Turn t, String uid, GameCard card) {
    final me = t.p(uid);
    switch (card.action) {
      case CardAction.advanceTo:
        final city = card.targetCity;
        _moveTo(t, uid,
            (city == null ? null : t.board.indexOfCity(city)) ?? t.board.startIndex);

      case CardAction.advanceToNearestTransport:
        t.transportMultiplier = 2;
        _moveTo(t, uid, t.board.nearestForward(me.position, TileType.transport));

      case CardAction.advanceToNearestUtility:
        t.utilityMultiplier = 10;
        _moveTo(t, uid, t.board.nearestForward(me.position, TileType.utility));

      case CardAction.moveBack:
        final target =
            (me.position - card.value) % t.board.length; // Dart'ta % hep pozitif
        t.setP(me.copyWith(position: target));
        t.log('${me.name} ${card.value} kare geri gitti.',
            kind: LogKind.move, playerId: uid, tileIndex: target);
        _land(t, uid);

      case CardAction.goToJail:
        _sendToJail(t, uid);

      case CardAction.getOutOfJail:
        t.setP(me.copyWith(jailCardIds: [...me.jailCardIds, card.id]));
        _finishMove(t, uid);

      case CardAction.receive:
        t.receive(uid, card.value, '${me.name} kart ödülü aldı');
        _finishMove(t, uid);

      case CardAction.pay:
        t.pay(uid, null, card.value, '${me.name} kart cezası ödedi');
        _finishMove(t, uid);

      case CardAction.collectFromEach:
        for (final other in t.alivePlayerIds.where((id) => id != uid)) {
          t.pay(other, uid, card.value, '${t.p(other).name} → ${me.name}');
        }
        _finishMove(t, uid);

      case CardAction.payEach:
        for (final other in t.alivePlayerIds.where((id) => id != uid)) {
          t.pay(uid, other, card.value, '${me.name} → ${t.p(other).name}');
        }
        _finishMove(t, uid);

      case CardAction.repairs:
        var houses = 0;
        var skyscrapers = 0;
        for (final s in t.game.tilesOwnedBy(uid)) {
          if (s.hasSkyscraper) {
            skyscrapers++;
          } else {
            houses += s.level;
          }
        }
        final cost = houses * card.value + skyscrapers * card.value2;
        if (cost > 0) {
          t.pay(uid, null, cost,
              '${me.name} $houses ev, $skyscrapers gökdelen için bakım ödedi');
        }
        _finishMove(t, uid);
    }
  }

  /// İniş tamamlandı: borç varsa borç aşamasına, yoksa sonraki aşamaya geç.
  static void _finishMove(_Turn t, String uid) {
    t.game = t.game.copyWith(
      phase: t.p(uid).money < 0
          ? TurnPhase.awaitingDebtResolution
          : _postMovePhase(t, uid),
    );
  }

  /// Çift attıysa tekrar zar atar, yoksa sırayı devretmeyi bekler.
  static TurnPhase _postMovePhase(_Turn t, String uid) {
    final rolledDouble = t.game.lastDice?.isDouble ?? false;
    final canRollAgain =
        !t.p(uid).inJail && rolledDouble && t.game.doublesInRow > 0;
    return canRollAgain ? TurnPhase.awaitingRoll : TurnPhase.awaitingEndTurn;
  }

  static void _resumeAfterDebt(_Turn t, String uid) {
    if (t.game.currentPlayerId == uid &&
        t.game.phase == TurnPhase.awaitingDebtResolution &&
        t.p(uid).money >= 0) {
      t.game = t.game.copyWith(phase: _postMovePhase(t, uid));
    }
  }

  static void _advanceTurn(_Turn t) {
    final order = t.game.turnOrder;
    var next = t.game.currentTurnIndex;
    for (var step = 1; step <= order.length; step++) {
      final i = (t.game.currentTurnIndex + step) % order.length;
      if (!(t.players[order[i]]?.isBankrupt ?? true)) {
        next = i;
        break;
      }
    }
    t.game = t.game.copyWith(
      currentTurnIndex: next,
      phase: TurnPhase.awaitingRoll,
      doublesInRow: 0,
      turnNumber: t.game.turnNumber + 1,
      clearActiveCard: true,
    );
    final p = t.players[order[next]];
    if (p != null) {
      t.log('Sıra ${p.name}\'de${p.inJail ? ' (kodeste)' : ''}.', playerId: p.id);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // Açık artırma (müzayede)
  // ═════════════════════════════════════════════════════════════════

  /// Sahibi, ilini açık artırmaya çıkarır. Herkesin ekranında müzayede açılır.
  static Room startAuction(
      Room room, String uid, int tileIndex, int startPrice, int nowMs) {
    final err = auctionStartError(room, uid, tileIndex);
    if (err != null) throw GameException(err);
    if (startPrice < 1) {
      throw const GameException('Başlangıç fiyatı en az 1M olmalı.');
    }
    final t = _Turn(room);
    final tile = t.board.tile(tileIndex);
    t.game = t.game.copyWith(
      auction: Auction(
        tileIndex: tileIndex,
        sellerId: uid,
        startPrice: startPrice,
        endsAtMs: nowMs + GameRules.auctionDuration.inMilliseconds,
      ),
    );
    t.log(
        '🔨 ${t.p(uid).name}, ${tile.name} tapusunu ${startPrice}M '
        'başlangıç fiyatıyla açık artırmaya çıkardı!',
        kind: LogKind.auction,
        playerId: uid,
        tileIndex: tileIndex);
    return t.build();
  }

  static Room placeBid(Room room, String uid, int amount, int nowMs) {
    final t = _Turn(room);
    final a = t.game.auction;
    if (a == null) throw const GameException('Süren bir müzayede yok.');
    if (a.isOver(nowMs)) throw const GameException('Müzayede süresi doldu.');
    final me = t.p(uid);
    if (me.isBankrupt) throw const GameException('Oyundan çıktın.');
    if (a.sellerId == uid) {
      throw const GameException('Kendi müzayedene teklif veremezsin.');
    }
    if (a.highestBidderId == uid) {
      throw const GameException('En yüksek teklif zaten senin.');
    }
    if (amount < a.minimumBid) {
      throw GameException('Teklif en az ${a.minimumBid}M olmalı.');
    }
    if (me.money < amount) {
      throw const GameException('Bu teklif için paran yetmiyor.');
    }
    // Her teklif kalan süreyi en az 5 saniyeye çıkarır.
    final reset = nowMs + GameRules.auctionBidReset.inMilliseconds;
    t.game = t.game
        .copyWith(auction: a.withBid(uid, amount, max(a.endsAtMs, reset)));
    t.log('${me.name} ${amount}M teklif verdi.',
        kind: LogKind.auction, playerId: uid, tileIndex: a.tileIndex);
    return t.build();
  }

  /// Süre dolduysa müzayedeyi sonuçlandırır. Her istemci çağırabilir; süre
  /// dolmadıysa ya da müzayede zaten bittiyse odayı değiştirmeden döner.
  static Room finalizeAuction(Room room, int nowMs) {
    final a = room.game?.auction;
    if (room.status != RoomStatus.playing || a == null || !a.isOver(nowMs)) {
      return room;
    }
    final t = _Turn(room);
    final tile = t.board.tile(a.tileIndex);
    final seller = t.p(a.sellerId);
    final state = t.game.tileState(a.tileIndex);
    t.game = t.game.copyWith(clearAuction: true);

    final bidderId = a.highestBidderId;
    final bid = a.highestBid ?? 0;
    final bidder = bidderId == null ? null : t.players[bidderId];
    final stillValid = state.ownerId == seller.id &&
        !_hasBlockingBuildings(t.game, tile) &&
        !seller.isBankrupt;

    if (bidder == null ||
        bidder.isBankrupt ||
        bidder.money < bid ||
        !stillValid) {
      t.log(
          '🔨 ${tile.name} müzayedesi satışsız kapandı; tapu '
          '${seller.name}\'de kaldı.',
          kind: LogKind.auction,
          playerId: seller.id,
          tileIndex: tile.index);
      return t.build();
    }

    t.pay(bidder.id, seller.id, bid,
        '🔨 ${bidder.name}, ${tile.name} tapusunu müzayedede aldı',
        kind: LogKind.auction, tileIndex: tile.index);
    t.setTile(state.copyWith(ownerId: bidder.id));
    _dropOffersTouching(t, {tile.index});
    _resumeAfterDebt(t, t.game.currentPlayerId);
    return t.build();
  }

  static String? auctionStartError(Room room, String uid, int index) {
    final turnErr = _manageTurnError(room, uid, allowInDebt: true);
    if (turnErr != null) return turnErr;
    final game = room.game!;
    final tile = game.board.tile(index);
    if (!tile.isBuyable) return 'Bu kare satılamaz.';
    if (game.tileState(index).ownerId != uid) return 'Bu tapu senin değil.';
    if (_hasBlockingBuildings(game, tile)) {
      return game.speed.quickBuild
          ? 'Önce bu ildeki ev/gökdelenleri bankaya satmalısın.'
          : 'Önce bu gruptaki ev/gökdelenleri bankaya satmalısın.';
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════════════
  // Doğrudan teklif (pazarlık / takas)
  // ═════════════════════════════════════════════════════════════════

  /// Teklif gönderir. Aynı kişiye önceki teklifin varsa yenisiyle değişir;
  /// [TradeOffer.counterOf] doluysa yanıtlanan teklif kapanır.
  static Room sendOffer(Room room, TradeOffer offer) {
    final t = _Turn(room);
    final err = _offerError(t, offer);
    if (err != null) throw GameException(err);
    final others = t.game.offers
        .where((o) =>
            o.id != offer.counterOf &&
            !(o.fromId == offer.fromId && o.toId == offer.toId))
        .toList();
    if (others.length >= GameRules.maxOpenOffers) {
      throw const GameException('Çok fazla bekleyen teklif var.');
    }
    t.game = t.game.copyWith(offers: [...others, offer]);
    t.log(
        '🤝 ${t.p(offer.fromId).name}, ${t.p(offer.toId).name}\'e '
        '${offer.counterOf == null ? '' : 'karşı '}teklif gönderdi.',
        kind: LogKind.trade,
        playerId: offer.fromId);
    return t.build();
  }

  static Room acceptOffer(Room room, String uid, String offerId) {
    final t = _Turn(room);
    final offer = _findOffer(t, offerId);
    if (offer.toId != uid) throw const GameException('Bu teklif sana değil.');
    final err = _offerError(t, offer);
    if (err != null) throw GameException(err);

    final from = t.p(offer.fromId);
    final to = t.p(offer.toId);
    for (final i in offer.requestedTiles) {
      t.setTile(t.game.tileState(i).copyWith(ownerId: from.id));
    }
    for (final i in offer.offeredTiles) {
      t.setTile(t.game.tileState(i).copyWith(ownerId: to.id));
    }
    if (offer.cash > 0) {
      t.pay(from.id, to.id, offer.cash, '🤝 ${from.name} → ${to.name} takas',
          kind: LogKind.trade);
    } else if (offer.cash < 0) {
      t.pay(to.id, from.id, -offer.cash, '🤝 ${to.name} → ${from.name} takas',
          kind: LogKind.trade);
    }
    final names = [
      for (final i in [...offer.requestedTiles, ...offer.offeredTiles])
        t.board.tile(i).name,
    ];
    t.log(
        '🤝 ${to.name}, ${from.name}\'in teklifini kabul etti'
        '${names.isEmpty ? '' : ' (${names.join(', ')})'}.',
        kind: LogKind.trade,
        playerId: to.id);

    t.game = t.game.copyWith(
        offers: t.game.offers.where((o) => o.id != offer.id).toList());
    _dropOffersTouching(t, {...offer.requestedTiles, ...offer.offeredTiles});
    _resumeAfterDebt(t, t.game.currentPlayerId);
    return t.build();
  }

  /// Alıcı reddeder ya da gönderen geri çeker.
  static Room rejectOffer(Room room, String uid, String offerId) {
    final t = _Turn(room);
    final offer = _findOffer(t, offerId);
    if (offer.toId != uid && offer.fromId != uid) {
      throw const GameException('Bu teklif seninle ilgili değil.');
    }
    t.game = t.game.copyWith(
        offers: t.game.offers.where((o) => o.id != offerId).toList());
    t.log(
        offer.fromId == uid
            ? '${t.p(uid).name} teklifini geri çekti.'
            : '${t.p(uid).name}, ${t.p(offer.fromId).name}\'in teklifini reddetti.',
        kind: LogKind.trade,
        playerId: uid);
    return t.build();
  }

  static TradeOffer _findOffer(_Turn t, String id) {
    for (final o in t.game.offers) {
      if (o.id == id) return o;
    }
    throw const GameException('Teklif artık geçerli değil.');
  }

  static void _dropOffersTouching(_Turn t, Set<int> tiles) {
    t.game = t.game.copyWith(
      offers: t.game.offers.where((o) => !tiles.any(o.touchesTile)).toList(),
    );
  }

  /// Teklifin şu anki durumda uygulanabilir olup olmadığı; uygunsa null.
  static String? _offerError(_Turn t, TradeOffer o) {
    if (o.fromId == o.toId) return 'Kendine teklif gönderemezsin.';
    final from = t.players[o.fromId];
    final to = t.players[o.toId];
    if (from == null || to == null || from.isBankrupt || to.isBankrupt) {
      return 'Oyuncu artık oyunda değil.';
    }
    if (o.isEmpty) return 'Teklif boş.';
    final auctionTile = t.game.auction?.tileIndex;
    for (final i in o.requestedTiles) {
      if (t.game.tileState(i).ownerId != o.toId) {
        return '${t.board.tile(i).name} artık ${to.name}\'e ait değil.';
      }
    }
    for (final i in o.offeredTiles) {
      if (t.game.tileState(i).ownerId != o.fromId) {
        return '${t.board.tile(i).name} artık ${from.name}\'e ait değil.';
      }
    }
    for (final i in [...o.requestedTiles, ...o.offeredTiles]) {
      final tile = t.board.tile(i);
      if (i == auctionTile) return '${tile.name} şu an müzayedede.';
      if (_hasBlockingBuildings(t.game, tile)) {
        return '${tile.name} grubunda bina var. Satıştan önce binaların '
            'bankaya satılması gerekir.';
      }
    }
    if (o.cash > 0 && from.money < o.cash) {
      return '${from.name} teklif edilen ${o.cash}M\'yi ödeyemiyor.';
    }
    if (o.cash < 0 && to.money < -o.cash) {
      return '${to.name} istenen ${-o.cash}M\'yi ödeyemiyor.';
    }
    return null;
  }

  /// İl satılırken/takaslanırken/ipotek edilirken bina olmamalı.
  /// Klasik kuralda tüm renk grubu, hızlandırılmış inşaatta sadece ilin kendisi.
  static bool _hasBlockingBuildings(GameState game, Tile tile) {
    final group = tile.group;
    if (group == null) return false;
    if (game.speed.quickBuild) return game.tileState(tile.index).level > 0;
    return game.board
        .tilesInGroup(group)
        .any((x) => game.tileState(x.index).level > 0);
  }

  /// Arayüzün teklifi göndermeden önce gösterebileceği hata; uygunsa null.
  static String? offerError(Room room, TradeOffer offer) {
    try {
      return _offerError(_Turn(room), offer);
    } on GameException catch (e) {
      return e.message;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // Sorgular (arayüz de kullanır)
  // ═════════════════════════════════════════════════════════════════

  static bool ownsFullGroup(GameState game, String ownerId, TileGroup group) =>
      game.board.tilesInGroup(group)
          .every((t) => game.tileState(t.index).ownerId == ownerId);

  static int _ownedCountOfType(GameState game, String ownerId, TileType type) =>
      game.board.tiles
          .where((t) =>
              t.type == type && game.tileState(t.index).ownerId == ownerId)
          .length;

  /// Bir karenin şu anki kira bedeli. Sahipsiz ya da ipotekliyse 0.
  static int rentFor(
    GameState game,
    int index, {
    required int diceTotal,
    int transportMultiplier = 1,
    int utilityMultiplier = 0,
  }) {
    final tile = game.board.tile(index);
    final ts = game.tileState(index);
    final owner = ts.ownerId;
    if (owner == null || ts.mortgaged) return 0;

    switch (tile.type) {
      case TileType.property:
        if (ts.level == 0) {
          // Grubun tamamına sahipse boş arsa kirası iki katı.
          return tile.rents[0] * (ownsFullGroup(game, owner, tile.group!) ? 2 : 1);
        }
        return tile.rents[ts.level];
      case TileType.transport:
        final n = _ownedCountOfType(game, owner, TileType.transport);
        return tile.rents[max(n, 1) - 1] * transportMultiplier;
      case TileType.utility:
        final n = _ownedCountOfType(game, owner, TileType.utility);
        final mult =
            utilityMultiplier > 0 ? utilityMultiplier : tile.rents[max(n, 1) - 1];
        return diceTotal * mult;
      default:
        return 0;
    }
  }

  /// Arayüzde gösterilecek tahmini kira (utility için 7 zar varsayılır).
  static int displayRent(GameState game, int index) =>
      rentFor(game, index, diceTotal: 7);

  static String? _manageTurnError(Room room, String uid, {bool allowInDebt = false}) {
    final game = room.game;
    final me = room.players[uid];
    if (room.status != RoomStatus.playing || game == null || me == null) {
      return 'Oyun devam etmiyor.';
    }
    if (me.isBankrupt) return 'Oyundan çıktın.';
    if (game.auction != null) return 'Müzayede sürüyor, bitmesini bekle.';
    if (allowInDebt && me.money < 0) return null; // borçlu her an satabilir
    if (game.currentPlayerId != uid) return 'Bunu sadece kendi sıranda yapabilirsin.';
    if (!managePhases.contains(game.phase)) {
      return 'Önce mevcut işlemi tamamla.';
    }
    return null;
  }

  static String? buildError(Room room, String uid, int index) {
    final turnErr = _manageTurnError(room, uid);
    if (turnErr != null) return turnErr;
    final game = room.game!;
    final tile = game.board.tile(index);
    final ts = game.tileState(index);
    if (!tile.isBuildable) return 'Bu kareye bina dikilemez.';
    if (ts.ownerId != uid) return 'Bu arsa senin değil.';
    if (game.speed.quickBuild) {
      // Hızlandırılmış inşaat: grup şartı ve eşit dağılım yok.
      if (ts.mortgaged) return 'İpotekli ile bina dikilemez.';
      if (ts.level >= GameRules.maxBuildingLevel) return 'Zaten gökdelen var.';
      if (room.players[uid]!.money < tile.houseCost) return 'Paran yetmiyor.';
      return null;
    }
    final group = game.board.tilesInGroup(tile.group!);
    if (!ownsFullGroup(game, uid, tile.group!)) {
      return '${tile.group!.label} grubunun tamamına sahip olmalısın.';
    }
    if (group.any((t) => game.tileState(t.index).mortgaged)) {
      return 'Gruptaki ipotekli arsaları önce kurtarmalısın.';
    }
    if (ts.level >= GameRules.maxBuildingLevel) return 'Zaten gökdelen var.';
    final minLevel =
        group.map((t) => game.tileState(t.index).level).reduce(min);
    if (ts.level > minLevel) {
      return 'Eşit dağılım kuralı: önce gruptaki diğer arsalara bina dik.';
    }
    if (room.players[uid]!.money < tile.houseCost) return 'Paran yetmiyor.';
    return null;
  }

  static String? sellError(Room room, String uid, int index) {
    final turnErr = _manageTurnError(room, uid, allowInDebt: true);
    if (turnErr != null) return turnErr;
    final game = room.game!;
    final tile = game.board.tile(index);
    final ts = game.tileState(index);
    if (ts.ownerId != uid) return 'Bu arsa senin değil.';
    if (ts.level == 0) return 'Satılacak bina yok.';
    if (game.speed.quickBuild) return null;
    final maxLevel = game.board.tilesInGroup(tile.group!)
        .map((t) => game.tileState(t.index).level)
        .reduce(max);
    if (ts.level < maxLevel) {
      return 'Eşit dağılım kuralı: önce gruptaki daha yüksek binaları sat.';
    }
    return null;
  }

  static String? mortgageError(Room room, String uid, int index) {
    final turnErr = _manageTurnError(room, uid, allowInDebt: true);
    if (turnErr != null) return turnErr;
    final game = room.game!;
    final tile = game.board.tile(index);
    final ts = game.tileState(index);
    if (ts.ownerId != uid) return 'Bu arsa senin değil.';
    if (ts.mortgaged) return 'Zaten ipotekli.';
    if (_hasBlockingBuildings(game, tile)) {
      return game.speed.quickBuild
          ? 'Önce bu ildeki binaları satmalısın.'
          : 'Önce bu gruptaki tüm binaları satmalısın.';
    }
    return null;
  }

  static String? unmortgageError(Room room, String uid, int index) {
    final turnErr = _manageTurnError(room, uid);
    if (turnErr != null) return turnErr;
    final ts = room.game!.tileState(index);
    if (ts.ownerId != uid) return 'Bu arsa senin değil.';
    if (!ts.mortgaged) return 'İpotekli değil.';
    if (room.players[uid]!.money < room.game!.board.tile(index).unmortgageCost) {
      return 'Paran yetmiyor.';
    }
    return null;
  }
}

/// Bir hamle boyunca değişen durumu tutan yardımcı.
class _Turn {
  _Turn(this.room)
      : players = Map<String, Player>.from(room.players),
        status = room.status {
    final g = room.game;
    if (room.status != RoomStatus.playing || g == null) {
      throw const GameException('Oyun devam etmiyor.');
    }
    game = g;
  }

  final Room room;
  final Map<String, Player> players;
  late GameState game;
  RoomStatus status;

  // Kartlardan gelen geçici kira çarpanları (sadece bu hamlede geçerli).
  int transportMultiplier = 1;
  int utilityMultiplier = 0;

  Player p(String id) {
    final player = players[id];
    if (player == null) throw const GameException('Oyuncu bulunamadı.');
    return player;
  }

  BoardLayout get board => game.board;

  void setP(Player player) => players[player.id] = player;

  void setTile(TileState s) {
    game = game.copyWith(tiles: {...game.tiles, s.index: s});
  }

  List<String> get alivePlayerIds => [
        for (final id in game.turnOrder)
          if (!(players[id]?.isBankrupt ?? true)) id,
      ];

  void requireTurn(String uid) {
    if (game.phase == TurnPhase.gameOver) {
      throw const GameException('Oyun bitti.');
    }
    if (game.currentPlayerId != uid) {
      throw const GameException('Sıra sende değil.');
    }
    if (game.auction != null) {
      throw const GameException('Müzayede sürüyor, bitmesini bekle.');
    }
    if (p(uid).isBankrupt) throw const GameException('Oyundan çıktın.');
  }

  void requirePhase(Set<TurnPhase> phases) {
    if (!phases.contains(game.phase)) {
      throw const GameException('Şu an bu hamle yapılamaz.');
    }
  }

  void log(String text,
      {LogKind kind = LogKind.info, String? playerId, int? moneyDelta, int? tileIndex}) {
    game = game.addLog(text,
        kind: kind, playerId: playerId, moneyDelta: moneyDelta, tileIndex: tileIndex);
  }

  /// [fromId] oyuncusu [amount] öder. [toId] null ise bankaya.
  /// Para eksiye düşebilir; borç aşaması bunu çözer.
  void pay(String fromId, String? toId, int amount, String text,
      {LogKind kind = LogKind.money, int? tileIndex}) {
    if (amount <= 0) return;
    final from = p(fromId);
    setP(from.copyWith(money: from.money - amount));
    log('$text (-${amount}M)',
        kind: kind, playerId: fromId, moneyDelta: -amount, tileIndex: tileIndex);
    if (toId != null) {
      final to = p(toId);
      setP(to.copyWith(money: to.money + amount));
      log('${to.name} +${amount}M',
          kind: LogKind.money, playerId: toId, moneyDelta: amount);
    }
  }

  void receive(String id, int amount, String text) {
    if (amount <= 0) return;
    final pl = p(id);
    setP(pl.copyWith(money: pl.money + amount));
    log('$text (+${amount}M)',
        kind: LogKind.money, playerId: id, moneyDelta: amount);
  }

  Room build() => room.copyWith(players: players, game: game, status: status);
}

/// Bir oyuncunun Net Varlık dökümü.
class NetWorth {
  final Player player;
  final int cash;
  final int deeds;
  final int buildings;

  const NetWorth(this.player, this.cash, this.deeds, this.buildings);

  int get total => cash + deeds + buildings;
}
