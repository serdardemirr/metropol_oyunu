import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/game_engine.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import 'tile_view.dart';

/// "Mülklerim": inşaat, bina satışı, ipotek ve ipotek kaldırma.
/// Oda canlı güncellendiği için [room] bir ValueListenable olarak gelir.
class PropertiesSheet extends StatelessWidget {
  const PropertiesSheet({
    super.key,
    required this.room,
    required this.myId,
    required this.run,
    this.scroll,
  });

  final ValueNotifier<Room> room;
  final ScrollController? scroll;
  final String myId;

  /// Hata/meşguliyet yönetimi yapan çalıştırıcı (GameScreen'den gelir).
  final Future<void> Function(Future<void> Function() action) run;

  static Future<void> show(
    BuildContext context, {
    required ValueNotifier<Room> room,
    required String myId,
    required Future<void> Function(Future<void> Function()) run,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (context, scroll) => PropertiesSheet(
          room: room,
          myId: myId,
          run: run,
          scroll: scroll,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Room>(
      valueListenable: room,
      builder: (context, r, _) {
        final game = r.game;
        final me = r.players[myId];
        if (game == null || me == null) return const SizedBox.shrink();
        final owned = game.tilesOwnedBy(myId)
          ..sort((a, b) => a.index.compareTo(b.index));
        final code = r.code;
        final repo = AppServices.game;

        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            ListTile(
              title: Text('Mülklerim',
                  style: Theme.of(context).textTheme.titleLarge),
              trailing: Text(
                '${me.money}M',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: me.money < 0 ? Colors.redAccent : Colors.greenAccent,
                    ),
              ),
            ),
            if (owned.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Henüz hiç tapun yok.', textAlign: TextAlign.center),
              ),
            for (final s in owned)
              _PropertyRow(
                tile: game.board.tile(s.index),
                state: s,
                buildErr: GameEngine.buildError(r, myId, s.index),
                sellErr: GameEngine.sellError(r, myId, s.index),
                mortgageErr: GameEngine.mortgageError(r, myId, s.index),
                unmortgageErr: GameEngine.unmortgageError(r, myId, s.index),
                auctionErr: GameEngine.auctionStartError(r, myId, s.index),
                onAuction: () async {
                  final tile = game.board.tile(s.index);
                  final price = await _askStartPrice(context, tile);
                  if (price == null) return;
                  await run(() => repo.startAuction(code, myId, s.index, price));
                  if (context.mounted) Navigator.of(context).maybePop();
                },
                onBuild: () => run(() => repo.buildHouse(code, myId, s.index)),
                onSell: () => run(() => repo.sellBuilding(code, myId, s.index)),
                onMortgage: () => run(() => repo.mortgage(code, myId, s.index)),
                onUnmortgage: () =>
                    run(() => repo.unmortgage(code, myId, s.index)),
              ),
          ],
        );
      },
    );
  }

}

/// Müzayede başlangıç fiyatını sorar.
Future<int?> _askStartPrice(BuildContext context, Tile tile) async {
  final ctrl = TextEditingController(text: '${tile.mortgageValue}');
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${tile.name} — Açık Artırma'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tapu değeri: ${tile.price}M'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Başlangıç fiyatı',
              suffixText: 'M',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Herkesin ekranında 15 sn\'lik müzayede açılır. Teklif gelmezse '
            'tapu sende kalır.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
          child: const Text('Başlat'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.tile,
    required this.state,
    required this.buildErr,
    required this.sellErr,
    required this.mortgageErr,
    required this.unmortgageErr,
    required this.auctionErr,
    required this.onAuction,
    required this.onBuild,
    required this.onSell,
    required this.onMortgage,
    required this.onUnmortgage,
  });

  final Tile tile;
  final TileState state;
  final String? buildErr, sellErr, mortgageErr, unmortgageErr, auctionErr;
  final VoidCallback onBuild, onSell, onMortgage, onUnmortgage, onAuction;

  String get _levelText {
    if (!tile.isBuildable) return '';
    if (state.hasSkyscraper) return 'Gökdelen';
    if (state.level == 0) return 'Boş arsa';
    return '${state.level} Ev';
  }

  @override
  Widget build(BuildContext context) {
    final icon = tileIcon(tile);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 36,
                  color: tile.group?.color ?? Colors.grey,
                ),
                const SizedBox(width: 10),
                if (icon != null) ...[
                  Icon(icon.$1, size: 20),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tile.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        [
                          if (_levelText.isNotEmpty) _levelText,
                          if (state.mortgaged) 'İPOTEKLİ',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (tile.isBuildable)
                  _action(
                    context,
                    icon: Icons.construction,
                    label: state.level == 4
                        ? 'Gökdelen (${tile.houseCost}M)'
                        : 'İnşa Et (${tile.houseCost}M)',
                    error: buildErr,
                    onTap: onBuild,
                    primary: true,
                  ),
                if (tile.isBuildable && state.level > 0)
                  _action(
                    context,
                    icon: Icons.remove_circle_outline,
                    label: 'Bina Sat (+${tile.houseSellValue}M)',
                    error: sellErr,
                    onTap: onSell,
                  ),
                if (!state.mortgaged)
                  _action(
                    context,
                    icon: Icons.account_balance,
                    label: 'İpotek (+${tile.mortgageValue}M)',
                    error: mortgageErr,
                    onTap: onMortgage,
                  )
                else
                  _action(
                    context,
                    icon: Icons.lock_open,
                    label: 'İpoteği Kaldır (${tile.unmortgageCost}M)',
                    error: unmortgageErr,
                    onTap: onUnmortgage,
                  ),
                _action(
                  context,
                  icon: Icons.gavel,
                  label: 'Açık Artırmaya Çıkar',
                  error: auctionErr,
                  onTap: onAuction,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Devre dışı düğmeye basınca nedenini gösterir.
  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? error,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final enabled = error == null;
    final handler = enabled
        ? onTap
        : () => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error ?? '')));
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(label)],
    );
    final style = enabled ? null : ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(Colors.grey.shade500),
    );
    return primary
        ? FilledButton.tonal(onPressed: handler, style: style, child: child)
        : OutlinedButton(onPressed: handler, style: style, child: child);
  }
}
