import 'package:flutter/material.dart';

import '../models/models.dart';
import 'pawn_avatar.dart';

/// Zar düellosu sonunda gösterilen sıralama tablosu.
class RankingTable extends StatelessWidget {
  const RankingTable({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final duel = room.orderDuel;
    final order = room.game?.turnOrder ?? duel?.finalOrder ?? const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < order.length; i++)
          if (room.players[order[i]] case final p?)
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 72,
                child: Row(
                  children: [
                    Text(
                      '${i + 1}.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 8),
                    PawnAvatar(pawn: p.pawn, size: 32),
                  ],
                ),
              ),
              title: Text(p.name),
              trailing: Text(
                duel?.lastRollOf(p.id)?.total.toString() ?? '-',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
      ],
    );
  }
}
