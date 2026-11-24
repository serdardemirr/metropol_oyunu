import 'dart:math';

import '../models/models.dart';

/// Bekleme odasına eklenecek bot oyuncuları üretir.
/// Firebase'e dokunmaz; test edilebilir.
class BotFactory {
  BotFactory._();

  static const List<String> names = [
    'Bot Ayşe', 'Bot Mehmet', 'Bot Zeynep', 'Bot Can',
    'Bot Elif', 'Bot Emre', 'Bot Deniz', 'Bot Selin',
  ];

  static final Random _defaultRandom = Random();

  /// Odadaki isim, piyon sembolü ve renkle çakışmayan yeni bir bot.
  static Player create(Room room, {required int now, Random? random}) {
    final rnd = random ?? _defaultRandom;
    final takenNames =
        room.players.values.map((p) => p.name.toLowerCase()).toSet();
    final freeNames =
        names.where((n) => !takenNames.contains(n.toLowerCase())).toList();
    var name =
        freeNames.isNotEmpty ? freeNames[rnd.nextInt(freeNames.length)] : 'Bot';
    for (var n = 2; takenNames.contains(name.toLowerCase()); n++) {
      name = 'Bot $n';
    }

    final start = PawnToken(
      PawnSymbol.values[rnd.nextInt(PawnSymbol.values.length)],
      PawnColor.values[rnd.nextInt(PawnColor.values.length)],
    );
    final pawn = start.resolveAgainst(room.players.values.map((p) => p.pawn));

    String newId() => 'bot_${now}_${rnd.nextInt(1 << 20)}';
    var id = newId();
    while (room.players.containsKey(id)) {
      id = newId();
    }

    // Aynı milisaniyede eklenen botların sırası bozulmasın diye en sona koy.
    final lastJoin = room.players.values
        .map((p) => p.joinedAtMs)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Player(
      id: id,
      name: name,
      pawn: pawn,
      joinedAtMs: now > lastJoin ? now : lastJoin + 1,
      isBot: true,
    );
  }
}
