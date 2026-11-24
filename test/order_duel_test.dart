import 'package:flutter_test/flutter_test.dart';
import 'package:metropol/core/utils/dice.dart';
import 'package:metropol/models/order_duel.dart';

DiceRoll r(int total) =>
    total <= 7 ? DiceRoll(1, total - 1) : DiceRoll(6, total - 6);

void main() {
  group('OrderDuel', () {
    test('farklı zarlar tek turda sıralamayı belirler', () {
      var d = OrderDuel.start(['a', 'b', 'c']);
      expect(d.currentRollerId, 'a');
      d = d.applyRoll('a', r(5));
      d = d.applyRoll('b', r(11));
      d = d.applyRoll('c', r(8));
      expect(d.isComplete, isTrue);
      expect(d.finalOrder, ['b', 'c', 'a']);
    });

    test('sadece berabere kalanlar tekrar atar', () {
      var d = OrderDuel.start(['a', 'b', 'c', 'd']);
      d = d.applyRoll('a', r(9));
      d = d.applyRoll('b', r(4));
      d = d.applyRoll('c', r(9));
      d = d.applyRoll('d', r(4));

      expect(d.isComplete, isFalse);
      expect(d.activeGroup, ['a', 'c']); // önce en yüksek eşitlik
      expect(d.isTieBreak, isTrue);
      expect(() => d.applyRoll('b', r(12)), throwsStateError);

      d = d.applyRoll('a', r(3));
      d = d.applyRoll('c', r(10));
      expect(d.activeGroup, ['b', 'd']); // sonra alttaki eşitlik

      d = d.applyRoll('b', r(7));
      d = d.applyRoll('d', r(8));
      expect(d.isComplete, isTrue);
      expect(d.finalOrder, ['c', 'a', 'd', 'b']);
    });

    test('herkes aynı atarsa tüm grup tekrar atar', () {
      var d = OrderDuel.start(['a', 'b']);
      d = d.applyRoll('a', r(6));
      d = d.applyRoll('b', r(6));
      expect(d.activeGroup, ['a', 'b']);
      expect(d.currentRollerId, 'a');
      d = d.applyRoll('a', r(2));
      d = d.applyRoll('b', r(3));
      expect(d.finalOrder, ['b', 'a']);
    });

    test('sırası olmayan oyuncu atamaz', () {
      final d = OrderDuel.start(['a', 'b']);
      expect(() => d.applyRoll('b', r(6)), throwsStateError);
    });

    test('toMap/fromMap gidiş-dönüş', () {
      var d = OrderDuel.start(['a', 'b', 'c']);
      d = d.applyRoll('a', r(6)).applyRoll('b', r(6)).applyRoll('c', r(2));
      final back = OrderDuel.fromMap(d.toMap());
      expect(back.groups, d.groups);
      expect(back.round, d.round);
      expect(back.history.length, 3);
      expect(back.currentRollerId, 'a');
    });

    test('düellodan ayrılan oyuncu çıkarılır', () {
      var d = OrderDuel.start(['a', 'b', 'c']);
      d = d.applyRoll('a', r(6));
      d = d.removePlayer('b');
      expect(d.activeGroup, ['a', 'c']);
      expect(d.currentRollerId, 'c');
    });
  });
}
