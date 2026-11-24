import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../logic/game_engine.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../widgets/pawn_avatar.dart';

/// Teklif hazırlama ekranı: karşı oyuncudan il iste, kendi illerini takasa
/// koy, nakit ekle ya da iste. Karşı teklif için [counterOf] verilir.
class TradeComposerPage extends StatefulWidget {
  const TradeComposerPage({
    super.key,
    required this.room,
    required this.myId,
    required this.targetId,
    this.initialRequested = const {},
    this.initialOffered = const {},
    this.initialCash = 0,
    this.counterOf,
  });

  final ValueNotifier<Room> room;
  final String myId;
  final String targetId;
  final Set<int> initialRequested;
  final Set<int> initialOffered;

  /// Pozitif: ben öderim. Negatif: karşı taraftan isterim.
  final int initialCash;
  final String? counterOf;

  static Future<void> open(
    BuildContext context, {
    required ValueNotifier<Room> room,
    required String myId,
    required String targetId,
    Set<int> requested = const {},
    Set<int> offered = const {},
    int cash = 0,
    String? counterOf,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TradeComposerPage(
        room: room,
        myId: myId,
        targetId: targetId,
        initialRequested: requested,
        initialOffered: offered,
        initialCash: cash,
        counterOf: counterOf,
      ),
    ));
  }

  @override
  State<TradeComposerPage> createState() => _TradeComposerPageState();
}

class _TradeComposerPageState extends State<TradeComposerPage> {
  late final Set<int> _requested = {...widget.initialRequested};
  late final Set<int> _offered = {...widget.initialOffered};
  late bool _iPay = widget.initialCash >= 0;
  late final TextEditingController _cash = TextEditingController(
      text: widget.initialCash == 0 ? '' : '${widget.initialCash.abs()}');
  bool _sending = false;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  TradeOffer _buildOffer() {
    final amount = int.tryParse(_cash.text) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return TradeOffer(
      id: '${widget.myId}_$now',
      fromId: widget.myId,
      toId: widget.targetId,
      requestedTiles: _requested.toList()..sort(),
      offeredTiles: _offered.toList()..sort(),
      cash: _iPay ? amount : -amount,
      createdAtMs: now,
      counterOf: widget.counterOf,
    );
  }

  Future<void> _send() async {
    final room = widget.room.value;
    final offer = _buildOffer();
    final err = GameEngine.offerError(room, offer);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _sending = true);
    try {
      await AppServices.game.sendOffer(room.code, offer);
      if (mounted) Navigator.of(context).pop();
    } on GameException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Room>(
      valueListenable: widget.room,
      builder: (context, room, _) {
        final game = room.game;
        final me = room.players[widget.myId];
        final them = room.players[widget.targetId];
        if (game == null || me == null || them == null) {
          return const Scaffold(body: Center(child: Text('Oyun bulunamadı.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.counterOf == null
                ? '${them.name}\'e teklif'
                : '${them.name}\'e karşı teklif'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(me: me, them: them),
              const SizedBox(height: 16),
              _TileSection(
                title: '${them.name}\'den istediğin iller',
                game: game,
                ownerId: them.id,
                selected: _requested,
                onToggle: (i) => setState(() =>
                    _requested.contains(i) ? _requested.remove(i) : _requested.add(i)),
              ),
              const SizedBox(height: 12),
              _TileSection(
                title: 'Takasa koyduğun illerin',
                game: game,
                ownerId: me.id,
                selected: _offered,
                onToggle: (i) => setState(() =>
                    _offered.contains(i) ? _offered.remove(i) : _offered.add(i)),
              ),
              const SizedBox(height: 16),
              Text('Nakit', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  const ButtonSegment(
                      value: true,
                      icon: Icon(Icons.arrow_upward),
                      label: Text('Ben öderim')),
                  ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.arrow_downward),
                      label: Text('${them.name} ödesin')),
                ],
                selected: {_iPay},
                onSelectionChanged: (s) => setState(() => _iPay = s.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _cash,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixText: 'M',
                  hintText: '0',
                  helperText: _iPay
                      ? 'Senin bakiyen: ${me.money}M'
                      : '${them.name} bakiyesi: ${them.money}M',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text(
                'Not: Üzerinde ev/gökdelen olan bir gruptan il takas edilemez; '
                'önce binaların bankaya satılması gerekir.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
                label: const Text('Teklifi Gönder'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me, required this.them});
  final Player me, them;

  @override
  Widget build(BuildContext context) {
    Widget side(Player p) => Column(
          children: [
            PawnAvatar(pawn: p.pawn, size: 48),
            Text(p.name),
            Text('${p.money}M', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [side(me), const Icon(Icons.swap_horiz, size: 36), side(them)],
    );
  }
}

class _TileSection extends StatelessWidget {
  const _TileSection({
    required this.title,
    required this.game,
    required this.ownerId,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final GameState game;
  final String ownerId;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final owned = game.tilesOwnedBy(ownerId)
      ..sort((a, b) => a.index.compareTo(b.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (owned.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Tapu yok.', style: TextStyle(color: Colors.white54)),
          ),
        for (final s in owned)
          _tileRow(context, s),
      ],
    );
  }

  Widget _tileRow(BuildContext context, TileState s) {
    final tile = game.board.tile(s.index);
    final group = tile.group;
    final groupBuilt = group != null &&
        game.board
            .tilesInGroup(group)
            .any((t) => game.tileState(t.index).level > 0);
    return CheckboxListTile(
      dense: true,
      value: selected.contains(s.index),
      onChanged: groupBuilt ? null : (_) => onToggle(s.index),
      secondary: Container(width: 10, height: 32, color: group?.color ?? Colors.grey),
      title: Text(tile.name),
      subtitle: Text([
        '${tile.price}M',
        if (s.mortgaged) 'ipotekli',
        if (groupBuilt) 'grupta bina var',
      ].join(' · ')),
    );
  }
}

/// Bana gelen teklif: Kabul Et / Reddet / Karşı Teklif.
class IncomingOfferCard extends StatelessWidget {
  const IncomingOfferCard({
    super.key,
    required this.offer,
    required this.room,
    required this.myId,
    required this.busy,
    required this.run,
    required this.onCounter,
  });

  final TradeOffer offer;
  final Room room;
  final String myId;
  final bool busy;
  final Future<void> Function(Future<void> Function() action) run;
  final VoidCallback onCounter;

  @override
  Widget build(BuildContext context) {
    final game = room.game!;
    final from = room.players[offer.fromId];
    if (from == null) return const SizedBox.shrink();
    String names(List<int> tiles) =>
        tiles.map((i) => game.board.tile(i).name).join(', ');
    final repo = AppServices.game;
    final error = GameEngine.offerError(room, offer);

    return Card(
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PawnAvatar(pawn: from.pawn, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${from.name} sana ${offer.counterOf == null ? '' : 'karşı '}teklif gönderdi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (offer.requestedTiles.isNotEmpty)
              _line(Icons.call_made, 'Senden istediği',
                  names(offer.requestedTiles), Colors.redAccent),
            if (offer.offeredTiles.isNotEmpty)
              _line(Icons.call_received, 'Sana verdiği',
                  names(offer.offeredTiles), Colors.greenAccent),
            if (offer.cash > 0)
              _line(Icons.payments, 'Sana ödeyeceği', '${offer.cash}M',
                  Colors.greenAccent),
            if (offer.cash < 0)
              _line(Icons.payments, 'Senden istediği para', '${-offer.cash}M',
                  Colors.redAccent),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error,
                    style: const TextStyle(color: Colors.orangeAccent)),
              ),
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => run(() =>
                            repo.rejectOffer(room.code, myId, offer.id)),
                    child: const Text('Reddet'),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onCounter,
                    child: const Text('Karşı Teklif', textAlign: TextAlign.center),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: busy || error != null
                        ? null
                        : () => run(() =>
                            repo.acceptOffer(room.code, myId, offer.id)),
                    child: const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text('$label: '),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
