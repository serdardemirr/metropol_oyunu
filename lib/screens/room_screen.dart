import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_services.dart';
import '../services/bot_driver.dart';
import '../services/room_repository.dart';
import '../services/voice_chat_service.dart';
import '../widgets/mic_button.dart';
import 'game/game_screen.dart';
import 'order_duel_view.dart';
import 'rules_screen.dart';
import 'waiting_room_view.dart';

/// Odanın canlı akışını dinler ve duruma göre doğru ekranı gösterir:
/// bekleme odası → zar düellosu → oyun.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.code});

  final String code;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final Stream<Room?> _room = AppServices.rooms.watchRoom(widget.code);
  late final Stream<Map<String, bool>> _presence =
      AppServices.presence.watchRoom(widget.code);
  late final Stream<Map<String, MicState>> _mics =
      AppServices.presence.watchMics(widget.code);
  String get _uid => AppServices.auth.uid!;
  bool _leaving = false;

  /// Botların hamlelerini yapar; sadece kurucuyken devreye girer.
  late final BotDriver _bots = BotDriver(
    code: widget.code,
    myId: _uid,
    rooms: AppServices.rooms,
    game: AppServices.game,
  );

  @override
  void initState() {
    super.initState();
    unawaited(AppServices.presence.goOnline(roomCode: widget.code, uid: _uid));
    unawaited(AppServices.voice.join(roomCode: widget.code, uid: _uid));
    _bots.start();
  }

  @override
  void dispose() {
    _bots.dispose();
    unawaited(AppServices.voice.leave());
    unawaited(AppServices.presence.goOffline());
    super.dispose();
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odadan ayrıl?'),
        content: const Text(
            'Oyun başladıysa ayrılmak iflas sayılır ve arsaların bankaya döner.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ayrıl')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await AppServices.rooms.leaveRoom(code: widget.code, uid: _uid);
    } on RoomException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_leaving) _leave();
      },
      child: StreamBuilder<Room?>(
        stream: _room,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Shell(
              code: widget.code,
              onLeave: _leave,
              child: Center(child: Text('Hata: ${snap.error}')),
            );
          }
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
            return _Shell(
              code: widget.code,
              onLeave: _leave,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          final room = snap.data;
          if (room == null || !room.players.containsKey(_uid)) {
            return _Shell(
              code: widget.code,
              onLeave: () => Navigator.of(context).pop(),
              child: const Center(child: Text('Oda kapandı ya da odadan çıkarıldın.')),
            );
          }

          return StreamBuilder<Map<String, bool>>(
            stream: _presence,
            initialData: const {},
            builder: (context, presenceSnap) {
              final online = presenceSnap.data ?? const {};
              final Widget body = switch (room.status) {
                RoomStatus.waiting =>
                  WaitingRoomView(room: room, myId: _uid, online: online),
                RoomStatus.orderDuel => OrderDuelView(room: room, myId: _uid),
                RoomStatus.playing ||
                RoomStatus.finished =>
                  StreamBuilder<Map<String, MicState>>(
                    stream: _mics,
                    initialData: const {},
                    builder: (context, micSnap) => GameScreen(
                      room: room,
                      myId: _uid,
                      mics: micSnap.data ?? const {},
                    ),
                  ),
              };
              return _Shell(
                code: room.code,
                onLeave: _leave,
                settings: room.settings,
                child: body,
              );
            },
          );
        },
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.code,
    required this.child,
    required this.onLeave,
    this.settings,
  });

  final GameSettings? settings;

  final String code;
  final Widget child;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Odadan ayrıl',
          icon: const Icon(Icons.logout),
          onPressed: onLeave,
        ),
        title: Text('Oda $code'),
        actions: [
          const MicButton(),
          ValueListenableBuilder<bool>(
            valueListenable: AppServices.sound.enabled,
            builder: (context, on, _) => IconButton(
              tooltip: on ? 'Sesi kapat' : 'Sesi aç',
              icon: Icon(on ? Icons.volume_up : Icons.volume_off),
              onPressed: AppServices.sound.toggle,
            ),
          ),
          IconButton(
            tooltip: 'Kurallar',
            icon: const Icon(Icons.menu_book),
            onPressed: () => RulesScreen.open(context, settings: settings),
          ),
        ],
      ),
      body: SafeArea(bottom: false, child: child),
    );
  }
}
