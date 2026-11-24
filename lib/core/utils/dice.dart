import 'dart:math';

/// İki zarlık bir atış.
class DiceRoll {
  final int die1;
  final int die2;

  const DiceRoll(this.die1, this.die2)
      : assert(die1 >= 1 && die1 <= 6),
        assert(die2 >= 1 && die2 <= 6);

  int get total => die1 + die2;
  bool get isDouble => die1 == die2;

  Map<String, dynamic> toMap() => {'d1': die1, 'd2': die2};

  factory DiceRoll.fromMap(Map<String, dynamic> map) =>
      DiceRoll((map['d1'] as num).toInt(), (map['d2'] as num).toInt());

  @override
  String toString() => '$die1+$die2=$total';

  @override
  bool operator ==(Object other) =>
      other is DiceRoll && other.die1 == die1 && other.die2 == die2;

  @override
  int get hashCode => Object.hash(die1, die2);
}

/// Zar üretici. Testlerde sabit sonuç verebilmek için [Random] enjekte edilebilir.
class Dice {
  final Random _random;

  Dice([Random? random]) : _random = random ?? Random.secure();

  int rollOne() => _random.nextInt(6) + 1;

  DiceRoll roll() => DiceRoll(rollOne(), rollOne());
}
