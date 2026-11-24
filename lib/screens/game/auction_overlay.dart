import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/game_rules.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../widgets/pawn_avatar.dart';

/// Tüm oyuncuların ekranında açılan canlı müzayede penceresi.
///
/// Geri sayım her cihazın kendi saatiyle yapılır. Süre dolunca her istemci
/// sonuçlandırma ister; sunucu tarafında transaction ilk geçerli isteği uygular,
/// diğerleri değişiklik yapmaz.
class AuctionOverlay extends StatefulWidget {
  const AuctionOverlay({
    super.key,
    required this.room,
    required this.myId,
    required this.run,
  });

  final Room room;
  final String myId;
  final Future<void> Function(Future<void> Function() action) run;

  @override
  State<AuctionOverlay> createState() => _AuctionOverlayState();
}

class _AuctionOverlayState extends State<AuctionOverlay> {
  Timer? _ticker;
  int _now = DateTime.now().millisecondsSinceEpoch;
  int _lastFinalizeTry = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant AuctionOverlay old) {
    super.didUpdateWidget(old);
    final a = widget.room.game?.auction;
    if (a != null && a.bidCount != old.room.game?.auction?.bidCount) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = DateTime.now().millisecondsSinceEpoch);
    final a = widget.room.game?.auction;
    // Süre dolduysa (küçük saat farkları için +400ms payla) saniyede bir
    // sonuçlandırmayı dene.
    if (a != null && _now > a.endsAtMs + 400 && _now - _lastFinalizeTry > 1000) {
      _lastFinalizeTry = _now;
      AppServices.game.finalizeAuction(widget.room.code).catchError((_) {});
    }
  }

  Future<void> _bid(int amount) => widget.run(
      () => AppServices.game.placeBid(widget.room.code, widget.myId, amount));

  Future<void> _customBid(Auction a) async {
    final ctrl = TextEditingController(text: '${a.minimumBid}');
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Özel teklif'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            suffixText: 'M',
            helperText: 'En az ${a.minimumBid}M',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Teklif Ver'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (amount != null) await _bid(amount);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final game = room.game;
    final a = game?.auction;
    if (game == null || a == null) return const SizedBox.shrink();

    final tile = game.board.tile(a.tileIndex);
    final seller = room.players[a.sellerId];
    final leader = room.players[a.highestBidderId];
    final me = room.players[widget.myId];
    final remainingMs = (a.endsAtMs - _now).clamp(0, 1 << 31).toInt();
    final total = GameRules.auctionDuration.inMilliseconds;
    final isSeller = a.sellerId == widget.myId;
    final canBid = me != null && !me.isBankrupt && !isSeller;
    final myMoney = me?.money ?? 0;
    final base = a.highestBid ?? a.startPrice;
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 330,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: tile.group?.color ?? Colors.blueGrey,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text('🔨 AÇIK ARTIRMA',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 3)])),
                    Text(tile.name.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 3)])),
                    Text(
                      'Satıcı: ${seller?.name ?? '?'} · Tapu değeri ${tile.price}M'
                      '${game.tileState(tile.index).mortgaged ? ' · İPOTEKLİ' : ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: (remainingMs / total).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                color: remainingMs < 3000 ? Colors.redAccent : Colors.amber,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      remainingMs == 0
                          ? 'Süre doldu, sonuçlanıyor...'
                          : '${(remainingMs / 1000).ceil()} sn',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, anim) =>
                          ScaleTransition(scale: anim, child: c),
                      child: Row(
                        key: ValueKey(a.bidCount),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (leader != null) ...[
                            PawnAvatar(pawn: leader.pawn, size: 36),
                            const SizedBox(width: 10),
                          ],
                          Column(
                            children: [
                              Text(
                                a.highestBid == null
                                    ? 'Açılış ${a.startPrice}M'
                                    : '${a.highestBid}M',
                                style: theme.textTheme.headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(leader == null
                                  ? 'Henüz teklif yok'
                                  : leader.id == widget.myId
                                      ? 'En yüksek teklif SENİN'
                                      : 'En yüksek: ${leader.name}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isSeller)
                      const Text('Teklifler bekleniyor...')
                    else if (!canBid)
                      const Text('İzliyorsun.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (a.highestBid == null)
                            FilledButton(
                              onPressed: myMoney >= a.startPrice
                                  ? () => _bid(a.startPrice)
                                  : null,
                              child: Text('${a.startPrice}M ile aç'),
                            ),
                          for (final step in GameRules.auctionQuickBids)
                            FilledButton.tonal(
                              onPressed: myMoney >= base + step &&
                                      a.highestBidderId != widget.myId
                                  ? () => _bid(base + step)
                                  : null,
                              child: Text('+${step}M'),
                            ),
                          OutlinedButton(
                            onPressed: a.highestBidderId == widget.myId
                                ? null
                                : () => _customBid(a),
                            child: const Text('Özel tutar'),
                          ),
                        ],
                      ),
                    if (canBid) ...[
                      const SizedBox(height: 8),
                      Text('Bakiyen: ${myMoney}M',
                          style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
