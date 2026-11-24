import 'dart:math';

import '../constants/game_rules.dart';

class RoomCode {
  RoomCode._();

  static final Random _random = Random.secure();

  /// 1000-9999 arasında 4 haneli kod üretir (başında 0 olmaz, okunması kolay).
  static String generate() {
    final min = pow(10, GameRules.roomCodeLength - 1).toInt();
    final max = pow(10, GameRules.roomCodeLength).toInt();
    return (min + _random.nextInt(max - min)).toString();
  }

  static bool isValid(String code) =>
      RegExp('^[1-9][0-9]{${GameRules.roomCodeLength - 1}}\$').hasMatch(code);
}
