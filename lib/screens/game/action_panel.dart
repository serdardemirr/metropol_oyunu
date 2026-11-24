import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/game_rules.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';

/// Alt eylem paneli: aşamaya göre doğru düğmeleri gösterir.
class ActionPanel extends StatelessWidget {
  const ActionPanel({
    super.key,
    required this.room,
    required this.myId,
    required this.busy,
    required this.run,
    required this.onOpenProperties,
  });

  final Room room;
  final String myId;
  final bool busy;
  final Future<void> Function(Future<void> Function() action) run;
  final VoidCallback onOpenProperties;

  @override
  Widget build(BuildContext context) {
    final game = room.game;
    final me = room.players[myId];
    if (game == null || me == null) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _content(context, game, me),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, GameState game, Player me) {
    final repo = AppServices.game;
    final code = room.code;
    final isMyTurn = game.currentPlayerId == myId;
    final current = room.players[game.currentPlayerId];

    if (room.status == RoomStatus.finished || game.phase == TurnPhase.gameOver) {
      final w = room.players[game.winnerId];
      return _info(context, Icons.emoji_events,
          w == null ? 'Oyun bitti.' : 'Oyun bitti! Kazanan: ${w.name}');
    }
    if (me.isBankrupt) {
      return _info(context, Icons.visibility, 'İflas ettin — oyunu izliyorsun.');
    }
    if (game.auction != null) {
      return _info(context, Icons.gavel,
          'Müzayede sürüyor — sonuçlanınca oyun devam eder.');
    }

    // Borç: kimin sırası olursa olsun önce bu çözülmeli.
    if (me.money < 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Borcun var: ${-me.money}M\nBina sat ya da arsa ipotek ettir.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onOpenProperties,
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Mülklerim'),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent),
                  onPressed: busy
                      ? null
                      : () => _confirmBankruptcy(context,
                          () => run(() => repo.declareBankruptcy(code, myId))),
                  icon: const Icon(Icons.money_off),
                  label: const Text('İflas Et'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final propertiesButton = IconButton.filledTonal(
      tooltip: 'Mülklerim (inşaat / ipotek)',
      onPressed: busy ? null : onOpenProperties,
      icon: const Icon(Icons.home_work),
    );

    if (!isMyTurn) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '${current?.name ?? '?'} oynuyor...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          propertiesButton,
        ],
      );
    }

    switch (game.phase) {
      case TurnPhase.awaitingRoll:
        if (me.inJail) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kodestesin (${me.jailTurns}/${GameRules.maxJailTurns}). Ne yapacaksın?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                spacing: 6,
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => _roll(code),
                      child: const Text('Çift Dene', textAlign: TextAlign.center),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: busy || me.money < GameRules.jailBail
                          ? null
                          : () => run(() => repo.payBail(code, myId)),
                      child: const Text('Kefalet ${GameRules.jailBail}M',
                          textAlign: TextAlign.center),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy || me.jailFreeCards == 0
                          ? null
                          : () => run(() => repo.useJailCard(code, myId)),
                      child: Text('Kart Kullan (${me.jailFreeCards})',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          spacing: 8,
          children: [
            propertiesButton,
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: busy ? null : () => _roll(code),
                icon: const Icon(Icons.casino, size: 30),
                label: Text(
                  game.doublesInRow > 0 ? 'ÇİFT! TEKRAR AT' : 'ZAR AT',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );

      case TurnPhase.awaitingBuyDecision:
        return _info(context, Icons.description, 'Tapu kartından kararını ver.');

      case TurnPhase.showingCard:
        return _info(context, Icons.style, 'Kartı okuyup onayla.');

      case TurnPhase.awaitingDebtResolution:
        return _info(context, Icons.hourglass_bottom, 'Devam ediliyor...');

      case TurnPhase.awaitingEndTurn:
        return Row(
          spacing: 8,
          children: [
            propertiesButton,
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: busy ? null : () => run(() => repo.endTurn(code, myId)),
                icon: const Icon(Icons.skip_next),
                label: const Text('Sırayı Devret',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        );

      case TurnPhase.gameOver:
        return _info(context, Icons.emoji_events, 'Oyun bitti.');
    }
  }

  void _roll(String code) {
    HapticFeedback.mediumImpact();
    run(() => AppServices.game.rollDice(code, myId));
  }

  Widget _info(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }

  Future<void> _confirmBankruptcy(
      BuildContext context, VoidCallback onConfirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İflas etmek istediğine emin misin?'),
        content: const Text(
            'Oyundan çıkarsın ve tüm mülklerin bankaya döner. Geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('İflas Et')),
        ],
      ),
    );
    if (ok == true) onConfirm();
  }
}
