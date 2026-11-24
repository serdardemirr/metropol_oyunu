import 'package:flutter_test/flutter_test.dart';
import 'package:metropol/core/constants/game_rules.dart';
import 'package:metropol/core/errors.dart';
import 'package:metropol/core/utils/dice.dart';
import 'package:metropol/data/board_layout.dart';
import 'package:metropol/data/card_data.dart';
import 'package:metropol/logic/game_engine.dart';
import 'package:metropol/models/models.dart';

/// Testler standart (44 kare) haritayı kullanır. Dizilim üretildiği için
/// kareler sabit numara yerine türlerine göre aranır ve doğrulanır.
final board = BoardLayout.of(BoardSize.standard);
const startMoney = 2500;

Room makeRoom({
  Map<String, int> positions = const {},
  Map<String, int> money = const {},
  Map<int, TileState> tiles = const {},
  int doublesInRow = 0,
  TurnPhase phase = TurnPhase.awaitingRoll,
  Set<String> jailed = const {},
  List<TradeOffer> offers = const [],
  GameSpeed speed = GameSpeed.normal,
  int? endsAtMs,
  List<String> ids = const ['a', 'b'],
}) {
  return Room(
    code: '1234',
    hostId: 'a',
    status: RoomStatus.playing,
    createdAtMs: 0,
    updatedAtMs: 0,
    players: {
      for (final (i, id) in ids.indexed)
        id: Player(
          id: id,
          name: id.toUpperCase(),
          pawn: PawnToken(PawnSymbol.values[i], PawnColor.values[i]),
          joinedAtMs: i,
          position: positions[id] ?? 0,
          money: money[id] ?? startMoney,
          inJail: jailed.contains(id),
        ),
    },
    game: GameState(
      boardSize: BoardSize.standard,
      speed: speed,
      endsAtMs: endsAtMs,
      turnOrder: ids,
      chanceDeck: [for (final c in CardData.chance) c.id],
      fundDeck: [for (final c in CardData.communityFund) c.id],
      tiles: tiles,
      doublesInRow: doublesInRow,
      phase: phase,
      offers: offers,
    ),
  );
}

int moneyOf(Room r, String id) => r.players[id]!.money;
int posOf(Room r, String id) => r.players[id]!.position;
TileState owned(int i, String owner, {int level = 0, bool mortgaged = false}) =>
    TileState(index: i, ownerId: owner, level: level, mortgaged: mortgaged);

void main() {
  // Standart harita dizilimine dayanan kareler (aşağıda doğrulanıyor).
  const bayburt = 1, ardahan = 3, tax = 5, transport = 6, chance = 10;

  test('test haritası beklenen dizilimde', () {
    expect(board.tile(bayburt).name, 'Bayburt');
    expect(board.tile(ardahan).name, 'Ardahan');
    expect(board.tile(bayburt).group, board.tile(ardahan).group);
    expect(board.tilesInGroup(board.tile(bayburt).group!).length, 2);
    expect(board.tile(tax).type, TileType.tax);
    expect(board.tile(transport).type, TileType.transport);
    expect(board.tile(chance).type, TileType.chance);
    expect(board.jailIndex, 11);
    expect(board.goToJailIndex, 33);
  });

  group('hareket', () {
    test('Başlangıç\'tan geçince maaş, boş ilde satın alma kararı', () {
      final r = GameEngine.rollDice(
          makeRoom(positions: {'a': 40}), 'a', const DiceRoll(3, 2));
      expect(posOf(r, 'a'), bayburt);
      expect(moneyOf(r, 'a'), startMoney + GameSpeed.normal.salary);
      expect(r.game!.phase, TurnPhase.awaitingBuyDecision);
    });

    test('vergi karesi', () {
      final r = GameEngine.rollDice(makeRoom(), 'a', const DiceRoll(1, 4));
      expect(posOf(r, 'a'), tax);
      expect(moneyOf(r, 'a'), startMoney - board.tile(tax).taxAmount);
      expect(r.game!.phase, TurnPhase.awaitingEndTurn);
    });

    test('Kodese Git karesi', () {
      final r = GameEngine.rollDice(
          makeRoom(positions: {'a': 30}), 'a', const DiceRoll(1, 2));
      expect(posOf(r, 'a'), board.jailIndex);
      expect(r.players['a']!.inJail, isTrue);
    });

    test('çift atınca tekrar atar', () {
      var r = GameEngine.rollDice(makeRoom(), 'a', const DiceRoll(3, 3));
      expect(posOf(r, 'a'), transport);
      r = GameEngine.declineProperty(r, 'a');
      expect(r.game!.phase, TurnPhase.awaitingRoll);
    });

    test('üst üste 3 çift = kodes', () {
      final r = GameEngine.rollDice(
          makeRoom(doublesInRow: 2), 'a', const DiceRoll(2, 2));
      expect(r.players['a']!.inJail, isTrue);
    });

    test('sırası olmayan zar atamaz', () {
      expect(() => GameEngine.rollDice(makeRoom(), 'b', const DiceRoll(1, 2)),
          throwsA(isA<GameException>()));
    });
  });

  group('satın alma ve kira', () {
    test('satın al', () {
      var r = GameEngine.rollDice(makeRoom(), 'a', const DiceRoll(1, 2));
      r = GameEngine.buyProperty(r, 'a');
      expect(r.game!.tileState(ardahan).ownerId, 'a');
      expect(moneyOf(r, 'a'), startMoney - board.tile(ardahan).price);
    });

    test('kira; grubun tamamı tek kişideyse boş arsa kirası 2 kat', () {
      final base = board.tile(ardahan).rents[0];
      var r = GameEngine.rollDice(makeRoom(tiles: {ardahan: owned(ardahan, 'b')}),
          'a', const DiceRoll(1, 2));
      expect(moneyOf(r, 'a'), startMoney - base);
      expect(moneyOf(r, 'b'), startMoney + base);

      r = GameEngine.rollDice(
        makeRoom(tiles: {
          bayburt: owned(bayburt, 'b'),
          ardahan: owned(ardahan, 'b'),
        }),
        'a',
        const DiceRoll(1, 2),
      );
      expect(moneyOf(r, 'a'), startMoney - 2 * base);
    });

    test('ipotekli ilden kira alınmaz', () {
      final r = GameEngine.rollDice(
        makeRoom(tiles: {ardahan: owned(ardahan, 'b', mortgaged: true)}),
        'a',
        const DiceRoll(1, 2),
      );
      expect(moneyOf(r, 'a'), startMoney);
    });

    test('ödeyemeyen oyuncu borç aşamasına geçer', () {
      final rent = board.tile(ardahan).rents[3];
      final r = GameEngine.rollDice(
        makeRoom(
          money: {'a': 10},
          tiles: {
            bayburt: owned(bayburt, 'b', level: 3),
            ardahan: owned(ardahan, 'b', level: 3),
          },
        ),
        'a',
        const DiceRoll(1, 2),
      );
      expect(moneyOf(r, 'a'), 10 - rent);
      expect(r.game!.phase, TurnPhase.awaitingDebtResolution);
      expect(() => GameEngine.endTurn(r, 'a'), throwsA(isA<GameException>()));
    });
  });

  group('inşaat', () {
    final group = {bayburt: owned(bayburt, 'a'), ardahan: owned(ardahan, 'a')};

    test('eşit dağılım kuralı', () {
      var r = makeRoom(tiles: group);
      r = GameEngine.buildHouse(r, 'a', bayburt);
      expect(() => GameEngine.buildHouse(r, 'a', bayburt),
          throwsA(isA<GameException>()));
      r = GameEngine.buildHouse(r, 'a', ardahan);
      r = GameEngine.buildHouse(r, 'a', bayburt);
      expect(r.game!.tileState(bayburt).level, 2);
      expect(moneyOf(r, 'a'), startMoney - 3 * board.tile(bayburt).houseCost);
    });

    test('grubun tamamı yoksa inşaat yok', () {
      final r = makeRoom(tiles: {bayburt: owned(bayburt, 'a')});
      expect(GameEngine.buildError(r, 'a', bayburt), isNotNull);
    });
  });

  group('kodes', () {
    test('3. denemede kefaletle çıkar', () {
      var r = makeRoom(positions: {'a': 11}, jailed: {'a'});
      r = GameEngine.rollDice(r, 'a', const DiceRoll(1, 2));
      expect(r.players['a']!.jailTurns, 1);
      r = r.copyWith(
        players: {...r.players, 'a': r.players['a']!.copyWith(jailTurns: 2)},
        game: r.game!.copyWith(phase: TurnPhase.awaitingRoll),
      );
      r = GameEngine.rollDice(r, 'a', const DiceRoll(1, 2));
      expect(r.players['a']!.inJail, isFalse);
      expect(posOf(r, 'a'), 14);
      expect(moneyOf(r, 'a'), startMoney - GameRules.jailBail);
    });

    test('kefalet', () {
      final r = GameEngine.payBail(
          makeRoom(positions: {'a': 11}, jailed: {'a'}), 'a');
      expect(r.players['a']!.inJail, isFalse);
      expect(r.game!.phase, TurnPhase.awaitingRoll);
    });
  });

  group('sıra, kart ve iflas', () {
    test('sırayı devret', () {
      var r = GameEngine.rollDice(makeRoom(), 'a', const DiceRoll(1, 4));
      r = GameEngine.endTurn(r, 'a');
      expect(r.game!.currentPlayerId, 'b');
    });

    test('kart çekilir, onaylanınca uygulanır', () {
      var r = GameEngine.rollDice(
          makeRoom(positions: {'a': chance - 2}), 'a', const DiceRoll(1, 1));
      expect(r.game!.phase, TurnPhase.showingCard);
      expect(r.game!.activeCardId, 101); // "Başlangıç'a ilerle"
      r = GameEngine.acknowledgeCard(r, 'a');
      expect(posOf(r, 'a'), 0);
      expect(moneyOf(r, 'a'), startMoney + GameSpeed.normal.salary);
    });

    test('şehre ilerle kartı haritadaki ile gider', () {
      final r = makeRoom(phase: TurnPhase.showingCard);
      final withCard = r.copyWith(
          game: r.game!.copyWith(activeCardId: 105)); // Ankara
      final after = GameEngine.acknowledgeCard(withCard, 'a');
      expect(board.tile(posOf(after, 'a')).name, 'Ankara');
    });

    test('iflas eden çıkar, son kalan kazanır, teklifleri silinir', () {
      final r = GameEngine.declareBankruptcy(
        makeRoom(
          money: {'a': -50},
          tiles: {bayburt: owned(bayburt, 'a')},
          phase: TurnPhase.awaitingDebtResolution,
          offers: [
            const TradeOffer(
                id: 'x', fromId: 'a', toId: 'b', requestedTiles: [],
                offeredTiles: [bayburt], cash: 0, createdAtMs: 0),
          ],
        ),
        'a',
      );
      expect(r.players['a']!.isBankrupt, isTrue);
      expect(r.game!.tileState(bayburt).isOwned, isFalse);
      expect(r.game!.offers, isEmpty);
      expect(r.status, RoomStatus.finished);
      expect(r.game!.winnerId, 'b');
    });
  });

  group('açık artırma', () {
    Room auctionRoom() => GameEngine.startAuction(
        makeRoom(tiles: {bayburt: owned(bayburt, 'a')}), 'a', bayburt, 100, 0);

    test('başlar, teklif alır, süre dolunca en yüksek teklife satılır', () {
      var r = auctionRoom();
      expect(r.game!.auction!.endsAtMs,
          GameRules.auctionDuration.inMilliseconds);

      expect(() => GameEngine.placeBid(r, 'a', 200, 1000),
          throwsA(isA<GameException>())); // satıcı teklif veremez
      expect(() => GameEngine.placeBid(r, 'b', 50, 1000),
          throwsA(isA<GameException>())); // başlangıçtan düşük

      r = GameEngine.placeBid(r, 'b', 150, 1000);
      expect(r.game!.auction!.highestBid, 150);

      // Müzayede sürerken zar atılamaz.
      expect(() => GameEngine.rollDice(r, 'a', const DiceRoll(1, 2)),
          throwsA(isA<GameException>()));

      // Erken sonuçlandırma hiçbir şeyi değiştirmez.
      expect(identical(GameEngine.finalizeAuction(r, 2000), r), isTrue);

      r = GameEngine.finalizeAuction(r, 20000);
      expect(r.game!.auction, isNull);
      expect(r.game!.tileState(bayburt).ownerId, 'b');
      expect(moneyOf(r, 'b'), startMoney - 150);
      expect(moneyOf(r, 'a'), startMoney + 150);
    });

    test('her teklif kalan süreyi en az 5 saniyeye çıkarır', () {
      var r = auctionRoom();
      r = GameEngine.placeBid(r, 'b', 100, 13000);
      expect(r.game!.auction!.endsAtMs,
          13000 + GameRules.auctionBidReset.inMilliseconds);
    });

    test('teklif gelmezse tapu sahibinde kalır', () {
      final r = GameEngine.finalizeAuction(auctionRoom(), 20000);
      expect(r.game!.auction, isNull);
      expect(r.game!.tileState(bayburt).ownerId, 'a');
    });

    test('grubunda bina olan il açık artırmaya çıkamaz', () {
      final r = makeRoom(tiles: {
        bayburt: owned(bayburt, 'a', level: 1),
        ardahan: owned(ardahan, 'a', level: 1),
      });
      expect(GameEngine.auctionStartError(r, 'a', bayburt), isNotNull);
    });
  });

  group('teklif ve takas', () {
    TradeOffer offer({
      String id = 'o1',
      String from = 'a',
      String to = 'b',
      List<int> requested = const [ardahan],
      List<int> offered = const [bayburt],
      int cash = 50,
      String? counterOf,
    }) =>
        TradeOffer(
          id: id,
          fromId: from,
          toId: to,
          requestedTiles: requested,
          offeredTiles: offered,
          cash: cash,
          createdAtMs: 0,
          counterOf: counterOf,
        );

    Room tradeRoom() => makeRoom(tiles: {
          bayburt: owned(bayburt, 'a'),
          ardahan: owned(ardahan, 'b'),
        });

    test('kabul edilince tapular ve para el değiştirir', () {
      var r = GameEngine.sendOffer(tradeRoom(), offer());
      expect(r.game!.offers.length, 1);
      expect(() => GameEngine.acceptOffer(r, 'a', 'o1'),
          throwsA(isA<GameException>())); // gönderen kabul edemez
      r = GameEngine.acceptOffer(r, 'b', 'o1');
      expect(r.game!.tileState(ardahan).ownerId, 'a');
      expect(r.game!.tileState(bayburt).ownerId, 'b');
      expect(moneyOf(r, 'a'), startMoney - 50);
      expect(moneyOf(r, 'b'), startMoney + 50);
      expect(r.game!.offers, isEmpty);
    });

    test('red ve karşı teklif', () {
      var r = GameEngine.sendOffer(tradeRoom(), offer());
      r = GameEngine.sendOffer(
          r,
          offer(id: 'o2', from: 'b', to: 'a', requested: [bayburt],
              offered: [ardahan], cash: -120, counterOf: 'o1'));
      expect(r.game!.offers.map((o) => o.id), ['o2']);
      r = GameEngine.rejectOffer(r, 'a', 'o2');
      expect(r.game!.offers, isEmpty);
    });

    test('binalı gruptan il takas edilemez', () {
      final r = makeRoom(tiles: {
        bayburt: owned(bayburt, 'b', level: 1),
        ardahan: owned(ardahan, 'b', level: 1),
      });
      expect(
          () => GameEngine.sendOffer(
              r, offer(requested: [bayburt], offered: [], cash: 500)),
          throwsA(isA<GameException>()));
    });

    test('parası yetmeyen teklif geçersiz', () {
      expect(
          GameEngine.offerError(
              makeRoom(money: {'a': 10}, tiles: {ardahan: owned(ardahan, 'b')}),
              offer(offered: [], cash: 100)),
          isNotNull);
    });
  });

  group('oyun hızı', () {
    test('mod ayarları', () {
      expect(GameSpeed.fast.startingMoney, 1500);
      expect(GameSpeed.fast.salary, 150);
      expect(GameSpeed.normal.startingMoney, 2500);
      expect(GameSpeed.marathon.startingMoney, 4000);
      expect(GameSpeed.marathon.salary, 300);
      expect(GameSpeed.marathon.boardFor(2), BoardSize.giant);
      expect(GameSpeed.fast.boardFor(2), BoardSize.compact);
      expect(const GameSettings(speed: GameSpeed.fast).timeLimit,
          const Duration(minutes: 25));
      expect(const GameSettings().timeLimit, isNull);
      expect(const GameSettings(timerEnabled: true).timeLimit,
          const Duration(minutes: 60));
      expect(const GameSettings(speed: GameSpeed.marathon, timerEnabled: true)
          .timeLimit, isNull);
    });

    test('hızlı modda maaş 150M', () {
      final r = GameEngine.rollDice(
          makeRoom(positions: {'a': 40}, speed: GameSpeed.fast),
          'a',
          const DiceRoll(3, 2));
      expect(moneyOf(r, 'a'), startMoney + 150);
    });

    test('hızlı modda tek ile bina dikilir, eşit dağılım yok', () {
      var r = makeRoom(
          tiles: {bayburt: owned(bayburt, 'a')}, speed: GameSpeed.fast);
      expect(GameEngine.buildError(r, 'a', bayburt), isNull);
      r = GameEngine.buildHouse(r, 'a', bayburt);
      r = GameEngine.buildHouse(r, 'a', bayburt);
      expect(r.game!.tileState(bayburt).level, 2);
      // Kira seviyeye göre alınır
      expect(GameEngine.displayRent(r.game!, bayburt),
          board.tile(bayburt).rents[2]);
      // Binalı ilin kendisi ipotek edilemez, aynı gruptaki boş il edilebilir
      r = r.copyWith(game: r.game!.copyWith(tiles: {
        ...r.game!.tiles,
        ardahan: owned(ardahan, 'a'),
      }));
      expect(GameEngine.mortgageError(r, 'a', bayburt), isNotNull);
      expect(GameEngine.mortgageError(r, 'a', ardahan), isNull);
    });

    test('normal modda tek ile bina dikilemez', () {
      final r = makeRoom(tiles: {bayburt: owned(bayburt, 'a')});
      expect(GameEngine.buildError(r, 'a', bayburt), isNotNull);
    });

    test('hızlı modda ilk iflasta oyun biter, Net Varlık en yüksek kazanır', () {
      final r = GameEngine.declareBankruptcy(
        makeRoom(
          ids: ['a', 'b', 'c'],
          money: {'a': -10, 'b': 1000, 'c': 900},
          tiles: {ardahan: owned(ardahan, 'c', level: 2)},
          speed: GameSpeed.fast,
          phase: TurnPhase.awaitingDebtResolution,
        ),
        'a',
      );
      expect(r.status, RoomStatus.finished);
      expect(r.game!.endReason, GameEndReason.firstBankruptcy);
      // c: 900 + tapu + 2 ev > b: 1000
      final c = GameEngine.netWorthOf(r.game!, r.players['c']!);
      expect(c.total,
          900 + board.tile(ardahan).price + 2 * board.tile(ardahan).houseCost);
      expect(r.game!.winnerId, 'c');
    });

    test('normal modda ilk iflasta oyun sürer', () {
      final r = GameEngine.declareBankruptcy(
        makeRoom(
          ids: ['a', 'b', 'c'],
          money: {'a': -10},
          phase: TurnPhase.awaitingDebtResolution,
        ),
        'a',
      );
      expect(r.status, RoomStatus.playing);
      expect(r.game!.currentPlayerId, 'b');
    });

    test('süre dolunca Net Varlıkla biter, önce dolmaz', () {
      final room = makeRoom(
        money: {'a': 100, 'b': 3000},
        speed: GameSpeed.fast,
        endsAtMs: 10000,
      );
      expect(identical(GameEngine.finishByTime(room, 9999), room), isTrue);
      final r = GameEngine.finishByTime(room, 10000);
      expect(r.status, RoomStatus.finished);
      expect(r.game!.endReason, GameEndReason.timeUp);
      expect(r.game!.winnerId, 'b');
    });

    test('ipotekli tapu Net Varlıkta ipotek düşülerek sayılır', () {
      final r = makeRoom(
          money: {'a': 0},
          tiles: {ardahan: owned(ardahan, 'a', mortgaged: true)});
      final tile = board.tile(ardahan);
      expect(GameEngine.netWorthOf(r.game!, r.players['a']!).total,
          tile.price - tile.mortgageValue);
    });
  });
}
