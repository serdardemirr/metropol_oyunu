import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../widgets/pawn_avatar.dart';

/// Üst bilgi şeridi: oyun modu, kalan süre (varsa) ve Net Varlık lideri.
/// Dokununca Net Varlık sıralaması açılır. Süre dolunca oyunu bitirme
/// isteği gönderir (her istemci; sunucu ilk geçerli isteği uygular).
class GameInfoBar extends StatefulWidget {
  const GameInfoBar({super.key, required this.room, required this.myId});

  final Room room;
  final String myId;

  @override
  State<GameInfoBar> createState() => _GameInfoBarState();
}

class _GameInfoBarState extends State<GameInfoBar> {
  Timer? _ticker;
  int _now = DateTime.now().millisecondsSinceEpoch;
  int _lastFinishTry = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final game = widget.room.game;
    final endsAt = game?.endsAtMs;
    if (endsAt == null) return; // süre yoksa her saniye yeniden çizmeye gerek yok
    setState(() => _now = DateTime.now().millisecondsSinceEpoch);
    if (widget.room.status == RoomStatus.playing &&
        _now > endsAt + 500 &&
        _now - _lastFinishTry > 2000) {
      _lastFinishTry = _now;
      AppServices.game.finishByTime(widget.room.code).catchError((_) {});
    }
  }

  static String _clock(int ms) {
    final total = (ms / 1000).ceil().clamp(0, 1 << 31).toInt();
    final m = total ~/ 60, s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final game = room.game;
    if (game == null) return const SizedBox.shrink();
    final speed = game.speed;
    final ranking = GameEngine.netWorthRanking(game, room.players);
    final leader = ranking.isEmpty ? null : ranking.first;
    final endsAt = game.endsAtMs;
    final remaining = endsAt == null ? null : endsAt - _now;
    final showNetWorth = speed.endOnFirstBankruptcy || endsAt != null;

    return Material(
      color: Colors.black26,
      child: InkWell(
        onTap: () => NetWorthSheet.show(context, room: room, myId: widget.myId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text('${speed.emoji} ${speed.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (remaining != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.timer,
                    size: 16,
                    color: remaining < 5 * 60 * 1000
                        ? Colors.redAccent
                        : Colors.white70),
                const SizedBox(width: 2),
                Text(
                  _clock(remaining),
                  style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                    color:
                        remaining < 5 * 60 * 1000 ? Colors.redAccent : null,
                  ),
                ),
              ],
              const Spacer(),
              if (leader != null && showNetWorth) ...[
                const Text('Lider ', style: TextStyle(fontSize: 12)),
                PawnAvatar(pawn: leader.player.pawn, size: 18),
                const SizedBox(width: 4),
                Text('${leader.total}M',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ] else
                const Text('Net Varlık', style: TextStyle(fontSize: 12)),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Net Varlık sıralaması: nakit + tapu + bina dökümüyle.
class NetWorthSheet extends StatelessWidget {
  const NetWorthSheet({super.key, required this.room, required this.myId});

  final Room room;
  final String myId;

  static Future<void> show(BuildContext context,
          {required Room room, required String myId}) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => NetWorthSheet(room: room, myId: myId),
      );

  @override
  Widget build(BuildContext context) {
    final game = room.game;
    if (game == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Net Varlık Sıralaması',
                style: Theme.of(context).textTheme.titleLarge),
            const Text('Nakit + tapu değeri (ipotek düşülmüş) + bina maliyetleri',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 8),
            NetWorthTable(room: room, myId: myId),
          ],
        ),
      ),
    );
  }
}

/// Sıralama tablosu (bilgi penceresi ve oyun sonu ekranında ortak).
class NetWorthTable extends StatelessWidget {
  const NetWorthTable({super.key, required this.room, required this.myId});

  final Room room;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final ranking = GameEngine.netWorthRanking(room.game!, room.players);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, n) in ranking.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 64,
              child: Row(
                children: [
                  Text('${i + 1}.',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 6),
                  PawnAvatar(pawn: n.player.pawn, size: 28),
                ],
              ),
            ),
            title: Text(n.player.id == myId
                ? '${n.player.name} (sen)'
                : n.player.name),
            subtitle: Text(
                'Nakit ${n.cash}M · Tapu ${n.deeds}M · Bina ${n.buildings}M'),
            trailing: Text('${n.total}M',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900)),
          ),
      ],
    );
  }
}
