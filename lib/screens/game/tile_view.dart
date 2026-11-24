import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'board_geometry.dart';

/// Kare türüne göre ikon ve renk (tahta, tapu kartı ve listelerde ortak).
(IconData, Color)? tileIcon(Tile tile) {
  switch (tile.type) {
    case TileType.start:
      return (Icons.keyboard_double_arrow_left, Colors.green.shade700);
    case TileType.jail:
      return (Icons.local_police, Colors.blueGrey.shade700);
    case TileType.freeParking:
      return (Icons.local_parking, Colors.blue.shade700);
    case TileType.goToJail:
      return (Icons.gavel, Colors.red.shade700);
    case TileType.chance:
      return (Icons.help_outline, Colors.orange.shade800);
    case TileType.communityFund:
      return (Icons.savings, Colors.indigo.shade600);
    case TileType.tax:
      return (Icons.receipt_long, Colors.brown.shade600);
    case TileType.transport:
      final n = tile.name.toLowerCase();
      if (n.contains('iskele')) return (Icons.directions_boat, Colors.black87);
      if (n.contains('havalimanı')) return (Icons.flight, Colors.black87);
      return (Icons.train, Colors.black87);
    case TileType.utility:
      final n = tile.name.toLowerCase();
      if (n.contains('su')) return (Icons.water_drop, Colors.lightBlue.shade700);
      if (n.contains('doğalgaz')) {
        return (Icons.local_fire_department, Colors.deepOrange.shade600);
      }
      return (Icons.bolt, Colors.amber.shade800);
    case TileType.property:
      return null;
  }
}

/// Tahtadaki tek bir kare.
class TileView extends StatelessWidget {
  const TileView({
    super.key,
    required this.tile,
    required this.state,
    required this.innerEdge,
    required this.salary,
    this.owner,
    this.highlight = false,
  });

  /// Renk şeridinin çizileceği, tahtanın içine bakan kenar.
  final AxisDirection innerEdge;
  final int salary;
  final Tile tile;
  final TileState state;
  final Player? owner;
  final bool highlight;

  static const _bg = Color(0xFFF4EDD8);
  static const _ink = Color(0xFF2B2B2B);

  @override
  Widget build(BuildContext context) {
    final edge = innerEdge;
    const b = BoardGeometry.band;
    final icon = tileIcon(tile);

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(
          color: highlight ? Colors.amber : Colors.black54,
          width: highlight ? 4 : 0.8,
        ),
      ),
      child: Stack(
        children: [
          // Sahip şeridi (dış kenar)
          if (owner != null) _edgeStrip(_flip(edge), 7, owner!.pawn.color),

          // Renk grubu şeridi + binalar (iç kenar)
          if (tile.group != null)
            _edgeStrip(edge, b, tile.group!.color, child: _buildings()),

          Positioned.fill(
            child: Padding(
              padding: _paddingFor(edge, tile.group != null ? b : 0) +
                  const EdgeInsets.all(3),
              child: tile.isCorner
                  ? _cornerContent(icon)
                  : _content(icon),
            ),
          ),

          if (state.mortgaged)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: const RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'İPOTEK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content((IconData, Color)? icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) Icon(icon.$1, color: icon.$2, size: 26),
        if (tile.plate != null)
          Text(
            tile.plate!.toString().padLeft(2, '0'),
            style: const TextStyle(
                color: Colors.black45, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        Text(
          tile.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        if (tile.isBuyable)
          Text('${tile.price}M',
              style: const TextStyle(color: _ink, fontSize: 11)),
        if (tile.type == TileType.tax)
          Text('${tile.taxAmount}M',
              style: const TextStyle(color: _ink, fontSize: 11)),
      ],
    );
  }

  Widget _cornerContent((IconData, Color)? icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) Icon(icon.$1, color: icon.$2, size: 52),
        const SizedBox(height: 4),
        Text(
          tile.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (tile.type == TileType.start)
          Text('+${salary}M',
              style: const TextStyle(color: _ink, fontSize: 12)),
      ],
    );
  }

  Widget? _buildings() {
    if (state.level == 0) return null;
    if (state.hasSkyscraper) {
      return const Icon(Icons.apartment, color: Colors.white, size: 20,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)]);
    }
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 0,
      children: [
        for (var i = 0; i < state.level; i++)
          const Icon(Icons.house, color: Color(0xFF1B5E20), size: 15,
              shadows: [Shadow(color: Colors.white, blurRadius: 2)]),
      ],
    );
  }

  static AxisDirection _flip(AxisDirection d) => switch (d) {
        AxisDirection.up => AxisDirection.down,
        AxisDirection.down => AxisDirection.up,
        AxisDirection.left => AxisDirection.right,
        AxisDirection.right => AxisDirection.left,
      };

  static Widget _edgeStrip(AxisDirection edge, double thickness, Color color,
      {Widget? child}) {
    final box = Container(
      color: color,
      alignment: Alignment.center,
      child: child,
    );
    return switch (edge) {
      AxisDirection.up =>
        Positioned(left: 0, right: 0, top: 0, height: thickness, child: box),
      AxisDirection.down =>
        Positioned(left: 0, right: 0, bottom: 0, height: thickness, child: box),
      AxisDirection.left =>
        Positioned(top: 0, bottom: 0, left: 0, width: thickness, child: box),
      AxisDirection.right =>
        Positioned(top: 0, bottom: 0, right: 0, width: thickness, child: box),
    };
  }

  static EdgeInsets _paddingFor(AxisDirection edge, double b) => switch (edge) {
        AxisDirection.up => EdgeInsets.only(top: b),
        AxisDirection.down => EdgeInsets.only(bottom: b),
        AxisDirection.left => EdgeInsets.only(left: b),
        AxisDirection.right => EdgeInsets.only(right: b),
      };
}
