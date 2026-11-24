import 'dart:math';

import '../core/constants/game_rules.dart';
import '../data/board_layout.dart';
import '../data/card_data.dart';
import '../models/models.dart';

/// Zar düellosu bittiğinde oyunun başlangıç durumunu kurar.
class GameInitializer {
  GameInitializer._();

  static GameState create(
    List<String> turnOrder,
    Map<String, Player> players, {
    required BoardSize boardSize,
    required GameSettings settings,
    required int nowMs,
    Random? random,
  }) {
    final rnd = random ?? Random.secure();
    final first = players[turnOrder.first]?.name ?? 'Oyuncu';
    final layout = BoardLayout.of(boardSize);
    final limit = settings.timeLimit;
    return GameState(
      boardSize: boardSize,
      speed: settings.speed,
      startedAtMs: nowMs,
      endsAtMs: limit == null ? null : nowMs + limit.inMilliseconds,
      turnOrder: List.unmodifiable(turnOrder),
      chanceDeck: CardData.shuffledIds(CardDeck.chance, rnd),
      fundDeck: CardData.shuffledIds(CardDeck.communityFund, rnd),
    ).addLog(
        '${settings.speed.emoji} ${settings.speed.label} · ${boardSize.label} '
        '(${layout.length} kare)'
        '${limit == null ? '' : ' · ${limit.inMinutes} dk'} başladı! '
        'İlk hamle $first oyuncusunda.');
  }

  /// Tüm oyuncuları başlangıç parasına ve konumuna sıfırlar.
  static Map<String, Player> resetPlayers(
    Map<String, Player> players, [
    int startingMoney = GameRules.startingMoney,
  ]) {
    return {
      for (final e in players.entries)
        e.key: e.value.resetForNewGame(startingMoney),
    };
  }
}
