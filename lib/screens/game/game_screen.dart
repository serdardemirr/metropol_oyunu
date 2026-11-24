import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../data/card_data.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../services/sound_service.dart';
import '../../services/voice_chat_service.dart';
import '../../widgets/animated_dice.dart';
import '../../widgets/effects.dart';
import '../../widgets/ranking_table.dart';
import 'action_panel.dart';
import 'auction_overlay.dart';
import 'board_view.dart';
import 'deed_card.dart';
import 'game_info_bar.dart';
import 'player_strip.dart';
import 'properties_sheet.dart';
import 'trade_screens.dart';

/// Ana oyun ekranı: oyuncu şeridi + tahta + eylem paneli + efektler.
///
/// Efektler (ses, titreşim, uçuşan para, kodes, toz) oyun günlüğündeki yeni
/// satırlardan tetiklenir; böylece aynı olay tüm telefonlarda aynı anda oynar.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.room,
    required this.myId,
    this.mics = const {},
  });

  final Room room;
  final String myId;

  /// Oyuncuların mikrofon durumları (Realtime Database'den).
  final Map<String, MicState> mics;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _FloatItem {
  final int id;
  final String label;
  final int amount;
  final Color color;
  const _FloatItem(this.id, this.label, this.amount, this.color);
}

class _GameScreenState extends State<GameScreen> {
  late final ValueNotifier<Room> _roomVN = ValueNotifier(widget.room);
  late int _seenSeq = widget.room.game?.eventSeq ?? 0;
  int _diceKey = 0;
  bool _busy = false;

  final List<_FloatItem> _floats = [];
  final List<DustEvent> _dust = [];
  ({int seq, String name})? _jail;

  @override
  void initState() {
    super.initState();
    final game = widget.room.game;
    if (game != null && game.turnNumber == 1 && game.lastDice == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRanking());
    }
  }

  @override
  void didUpdateWidget(covariant GameScreen old) {
    super.didUpdateWidget(old);
    _roomVN.value = widget.room;
    _processEvents();
  }

  @override
  void dispose() {
    _roomVN.dispose();
    super.dispose();
  }

  // ─────────────────────────── Efektler ───────────────────────────

  void _processEvents() {
    final game = widget.room.game;
    if (game == null || game.eventSeq <= _seenSeq) return;
    final fresh = game.log.where((e) => e.seq > _seenSeq).toList();
    _seenSeq = game.eventSeq;

    final sounds = <Sfx>{};
    for (final e in fresh) {
      final player = widget.room.players[e.playerId];

      if (e.moneyDelta != null && player != null) {
        _floats.add(_FloatItem(
            e.seq, player.name, e.moneyDelta!, player.pawn.color));
        if (_floats.length > 4) _floats.removeAt(0);
        sounds.add(Sfx.cash);
      }

      switch (e.kind) {
        case LogKind.dice:
          _diceKey++;
          sounds.add(Sfx.dice);
          HapticFeedback.lightImpact();
        case LogKind.build:
          if (e.tileIndex != null) {
            final d = DustEvent(e.seq, e.tileIndex!);
            _dust.add(d);
            Timer(const Duration(milliseconds: 1300), () {
              if (mounted) setState(() => _dust.remove(d));
            });
          }
          sounds.add(Sfx.build);
          HapticFeedback.mediumImpact();
        case LogKind.jail:
          _jail = (seq: e.seq, name: player?.name ?? '');
          sounds.add(Sfx.siren);
          HapticFeedback.heavyImpact();
        case LogKind.card:
          sounds.add(Sfx.card);
        case LogKind.win:
          sounds.add(Sfx.win);
          HapticFeedback.heavyImpact();
        case LogKind.bankrupt:
          HapticFeedback.heavyImpact();
        case LogKind.auction:
          sounds.add(Sfx.card);
          HapticFeedback.selectionClick();
        case LogKind.trade:
          HapticFeedback.lightImpact();
        case LogKind.info:
        case LogKind.move:
        case LogKind.money:
        case LogKind.buy:
          break;
      }
    }
    for (final s in sounds) {
      unawaited(AppServices.sound.play(s));
    }
    // build() bu güncellemeden hemen sonra çalışır; setState gerekmez.
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on GameException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showRanking() async {
    if (!mounted) return;
    BuildContext? dialogCtx;
    Future.delayed(const Duration(seconds: 5), () {
      final ctx = dialogCtx;
      if (ctx != null && ctx.mounted) Navigator.pop(ctx);
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        dialogCtx = ctx;
        return AlertDialog(
          title: const Text('🎲 Oyun Sırası Belli Oldu!'),
          content: SizedBox(
            width: double.maxFinite,
            child: RankingTable(room: widget.room),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Başlayalım!'),
            ),
          ],
        );
      },
    );
    dialogCtx = null;
  }

  void _openProperties() => PropertiesSheet.show(
        context,
        room: _roomVN,
        myId: widget.myId,
        run: _run,
      );

  /// Teklif hazırlama ekranını açar.
  void _openTrade(String targetId,
      {Set<int> requested = const {},
      Set<int> offered = const {},
      int cash = 0,
      String? counterOf}) {
    final me = widget.room.players[widget.myId];
    final target = widget.room.players[targetId];
    if (targetId == widget.myId ||
        me == null ||
        me.isBankrupt ||
        target == null ||
        target.isBankrupt ||
        widget.room.status != RoomStatus.playing) {
      return;
    }
    TradeComposerPage.open(
      context,
      room: _roomVN,
      myId: widget.myId,
      targetId: targetId,
      requested: requested,
      offered: offered,
      cash: cash,
      counterOf: counterOf,
    );
  }

  void _showTileInfo(int index) {
    final tile = widget.room.game!.board.tile(index);
    if (!tile.isBuyable) return;
    final game = widget.room.game;
    final owner = widget.room.players[game?.tileState(index).ownerId];
    final me = widget.room.players[widget.myId];
    final canOffer = owner != null &&
        owner.id != widget.myId &&
        !owner.isBankrupt &&
        me != null &&
        !me.isBankrupt &&
        widget.room.status == RoomStatus.playing;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: DeedCard(
            tile: tile,
            game: game,
            owner: owner,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
              if (canOffer)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openTrade(owner!.id, requested: {index});
                  },
                  child: const Text('Teklif Gönder',
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Çizim ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final game = room.game;
    if (game == null) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        PlayerStrip(
          room: room,
          myId: widget.myId,
          mics: widget.mics,
          onTapPlayer: _openTrade,
        ),
        GameInfoBar(room: room, myId: widget.myId),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: BoardView(
                  room: room,
                  myId: widget.myId,
                  dust: List.unmodifiable(_dust),
                  onTileTap: _showTileInfo,
                  center: _BoardCenter(game: game, diceKey: _diceKey),
                ),
              ),
              Positioned(
                left: 8,
                right: 64,
                top: 8,
                child: _LastMoveBanner(room: room),
              ),
              ..._decisionOverlay(room, game),
              ..._offerOverlays(room, game),
              if (game.auction != null)
                Positioned.fill(
                  child: AuctionOverlay(
                    key: ValueKey('auction-${game.auction!.tileIndex}'),
                    room: room,
                    myId: widget.myId,
                    run: _run,
                  ),
                ),
              if (room.status == RoomStatus.finished) _winnerOverlay(room, game),

              // Uçuşan para metinleri
              Positioned(
                left: 0,
                right: 0,
                top: 70,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      for (final f in _floats)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: FloatingMoney(
                            key: ValueKey('float-${f.id}'),
                            label: f.label,
                            amount: f.amount,
                            color: f.color,
                            onDone: () {
                              if (mounted) setState(() => _floats.remove(f));
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (_jail case final j?)
                Positioned.fill(
                  child: JailBarsOverlay(
                    key: ValueKey('jail-${j.seq}'),
                    name: j.name,
                    onDone: () {
                      if (mounted) setState(() => _jail = null);
                    },
                  ),
                ),
            ],
          ),
        ),
        ActionPanel(
          room: room,
          myId: widget.myId,
          busy: _busy,
          run: _run,
          onOpenProperties: _openProperties,
        ),
      ],
    );
  }

  List<Widget> _decisionOverlay(Room room, GameState game) {
    final current = room.players[game.currentPlayerId];
    if (current == null) return const [];
    final isMine = current.id == widget.myId;
    final repo = AppServices.game;

    Widget dim(Widget child) => Positioned.fill(
          child: _DelayedAppear(
            key: ValueKey(
                'overlay-${game.phase.name}-${game.turnNumber}-${current.position}'),
            delay: const Duration(milliseconds: 900),
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(child: child),
            ),
          ),
        );

    if (game.phase == TurnPhase.awaitingBuyDecision) {
      final tile = game.board.tile(current.position);
      final canAfford = current.money >= tile.price;
      return [
        dim(DeedCard(
          tile: tile,
          game: game,
          actions: isMine
              ? [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => repo.decline(room.code, widget.myId)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87),
                    child: const Text('Pas Geç'),
                  ),
                  FilledButton(
                    onPressed: _busy || !canAfford
                        ? null
                        : () => _run(() => repo.buy(room.code, widget.myId)),
                    child: Text(canAfford
                        ? 'Satın Al ${tile.price}M'
                        : 'Para yetmiyor'),
                  ),
                ]
              : [
                  Text('${current.name} düşünüyor...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54)),
                ],
        )),
      ];
    }

    final cardId = game.activeCardId;
    if (game.phase == TurnPhase.showingCard && cardId != null) {
      return [
        dim(ChanceCardView(
          card: CardData.byId(cardId),
          action: isMine
              ? FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => repo.acknowledgeCard(room.code, widget.myId)),
                  child: const Text('Tamam'),
                )
              : Text('${current.name} kartı okuyor...',
                  style: const TextStyle(color: Colors.black54)),
        )),
      ];
    }
    return const [];
  }

  /// Bana gelen teklif (alt kart) ve bekleyen tekliflerim (üst şerit).
  List<Widget> _offerOverlays(Room room, GameState game) {
    final incoming = game.offers.where((o) => o.toId == widget.myId).toList();
    final outgoing = game.offers.where((o) => o.fromId == widget.myId).toList();
    return [
      if (outgoing.isNotEmpty)
        Positioned(
          left: 8,
          right: 64,
          top: 56,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in outgoing)
                InputChip(
                  avatar: const Icon(Icons.hourglass_top, size: 16),
                  label: Text(
                      '${room.players[o.toId]?.name ?? '?'} yanıtlıyor...'),
                  deleteIcon: const Icon(Icons.close),
                  deleteButtonTooltipMessage: 'Teklifi geri çek',
                  onDeleted: _busy
                      ? null
                      : () => _run(() => AppServices.game
                          .rejectOffer(room.code, widget.myId, o.id)),
                ),
            ],
          ),
        ),
      if (incoming.isNotEmpty)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: IncomingOfferCard(
              key: ValueKey(incoming.first.id),
              offer: incoming.first,
              room: room,
              myId: widget.myId,
              busy: _busy,
              run: _run,
              onCounter: () {
                final o = incoming.first;
                _openTrade(
                  o.fromId,
                  requested: o.offeredTiles.toSet(),
                  offered: o.requestedTiles.toSet(),
                  cash: -o.cash,
                  counterOf: o.id,
                );
              },
            ),
          ),
        ),
    ];
  }

  Widget _winnerOverlay(Room room, GameState game) {
    final winner = room.players[game.winnerId];
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: Colors.black.withValues(alpha: 0.5)),
          const Positioned.fill(child: ConfettiRain()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events,
                          size: 64, color: Colors.amber),
                      Text(
                        winner == null
                            ? 'Oyun bitti'
                            : '${winner.name} kazandı!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (game.endReason != null)
                        Text(game.endReason!.label,
                            style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 320,
                        child: NetWorthTable(room: room, myId: widget.myId),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tahtanın ortası: logo, zarlar ve son olaylar.
class _BoardCenter extends StatelessWidget {
  const _BoardCenter({required this.game, required this.diceKey});

  final GameState game;
  final int diceKey;

  @override
  Widget build(BuildContext context) {
    final dice = game.lastDice;
    final recent = game.log.reversed.take(7).toList();
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'METROPOL',
            style: TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: Color(0xFF1B5E20),
              shadows: [Shadow(color: Colors.black26, offset: Offset(3, 3))],
            ),
          ),
          const SizedBox(height: 60),
          AnimatedDicePair(
            die1: dice?.die1 ?? 1,
            die2: dice?.die2 ?? 1,
            rollKey: diceKey,
            size: 96,
          ),
          const SizedBox(height: 50),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        e.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 22),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Çocuğunu kısa bir gecikmeyle (piyon yürüyüşü bitsin diye) gösterir.
class _DelayedAppear extends StatefulWidget {
  const _DelayedAppear({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_DelayedAppear> createState() => _DelayedAppearState();
}

class _DelayedAppearState extends State<_DelayedAppear> {
  bool _visible = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(ignoring: !_visible, child: widget.child),
    );
  }
}

/// Son hamleyi, yapan oyuncunun rengiyle vurgulayan şerit.
class _LastMoveBanner extends StatelessWidget {
  const _LastMoveBanner({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final game = room.game!;
    GameLogEntry? last;
    for (final e in game.log.reversed) {
      if (e.playerId != null) {
        last = e;
        break;
      }
    }
    if (last == null) return const SizedBox.shrink();
    final player = room.players[last.playerId];
    final color = player?.pawn.color ?? Colors.white;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: Align(
        key: ValueKey(last.seq),
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          child: Text(
            last.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
