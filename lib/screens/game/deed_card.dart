import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/models.dart';
import 'tile_view.dart';

/// Tapu kartı: fiyat, kira tablosu, renk grubu, ev maliyeti, ipotek değeri.
class DeedCard extends StatelessWidget {
  const DeedCard({
    super.key,
    required this.tile,
    this.game,
    this.owner,
    this.actions = const [],
  });

  final Tile tile;
  final GameState? game;
  final Player? owner;
  final List<Widget> actions;

  static const _levelNames = [
    'Boş arsa',
    '1 Ev',
    '2 Ev',
    '3 Ev',
    '4 Ev',
    'Gökdelen',
  ];

  @override
  Widget build(BuildContext context) {
    final state = game?.tileState(tile.index);
    final header = tile.group?.color ?? Colors.blueGrey.shade700;
    final headerText =
        header.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final icon = tileIcon(tile);

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: header,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  Text('TAPU SENEDİ',
                      style: TextStyle(color: headerText, fontSize: 11)),
                  if (icon != null) Icon(icon.$1, color: headerText),
                  Text(
                    tile.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: headerText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (tile.group != null)
                    Text(
                      [
                        if (tile.plate != null)
                          'Plaka ${tile.plate.toString().padLeft(2, '0')}',
                        if (tile.region != null) tile.region!,
                        tile.group!.label,
                      ].join(' · '),
                      style: TextStyle(color: headerText, fontSize: 12),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('Fiyat', '${tile.price}M', bold: true),
                  const Divider(),
                  ..._rentRows(state),
                  const Divider(),
                  if (tile.isBuildable)
                    _row('Ev / Gökdelen maliyeti', '${tile.houseCost}M'),
                  _row('İpotek değeri', '${tile.mortgageValue}M'),
                  if (owner != null) ...[
                    const Divider(),
                    _row('Sahibi', owner!.name, bold: true),
                    if (state != null && game != null)
                      _row(
                        'Şu anki kira',
                        state.mortgaged
                            ? 'İpotekli'
                            : tile.type == TileType.utility
                                ? 'Zar × ${GameEngine.rentFor(game!, tile.index, diceTotal: 1)}'
                                : '${GameEngine.displayRent(game!, tile.index)}M',
                        bold: true,
                      ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final a in actions) Expanded(child: a),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rentRows(TileState? state) {
    switch (tile.type) {
      case TileType.property:
        return [
          for (var i = 0; i < tile.rents.length; i++)
            _row(
              i == 0 ? 'Kira (grup tamamsa ×2)' : _levelNames[i],
              '${tile.rents[i]}M',
              highlight: state != null && state.isOwned && state.level == i,
            ),
        ];
      case TileType.transport:
        return [
          for (var i = 0; i < tile.rents.length; i++)
            _row('${i + 1} hat sahibiyse', '${tile.rents[i]}M'),
        ];
      case TileType.utility:
        return [
          for (var i = 0; i < tile.rents.length; i++)
            _row('${i + 1} kurum sahibiyse', 'Zar × ${tile.rents[i]}'),
        ];
      default:
        return const [];
    }
  }

  Widget _row(String label, String value,
      {bool bold = false, bool highlight = false}) {
    return Container(
      color: highlight ? Colors.amber.withValues(alpha: 0.35) : null,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Şans / Kamu Fonu kartı.
class ChanceCardView extends StatelessWidget {
  const ChanceCardView({super.key, required this.card, this.action});

  final GameCard card;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isChance = card.deck == CardDeck.chance;
    final color = isChance ? Colors.orange.shade700 : Colors.indigo.shade500;
    return Container(
      width: 290,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isChance ? Icons.help_outline : Icons.savings,
              color: color, size: 44),
          Text(
            isChance ? 'ŞANS' : 'KAMU FONU',
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(
            card.text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87, fontSize: 17),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
