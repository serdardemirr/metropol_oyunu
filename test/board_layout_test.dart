import 'package:flutter_test/flutter_test.dart';
import 'package:metropol/data/board_layout.dart';
import 'package:metropol/data/card_data.dart';
import 'package:metropol/data/cities_data.dart';
import 'package:metropol/models/models.dart';

void main() {
  test('81 il eksiksiz ve tekrarsız', () {
    final plates = CitiesData.all.map((c) => c.plate).toSet();
    expect(plates.length, 81);
    expect(plates, Set.of(List.generate(81, (i) => i + 1)));
    expect(CitiesData.all.map((c) => c.name).toSet().length, 81);
    expect([for (final c in CitiesData.all) c.rank],
        List.generate(81, (i) => i + 1));
  });

  test('oyuncu sayısına göre harita', () {
    expect(BoardSize.forPlayerCount(2), BoardSize.compact);
    expect(BoardSize.forPlayerCount(3), BoardSize.compact);
    expect(BoardSize.forPlayerCount(4), BoardSize.standard);
    expect(BoardSize.forPlayerCount(5), BoardSize.standard);
    expect(BoardSize.forPlayerCount(6), BoardSize.giant);
    expect(BoardSize.forPlayerCount(8), BoardSize.giant);
  });

  const expected = {
    BoardSize.compact: (28, 16),
    BoardSize.standard: (44, 25),
    BoardSize.giant: (108, 81),
  };

  for (final size in BoardSize.values) {
    group(size.name, () {
      final board = BoardLayout.of(size);

      test('kare ve il sayısı', () {
        final (tiles, cities) = expected[size]!;
        expect(board.length, tiles);
        expect(
            board.tiles.where((t) => t.type == TileType.property).length, cities);
        for (var i = 0; i < board.length; i++) {
          expect(board.tiles[i].index, i);
        }
      });

      test('köşeler doğru yerde', () {
        expect(board.tile(0).type, TileType.start);
        expect(board.tile(board.jailIndex).type, TileType.jail);
        expect(board.tile(board.freeParkingIndex).type, TileType.freeParking);
        expect(board.tile(board.goToJailIndex).type, TileType.goToJail);
      });

      test('iller ucuzdan pahalıya dizili, ekonomi tutarlı', () {
        final cities =
            board.tiles.where((t) => t.type == TileType.property).toList();
        expect(cities.first.name, 'Bayburt');
        expect(cities.last.name, 'İstanbul');
        for (var i = 1; i < cities.length; i++) {
          expect(cities[i].group!.id, greaterThanOrEqualTo(cities[i - 1].group!.id));
          if (cities[i].group != cities[i - 1].group) {
            expect(cities[i].price, greaterThan(cities[i - 1].price),
                reason: '${cities[i].name} pahalı olmalı');
          }
        }
        for (final c in cities) {
          expect(c.rents.length, 6);
          for (var k = 1; k < 6; k++) {
            expect(c.rents[k], greaterThan(c.rents[k - 1]),
                reason: '${c.name} kirası her seviyede artmalı');
          }
          expect(c.houseCost, inInclusiveRange(50, 200));
        }
      });

      test('kart hedefleri bu haritada var', () {
        for (final c in [...CardData.chance, ...CardData.communityFund]) {
          if (c.targetCity != null) {
            expect(board.indexOfCity(c.targetCity!), isNotNull,
                reason: '${c.targetCity} ${size.name} haritasında yok');
          }
        }
      });
    });
  }

  test('kart id\'leri benzersiz', () {
    final all = [...CardData.chance, ...CardData.communityFund];
    expect(all.map((c) => c.id).toSet().length, all.length);
  });

  test('piyon çakışması çözülür', () {
    const taken = [
      PawnToken(PawnSymbol.car, PawnColor.red),
      PawnToken(PawnSymbol.plane, PawnColor.blue),
    ];
    final p = const PawnToken(PawnSymbol.car, PawnColor.blue)
        .resolveAgainst(taken);
    expect(p.symbol, isNot(anyOf(PawnSymbol.car, PawnSymbol.plane)));
    expect(p.tint, isNot(anyOf(PawnColor.red, PawnColor.blue)));
    const free = PawnToken(PawnSymbol.anchor, PawnColor.pink);
    expect(free.resolveAgainst(taken), free);
  });
}
