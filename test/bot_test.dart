import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:metropol/core/constants/game_rules.dart';
import 'package:metropol/core/errors.dart';
import 'package:metropol/core/utils/dice.dart';
import 'package:metropol/data/board_layout.dart';
import 'package:metropol/data/card_data.dart';
import 'package:metropol/logic/bot_brain.dart';
import 'package:metropol/logic/bot_factory.dart';
import 'package:metropol/logic/game_engine.dart';
import 'package:metropol/models/models.dart';
import 'package:metropol/services/game_initializer.dart';

final board = BoardLayout.of(BoardSize.standard);

Player human(String id) => Player(
      id: id,
      name: 'İnsan',
      pawn: PawnToken.initial,
      joinedAtMs: 0,
      isHost: true,
    );

Room lobby(List<Player> players) => Room(
      code: '1234',
      hostId: players.first.id,
      status: RoomStatus.waiting,
      createdAtMs: 0,
      updatedAtMs: 0,
      players: {for (final p in players) p.id: p},
    );

/// 'h' insan, 'b' bot. Sıra: önce h sonra b (ya da [order]).
Room game({
  List<String> order = const ['h', 'b'],
  Map<String, int> money = const {},
  Map<String, int> positions = const {},
  Map<int, TileState> tiles = const {},
  TurnPhase phase = TurnPhase.awaitingRoll,
  Set<String> jailed = const {},
  Map<String, List<int>> jailCards = const {},
  List<TradeOffer> offers = const [],
  Auction? auction,
  GameSpeed speed = GameSpeed.normal,
}) {
  return Room(
    code: '1234',
    hostId: 'h',
    status: RoomStatus.playing,
    createdAtMs: 0,
    updatedAtMs: 0,
    players: {
      for (final (i, id) in order.indexed)
        id: Player(
          id: id,
          name: id.toUpperCase(),
          pawn: PawnToken(PawnSymbol.values[i], PawnColor.values[i]),
          joinedAtMs: i,
          isHost: id == 'h',
          isBot: id != 'h',
          money: money[id] ?? 2500,
          position: positions[id] ?? 0,
          inJail: jailed.contains(id),
          jailCardIds: jailCards[id] ?? const [],
        ),
    },
    game: GameState(
      boardSize: BoardSize.standard,
      speed: speed,
      turnOrder: order,
      chanceDeck: [for (final c in CardData.chance) c.id],
      fundDeck: [for (final c in CardData.communityFund) c.id],
      tiles: tiles,
      phase: phase,
      offers: offers,
    ).copyWith(auction: auction),
  );
}

Tile firstOfType(TileType type) => board.tiles.firstWhere((t) => t.type == type);

/// Sürücünün yaptığını Firebase olmadan yapar: hamleyi motorla uygular.
Room apply(Room r, BotMove m, Dice dice, int nowMs) {
  final id = m.botId;
  return switch (m.kind) {
    BotMoveKind.orderRoll => throw UnimplementedError(),
    BotMoveKind.roll => GameEngine.rollDice(r, id, dice.roll()),
    BotMoveKind.buy => GameEngine.buyProperty(r, id),
    BotMoveKind.decline => GameEngine.declineProperty(r, id),
    BotMoveKind.acknowledgeCard => GameEngine.acknowledgeCard(r, id),
    BotMoveKind.build => GameEngine.buildHouse(r, id, m.tile!),
    BotMoveKind.unmortgage => GameEngine.unmortgage(r, id, m.tile!),
    BotMoveKind.sell => GameEngine.sellBuilding(r, id, m.tile!),
    BotMoveKind.mortgage => GameEngine.mortgage(r, id, m.tile!),
    BotMoveKind.payBail => GameEngine.payBail(r, id),
    BotMoveKind.useJailCard => GameEngine.useJailCard(r, id),
    BotMoveKind.endTurn => GameEngine.endTurn(r, id),
    BotMoveKind.bankrupt => GameEngine.declareBankruptcy(r, id),
    BotMoveKind.bid => GameEngine.placeBid(r, id, m.amount!, nowMs),
    BotMoveKind.acceptOffer => GameEngine.acceptOffer(r, id, m.offerId!),
    BotMoveKind.rejectOffer => GameEngine.rejectOffer(r, id, m.offerId!),
  };
}

void main() {
  group('Bot ekleme', () {
    test('7 bot: isimler, semboller, renkler ve id\'ler benzersiz', () {
      var room = lobby([human('h')]);
      final rnd = Random(1);
      for (var i = 0; i < GameRules.maxPlayers - 1; i++) {
        final bot = BotFactory.create(room, now: 1000, random: rnd);
        expect(bot.isBot, isTrue);
        expect(bot.isHost, isFalse);
        room = room.copyWith(players: {...room.players, bot.id: bot});
      }
      final ps = room.players.values.toList();
      expect(ps.length, GameRules.maxPlayers);
      expect(ps.map((p) => p.name.toLowerCase()).toSet().length, ps.length);
      expect(ps.map((p) => p.pawn.symbol).toSet().length, ps.length);
      expect(ps.map((p) => p.pawn.tint).toSet().length, ps.length);
      // Katılma sırası korunur: botlar insandan sonra, eklendikleri sırayla.
      final order = room.playersByJoinOrder;
      expect(order.first.id, 'h');
      expect(order.map((p) => p.joinedAtMs).toSet().length, ps.length);
    });

    test('isBot kaydedilir, okunur ve copyWith ile korunur', () {
      final bot = BotFactory.create(lobby([human('h')]), now: 5);
      final back = Player.fromMap(bot.toMap());
      expect(back.isBot, isTrue);
      expect(back.copyWith(money: 10).isBot, isTrue);
      expect(Player.fromMap(human('h').toMap()).isBot, isFalse);
      // Eski kayıtlarda alan yoksa insan sayılır.
      expect(Player.fromMap(human('h').toMap()..remove('isBot')).isBot, isFalse);
    });
  });

  group('Bot kararları', () {
    test('sıra düellosunda sırası gelen bot zar atar, insanı beklemez', () {
      final base = lobby([human('h'), BotFactory.create(lobby([human('h')]), now: 1)]);
      final botId = base.players.values.firstWhere((p) => p.isBot).id;
      final room = base.copyWith(
        status: RoomStatus.orderDuel,
        orderDuel: OrderDuel.start([botId, 'h']),
      );
      final m = BotBrain.decide(room)!;
      expect(m.kind, BotMoveKind.orderRoll);
      expect(m.botId, botId);

      final humanFirst =
          room.copyWith(orderDuel: OrderDuel.start(['h', botId]));
      expect(BotBrain.decide(humanFirst), isNull);
    });

    test('sıra insandaysa bot bir şey yapmaz', () {
      expect(BotBrain.decide(game()), isNull);
    });

    test('sıra bottaysa zar atar', () {
      final m = BotBrain.decide(game(order: ['b', 'h']))!;
      expect((m.botId, m.kind), ('b', BotMoveKind.roll));
    });

    test('parası yetiyorsa alır, yetmiyorsa pas geçer', () {
      final city = firstOfType(TileType.property);
      Room at(int money) => game(
            order: ['b', 'h'],
            phase: TurnPhase.awaitingBuyDecision,
            positions: {'b': city.index},
            money: {'b': money},
          );
      expect(BotBrain.decide(at(2500))!.kind, BotMoveKind.buy);
      expect(BotBrain.decide(at(city.price + 10))!.kind, BotMoveKind.decline);
    });

    test('kart gösterilirken onaylar', () {
      final r = game(order: ['b', 'h'], phase: TurnPhase.showingCard);
      expect(BotBrain.decide(r)!.kind, BotMoveKind.acknowledgeCard);
    });

    test('kodeste kartı varsa kullanır', () {
      final r = game(
        order: ['b', 'h'],
        jailed: {'b'},
        jailCards: {'b': [CardData.chance.first.id]},
      );
      expect(BotBrain.decide(r)!.kind, BotMoveKind.useJailCard);
    });

    test('borçta: önce bina satar, sonra ipotek eder, en son iflas', () {
      final group = board.tilesInGroup(firstOfType(TileType.property).group!);
      final withHouses = {
        for (final t in group)
          t.index: TileState(index: t.index, ownerId: 'b', level: 1),
      };
      Room debt(Map<int, TileState> tiles) => game(
            order: ['b', 'h'],
            phase: TurnPhase.awaitingDebtResolution,
            money: {'b': -50},
            tiles: tiles,
          );

      expect(BotBrain.decide(debt(withHouses))!.kind, BotMoveKind.sell);

      final bare = {
        for (final t in group) t.index: TileState(index: t.index, ownerId: 'b'),
      };
      final m = BotBrain.decide(debt(bare))!;
      expect(m.kind, BotMoveKind.mortgage);
      expect(m.tile, group.first.index); // en ucuz önce

      expect(BotBrain.decide(debt(const {}))!.kind, BotMoveKind.bankrupt);
    });

    test('sırası olmasa da borçlu bot borcunu kapatır', () {
      final r = game(
        phase: TurnPhase.awaitingEndTurn, // sıra insanda
        money: {'b': -10},
      );
      final m = BotBrain.decide(r)!;
      expect((m.botId, m.kind), ('b', BotMoveKind.bankrupt));
    });

    test('hızlı modda tek iline bina diker, sonra sırayı devreder', () {
      final city = firstOfType(TileType.property);
      Room end(int money) => game(
            order: ['b', 'h'],
            speed: GameSpeed.fast,
            phase: TurnPhase.awaitingEndTurn,
            money: {'b': money},
            tiles: {city.index: TileState(index: city.index, ownerId: 'b')},
          );
      final m = BotBrain.decide(end(2000))!;
      expect((m.kind, m.tile), (BotMoveKind.build, city.index));
      // Güvenlik payı kalmıyorsa dikmez.
      expect(BotBrain.decide(end(city.houseCost + 10))!.kind,
          BotMoveKind.endTurn);
    });

    test('başarısız hamle atlanınca bir sonraki seçenek gelir', () {
      final city = firstOfType(TileType.property);
      final r = game(
        order: ['b', 'h'],
        phase: TurnPhase.awaitingBuyDecision,
        positions: {'b': city.index},
      );
      final buy = BotBrain.decide(r)!;
      final next = BotBrain.decide(r, skip: {buy.key})!;
      expect(next.kind, BotMoveKind.decline);
    });

    test('müzayedede tapu fiyatına kadar artırır, satıcı teklif vermez', () {
      final city = firstOfType(TileType.property);
      Auction a({String seller = 'h', int? highest, String? bidder}) => Auction(
            tileIndex: city.index,
            sellerId: seller,
            startPrice: 10,
            highestBid: highest,
            highestBidderId: bidder,
            endsAtMs: 99999,
          );
      final open = BotBrain.decide(game(auction: a()))!;
      expect((open.kind, open.amount), (BotMoveKind.bid, 10));

      final raise =
          BotBrain.decide(game(auction: a(highest: city.price - 5, bidder: 'h')))!;
      expect(raise.amount, city.price); // fiyatı aşmaz

      expect(BotBrain.decide(game(auction: a(highest: city.price, bidder: 'h'))),
          isNull);
      expect(BotBrain.decide(game(auction: a(seller: 'b'))), isNull);
    });

    test('kârlı takası kabul eder, zararlıyı reddeder', () {
      final city = firstOfType(TileType.property);
      TradeOffer offer(int cash) => TradeOffer(
            id: 'o1',
            fromId: 'h',
            toId: 'b',
            requestedTiles: [city.index],
            offeredTiles: const [],
            cash: cash,
            createdAtMs: 0,
          );
      Room r(int cash) => game(
            offers: [offer(cash)],
            tiles: {city.index: TileState(index: city.index, ownerId: 'b')},
          );
      expect(BotBrain.decide(r(city.price * 2))!.kind, BotMoveKind.acceptOffer);
      expect(BotBrain.decide(r(1))!.kind, BotMoveKind.rejectOffer);
    });
  });

  group('Sadece botlarla tam oyun (motor üzerinden)', () {
    for (final speed in GameSpeed.values) {
      test('${speed.label}: botlar takılmadan oynar', () {
        const ids = ['b1', 'b2', 'b3', 'b4'];
        final players = {
          for (final (i, id) in ids.indexed)
            id: Player(
              id: id,
              name: id,
              pawn: PawnToken(PawnSymbol.values[i], PawnColor.values[i]),
              joinedAtMs: i,
              isBot: true,
              money: speed.startingMoney,
            ),
        };
        var room = Room(
          code: '1234',
          hostId: 'h',
          status: RoomStatus.playing,
          createdAtMs: 0,
          updatedAtMs: 0,
          players: players,
          settings: GameSettings(speed: speed),
          game: GameInitializer.create(
            ids,
            players,
            boardSize: speed.boardFor(ids.length),
            settings: GameSettings(speed: speed),
            nowMs: 0,
            random: Random(7),
          ),
        );
        final dice = Dice(Random(42));
        var moves = 0;
        final skip = <String>{};
        while (room.status == RoomStatus.playing && moves < 4000) {
          final move = BotBrain.decide(room, skip: skip);
          expect(move, isNotNull,
              reason: 'Bot takıldı: ${room.game!.phase} '
                  '(sıra ${room.game!.currentPlayerId})');
          try {
            room = apply(room, move!, dice, 0);
            skip.clear();
          } on GameException catch (e) {
            skip.add(move!.key); // sürücü gibi: sıradaki seçeneğe geç
            expect(skip.length, lessThan(50), reason: e.message);
          }
          moves++;
        }
        // Hiç takılmadan 4000 hamle oynandı ya da oyun bitti.
        expect(moves, greaterThan(100));
        if (room.status == RoomStatus.finished) {
          expect(room.game!.winnerId, isNotNull);
        }
      });
    }
  });
}
