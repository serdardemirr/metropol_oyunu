import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/dice.dart';
import '../models/models.dart';
import '../services/app_services.dart';
import '../services/room_repository.dart';
import '../widgets/dice_face.dart';
import '../widgets/pawn_avatar.dart';

/// Zar Düellosu: sırayla zar atılır, eşitlikte sadece berabere kalanlar
/// tekrar atar. Sıralama kesinleşince oda otomatik "playing" durumuna geçer.
class OrderDuelView extends StatefulWidget {
  const OrderDuelView({super.key, required this.room, required this.myId});

  final Room room;
  final String myId;

  @override
  State<OrderDuelView> createState() => _OrderDuelViewState();
}

class _OrderDuelViewState extends State<OrderDuelView> {
  final _rnd = Random();
  bool _rolling = false;
  DiceRoll? _shown; // ekrandaki zar
  Timer? _shuffle;

  @override
  void didUpdateWidget(covariant OrderDuelView old) {
    super.didUpdateWidget(old);
    // Başka bir oyuncu attığında onun zarını göster.
    final duel = widget.room.orderDuel;
    final last = duel?.lastRoll;
    final isNewRoll =
        duel?.history.length != old.room.orderDuel?.history.length;
    if (!_rolling && last != null && isNewRoll) {
      HapticFeedback.lightImpact();
      _shown = last.roll; // build zaten bu güncellemeden sonra çalışır
    }
  }

  @override
  void dispose() {
    _shuffle?.cancel();
    super.dispose();
  }

  Future<void> _roll() async {
    HapticFeedback.mediumImpact();
    setState(() => _rolling = true);

    // Sunucu yanıtı gelene kadar zarlar "döner".
    _shuffle = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) {
        setState(() =>
            _shown = DiceRoll(_rnd.nextInt(6) + 1, _rnd.nextInt(6) + 1));
      }
    });

    try {
      final results = await Future.wait<Object?>([
        AppServices.rooms.rollForOrder(code: widget.room.code, uid: widget.myId),
        Future<void>.delayed(const Duration(milliseconds: 900)),
      ]);
      _shuffle?.cancel();
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _shown = results.first as DiceRoll);
    } on RoomException catch (e) {
      _shuffle?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      _shuffle?.cancel();
      if (mounted) setState(() => _rolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final duel = room.orderDuel;
    if (duel == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final rollerId = duel.currentRollerId;
    final roller = rollerId == null ? null : room.players[rollerId];
    final myTurn = rollerId == widget.myId;
    final activeIds = duel.activeGroup.toSet();

    return Column(
      children: [
        const SizedBox(height: 16),
        Text('Zar Düellosu', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('En yüksek atan oyuna ilk başlar',
            style: theme.textTheme.bodySmall),
        if (duel.isTieBreak) ...[
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Eşitlik! ${duel.activeGroup.map((id) => room.players[id]?.name ?? '?').join(', ')} '
              'kendi aralarında tekrar atıyor.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DiceFace(value: _shown?.die1 ?? 0, size: 72),
            const SizedBox(width: 20),
            DiceFace(value: _shown?.die2 ?? 0, size: 72),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _shown == null ? '' : 'Toplam: ${_shown!.total}',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (final p in room.playersByJoinOrder)
                _DuelRow(
                  player: p,
                  isMe: p.id == widget.myId,
                  isRolling: p.id == rollerId,
                  inActiveGroup: activeIds.contains(p.id),
                  currentRoll: duel.currentRolls[p.id],
                  lastRoll: duel.lastRollOf(p.id),
                  rank: _rankOf(duel, p.id),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: myTurn
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64)),
                  onPressed: _rolling ? null : _roll,
                  icon: const Icon(Icons.casino, size: 32),
                  label: const Text('ZAR AT', style: TextStyle(fontSize: 22)),
                )
              : Text(
                  roller == null
                      ? 'Sıralama hesaplanıyor...'
                      : '${roller.name} zar atıyor...',
                  style: theme.textTheme.titleMedium,
                ),
        ),
      ],
    );
  }

  /// Sırası kesinleşmiş oyuncunun sırası (1'den başlar); belirsizse null.
  int? _rankOf(OrderDuel duel, String id) {
    var rank = 1;
    for (final g in duel.groups) {
      if (g.contains(id)) return g.length == 1 ? rank : null;
      rank += g.length;
    }
    return null;
  }
}

class _DuelRow extends StatelessWidget {
  const _DuelRow({
    required this.player,
    required this.isMe,
    required this.isRolling,
    required this.inActiveGroup,
    required this.currentRoll,
    required this.lastRoll,
    required this.rank,
  });

  final Player player;
  final bool isMe;
  final bool isRolling;
  final bool inActiveGroup;
  final DiceRoll? currentRoll;
  final DiceRoll? lastRoll;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final shownRoll = currentRoll ?? lastRoll;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isRolling
            ? player.pawn.color.withValues(alpha: 0.25)
            : Colors.transparent,
        border: Border.all(
          color: inActiveGroup ? player.pawn.color : Colors.white12,
        ),
      ),
      child: ListTile(
        leading: PawnAvatar(pawn: player.pawn, dimmed: !inActiveGroup && rank == null),
        title: Text(isMe ? '${player.name} (sen)' : player.name),
        subtitle: Text(
          rank != null
              ? 'Sıra: $rank.'
              : isRolling
                  ? 'Zar atıyor...'
                  : inActiveGroup
                      ? (currentRoll == null ? 'Bekliyor' : 'Attı')
                      : 'Bekliyor',
        ),
        trailing: Text(
          shownRoll?.total.toString() ?? '-',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
