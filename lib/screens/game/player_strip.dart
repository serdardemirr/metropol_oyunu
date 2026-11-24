import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/voice_chat_service.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/pawn_avatar.dart';

/// Üstteki oyuncu şeridi: sıra, para (sayarak değişir), kodes/iflas ve
/// mikrofon durumu. Başka bir oyuncuya dokununca teklif ekranı açılır.
class PlayerStrip extends StatelessWidget {
  const PlayerStrip({
    super.key,
    required this.room,
    required this.myId,
    this.mics = const {},
    this.onTapPlayer,
  });

  final Room room;
  final String myId;
  final Map<String, MicState> mics;
  final ValueChanged<String>? onTapPlayer;

  @override
  Widget build(BuildContext context) {
    final currentId = room.game?.currentPlayerId;
    final players = room.playersInTurnOrder;
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final p = players[i];
          final isCurrent = p.id == currentId;
          final tappable = p.id != myId && !p.isBankrupt && onTapPlayer != null;
          return Tooltip(
            message: tappable ? '${p.name}\'e teklif gönder' : p.name,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: tappable ? () => onTapPlayer!(p.id) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? p.pawn.color.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent ? p.pawn.color : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PawnAvatar(
                          pawn: p.pawn,
                          size: 34,
                          dimmed: p.isBankrupt,
                          selected: isCurrent,
                        ),
                        if (p.inJail)
                          const Positioned(
                            right: -4,
                            bottom: -4,
                            child: Icon(Icons.lock, size: 14),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              p.id == myId ? '${p.name} (sen)' : p.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isCurrent ? FontWeight.w800 : FontWeight.w400,
                                decoration: p.isBankrupt
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (p.isBot)
                              const Icon(Icons.smart_toy, size: 14)
                            else
                              MicIndicator(state: mics[p.id] ?? MicState.off),
                          ],
                        ),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(end: p.isBankrupt ? 0 : p.money),
                          duration: const Duration(milliseconds: 700),
                          builder: (context, value, _) => Text(
                            p.isBankrupt ? 'İFLAS' : '${value}M',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color:
                                  value < 0 ? Colors.redAccent : Colors.white,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          const Text('▶ SIRADA',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.amber)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
