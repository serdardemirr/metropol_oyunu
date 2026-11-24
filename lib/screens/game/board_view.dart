import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/board_layout.dart';
import '../../models/models.dart';
import '../../widgets/effects.dart';
import '../../widgets/pawn_avatar.dart';
import 'board_geometry.dart';
import 'tile_view.dart';

/// Bir karede oynatılacak toz bulutu (inşaat) olayı.
class DustEvent {
  final int seq;
  final int tileIndex;
  const DustEvent(this.seq, this.tileIndex);
}

/// Yakınlaştırılabilir (pinch-to-zoom) oyun tahtası.
///
/// * Piyonlar kare kare yürür (12 kareden uzak sıçramalar — kodes, kartlar —
///   doğrudan ışınlanır).
/// * "Takip" açıkken kamera sırası gelen oyuncunun piyonunu izler. Kullanıcı
///   tahtayı elle kaydırınca takip kapanır; sağ üstteki düğmeyle açılır.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.room,
    required this.myId,
    required this.center,
    required this.dust,
    required this.onTileTap,
  });

  final Room room;
  final String myId;

  /// Tahtanın ortasındaki içerik (zarlar, günlük).
  final Widget center;
  final List<DustEvent> dust;
  final ValueChanged<int> onTileTap;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _cam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Animation<Matrix4>? _camAnim;

  bool _follow = true;
  Size _viewport = Size.zero;
  bool _placedInitially = false;

  /// Ekranda gösterilen (animasyonlu) piyon konumları.
  final Map<String, int> _shown = {};
  Timer? _stepTimer;

  static const int _maxWalk = 12;

  @override
  void initState() {
    super.initState();
    _cam.addListener(() {
      final a = _camAnim;
      if (a != null) _tc.value = a.value;
    });
    for (final p in widget.room.players.values) {
      _shown[p.id] = p.position;
    }
  }

  @override
  void didUpdateWidget(covariant BoardView old) {
    super.didUpdateWidget(old);
    _syncPawns();
    if (old.room.game?.currentPlayerId != widget.room.game?.currentPlayerId) {
      _focusCurrent();
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _cam.dispose();
    _tc.dispose();
    super.dispose();
  }

  String? get _currentId => widget.room.game?.currentPlayerId;

  BoardLayout get _layout =>
      widget.room.game?.board ?? BoardLayout.of(BoardSize.standard);

  BoardGeometry? _geoCache;
  BoardGeometry get _geo {
    final layout = _layout;
    final cached = _geoCache;
    if (cached != null && identical(cached.layout, layout)) return cached;
    return _geoCache = BoardGeometry(layout);
  }

  void _syncPawns() {
    final needsMove = widget.room.players.values
        .any((p) => (_shown[p.id] ?? p.position) != p.position);
    if (needsMove && (_stepTimer?.isActive != true)) {
      _stepTimer =
          Timer.periodic(const Duration(milliseconds: 170), (_) => _step());
    }
  }

  void _step() {
    if (!mounted) return;
    var moving = false;
    setState(() {
      for (final p in widget.room.players.values) {
        final shown = _shown[p.id] ?? p.position;
        if (shown == p.position) continue;
        final forward = (p.position - shown) % _layout.length;
        _shown[p.id] = (forward >= 1 && forward <= _maxWalk)
            ? (shown + 1) % _layout.length
            : p.position;
        if (_shown[p.id] != p.position) moving = true;
      }
    });
    _focusCurrent();
    if (!moving) _stepTimer?.cancel();
  }

  // ─────────────────────────── Kamera ───────────────────────────

  double get _followScale =>
      (_viewport.shortestSide / 560).clamp(0.3, 1.6).toDouble();

  void _focusCurrent({bool animate = true}) {
    final id = _currentId;
    if (!_follow || id == null) return;
    final pos = _shown[id] ?? widget.room.players[id]?.position;
    if (pos == null) return;
    _focusOn(_geo.rectOf(pos).center, _followScale, animate: animate);
  }

  void _fitAll() {
    setState(() => _follow = false);
    final s = (min(_viewport.width, _viewport.height) / _geo.size);
    final offset = Offset(
      (_viewport.width - _geo.size * s) / 2,
      (_viewport.height - _geo.size * s) / 2,
    );
    _animateTo(_matrix(s, offset));
  }

  void _focusOn(Offset boardPoint, double scale, {bool animate = true}) {
    if (_viewport == Size.zero) return;
    final offset = Offset(
      _viewport.width / 2 - boardPoint.dx * scale,
      _viewport.height / 2 - boardPoint.dy * scale,
    );
    final m = _matrix(scale, offset);
    if (animate) {
      _animateTo(m);
    } else {
      _tc.value = m;
    }
  }

  static Matrix4 _matrix(double scale, Offset offset) =>
      Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(offset.dx, offset.dy, 0);

  void _animateTo(Matrix4 target) {
    _camAnim = Matrix4Tween(begin: _tc.value.clone(), end: target).animate(
      CurvedAnimation(parent: _cam, curve: Curves.easeInOutCubic),
    );
    _cam.forward(from: 0);
  }

  // ─────────────────────────── Çizim ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final game = room.game;
    final order = game?.turnOrder ?? room.players.keys.toList();

    return LayoutBuilder(
      builder: (context, box) {
        _viewport = box.biggest;
        if (!_placedInitially && _viewport != Size.zero) {
          _placedInitially = true;
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => mounted ? _focusCurrent(animate: false) : null);
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0E3B23),
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 2.5,
                  boundaryMargin: const EdgeInsets.all(600),
                  onInteractionStart: (_) {
                    _cam.stop();
                    if (_follow) setState(() => _follow = false);
                  },
                  child: SizedBox(
                    width: _geo.size,
                    height: _geo.size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Orta alan
                        Positioned.fromRect(
                          rect: _geo.centerRect,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                colors: [Color(0xFFDDEFD9), Color(0xFFB8D8B0)],
                              ),
                            ),
                            // Orta içerik 900x900 tasarlanır, tahtaya göre ölçeklenir.
                            child: FittedBox(
                              child: SizedBox(
                                width: 900,
                                height: 900,
                                child: widget.center,
                              ),
                            ),
                          ),
                        ),

                        // Kareler
                        for (final tile in _layout.tiles)
                          Positioned.fromRect(
                            rect: _geo.rectOf(tile.index),
                            child: GestureDetector(
                              onTap: () => widget.onTileTap(tile.index),
                              child: TileView(
                                tile: tile,
                                innerEdge: _geo.innerEdge(tile.index),
                                salary: widget.room.game?.salary ?? 200,
                                state: game?.tileState(tile.index) ??
                                    TileState(index: tile.index),
                                owner: room.players[
                                    game?.tileState(tile.index).ownerId],
                                highlight: _currentId != null &&
                                    _shown[_currentId] == tile.index,
                              ),
                            ),
                          ),

                        // Toz bulutları
                        for (final d in widget.dust)
                          Positioned.fromRect(
                            key: ValueKey('dust-${d.seq}'),
                            rect: _geo.rectOf(d.tileIndex).inflate(40),
                            child: const DustBurst(),
                          ),

                        // Piyonlar
                        for (final (i, id) in order.indexed)
                          if (room.players[id] case final p?
                              when !p.isBankrupt)
                            _pawn(p, i),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Kamera düğmeleri
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                children: [
                  IconButton.filledTonal(
                    tooltip: _follow ? 'Takip açık' : 'Sıradaki oyuncuyu takip et',
                    isSelected: _follow,
                    icon: const Icon(Icons.my_location),
                    onPressed: () {
                      setState(() => _follow = true);
                      _focusCurrent();
                    },
                  ),
                  const SizedBox(height: 6),
                  IconButton.filledTonal(
                    tooltip: 'Tüm tahtayı gör',
                    icon: const Icon(Icons.zoom_out_map),
                    onPressed: _fitAll,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pawn(Player p, int slot) {
    final pos = _shown[p.id] ?? p.position;
    final rect = _geo.rectOf(pos);
    const size = 34.0;
    // Aynı karedeki piyonlar üst üste binmesin: 3x2 yerleşim
    final dx = ((slot % 3) - 1) * 26.0;
    final dy = ((slot ~/ 3) - 0.5) * 30.0;
    final isCurrent = p.id == _currentId;

    return AnimatedPositioned(
      key: ValueKey('pawn-${p.id}'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      left: rect.center.dx + dx - size / 2,
      top: rect.center.dy + dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PawnAvatar(pawn: p.pawn, size: size, selected: isCurrent),
            if (p.inJail)
              const Positioned(
                right: -6,
                bottom: -6,
                child: Icon(Icons.lock, size: 16, color: Colors.black),
              ),
          ],
        ),
      ),
    );
  }
}
