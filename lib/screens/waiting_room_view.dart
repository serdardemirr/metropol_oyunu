import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/game_rules.dart';
import '../data/board_layout.dart';
import '../models/models.dart';
import '../services/app_services.dart';
import '../services/room_repository.dart';
import '../widgets/pawn_avatar.dart';
import '../widgets/pawn_picker.dart';

/// Bekleme odası: oyuncular anlık listelenir; kurucu "Oyunu Başlat"a basar.
class WaitingRoomView extends StatefulWidget {
  const WaitingRoomView({
    super.key,
    required this.room,
    required this.myId,
    required this.online,
  });

  final Room room;
  final String myId;
  final Map<String, bool> online;

  @override
  State<WaitingRoomView> createState() => _WaitingRoomViewState();
}

class _WaitingRoomViewState extends State<WaitingRoomView> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on RoomException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPawn() async {
    final others =
        widget.room.players.values.where((p) => p.id != widget.myId).toList();
    var pawn = widget.room.players[widget.myId]!.pawn;
    final chosen = await showModalBottomSheet<PawnToken>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PawnPicker(
                value: pawn,
                takenSymbols: {for (final p in others) p.pawn.symbol},
                takenColors: {for (final p in others) p.pawn.tint},
                onChanged: (p) => setSheet(() => pawn = p),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, pawn),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await _guard(() => AppServices.rooms
        .changePawn(code: widget.room.code, uid: widget.myId, pawn: chosen));
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final players = room.playersByJoinOrder;
    final amHost = room.isHost(widget.myId);
    final canStart = players.length >= GameRules.minPlayers;
    final canAddBot = amHost && players.length < GameRules.maxPlayers;
    final theme = Theme.of(context);

    // Tüm içerik kaydırılabilir; küçük ekranlarda taşma olmaz.
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Center(
                  child: Text('Oda Kodu', style: theme.textTheme.titleMedium)),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: room.code));
                    _toast('Kod kopyalandı');
                  },
                  child: Text(
                    room.code,
                    style: theme.textTheme.displayMedium?.copyWith(
                        letterSpacing: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Center(
                child: Text('Arkadaşlarına bu kodu söyle',
                    style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: 16),
              _SpeedSelector(
                settings: room.settings,
                editable: amHost && !_busy,
                onChanged: (s) => _guard(() => AppServices.rooms
                    .updateSettings(
                        code: room.code, uid: widget.myId, settings: s)),
              ),
              const SizedBox(height: 8),
              _MapPreview(
                size: room.settings.speed.boardFor(players.length),
                speed: room.settings.speed,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                    'Oyuncular (${players.length}/${GameRules.maxPlayers})',
                    style: theme.textTheme.titleMedium),
              ),
              for (final p in players)
                ListTile(
                  leading: Stack(
                    children: [
                      PawnAvatar(pawn: p.pawn),
                      if (p.isBot)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(Icons.smart_toy, size: 14),
                        )
                      else
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (widget.online[p.id] ?? false)
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              border: Border.all(color: Colors.black54),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    p.id == widget.myId ? '${p.name} (sen)' : p.name,
                  ),
                  subtitle: Text(p.id == widget.myId
                      ? '${p.pawn.label} · değiştirmek için dokun'
                      : p.isBot
                          ? '${p.pawn.label} · bilgisayar oyuncusu'
                          : p.pawn.label),
                  trailing: p.isHost
                      ? const Chip(
                          avatar: Icon(Icons.star, size: 16),
                          label: Text('Kurucu'),
                        )
                      : p.isBot && amHost
                          ? IconButton(
                              tooltip: 'Botu çıkar',
                              icon: const Icon(Icons.close),
                              onPressed: _busy
                                  ? null
                                  : () => _guard(() => AppServices.rooms
                                      .removeBot(
                                          code: room.code,
                                          uid: widget.myId,
                                          botId: p.id)),
                            )
                          : null,
                  onTap: p.id == widget.myId && !_busy ? _pickPawn : null,
                ),
              if (canAddBot)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _guard(() => AppServices.rooms
                            .addBot(code: room.code, uid: widget.myId)),
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('Bot Ekle'),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: amHost
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: canStart && !_busy
                      ? () => _guard(() => AppServices.rooms
                          .startGame(code: room.code, uid: widget.myId))
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(canStart
                      ? 'Oyunu Başlat'
                      : 'En az ${GameRules.minPlayers} oyuncu bekleniyor...'),
                )
              : const Text('Kurucunun oyunu başlatması bekleniyor...'),
        ),
      ],
    );
  }
}

/// Oyuncu sayısına göre seçilecek haritanın önizlemesi.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.size, required this.speed});

  final BoardSize size;
  final GameSpeed speed;

  @override
  Widget build(BuildContext context) {
    final layout = BoardLayout.of(size);
    final cities = layout.tiles.where((t) => t.plate != null).toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: const Icon(Icons.map, size: 32),
        title: Text('${size.label} · ${layout.length} kare'),
        subtitle: Text(
          '${size.description}\n'
          '${cities.first.name} ${cities.first.price}M → '
          '${cities.last.name} ${cities.last.price}M · '
          'Başlangıç ${speed.startingMoney}M',
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// Oyun hızı / süre modu seçimi. Kurucu değiştirir, herkes görür.
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({
    required this.settings,
    required this.editable,
    required this.onChanged,
  });

  final GameSettings settings;
  final bool editable;
  final ValueChanged<GameSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speed = settings.speed;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.speed),
                const SizedBox(width: 8),
                Text('Oyun Modu', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (!editable)
                  Text('Kurucu seçer',
                      style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<GameSpeed>(
              showSelectedIcon: false,
              segments: [
                for (final s in GameSpeed.values)
                  ButtonSegment(
                    value: s,
                    label: Text('${s.emoji} ${s.label.split(' ').first}'),
                    tooltip: '${s.label} · ${s.duration}',
                  ),
              ],
              selected: {speed},
              onSelectionChanged: editable
                  ? (sel) => onChanged(settings.copyWith(speed: sel.first))
                  : null,
            ),
            const SizedBox(height: 8),
            Text('${speed.label} · ${speed.duration}',
                style: theme.textTheme.titleSmall),
            for (final line in speed.summary(timerEnabled: settings.timerEnabled))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $line', style: theme.textTheme.bodySmall),
              ),
            if (speed.optionalTimeLimit != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                    '${speed.optionalTimeLimit!.inMinutes} dakikalık geri sayım'),
                value: settings.timerEnabled,
                onChanged: editable
                    ? (v) => onChanged(settings.copyWith(timerEnabled: v))
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}