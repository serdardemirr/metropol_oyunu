import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../logic/bot_brain.dart';
import '../models/models.dart';
import 'game_repository.dart';
import 'room_repository.dart';

/// Odadaki botların hamlelerini yapar.
///
/// Sadece oda kurucusunun telefonunda çalışır (kurucu her zaman insandır),
/// böylece aynı bot hamlesi iki telefondan birden gönderilmez. Her oda
/// güncellemesinde [BotBrain]'e sorar, cevabı 1–2 saniyelik doğal bir
/// gecikmeyle Firestore transaction'ı olarak uygular.
///
/// Kurucu uygulamayı kapatır ya da arka plana alırsa botlar bekler; kurucu
/// geri gelince kaldıkları yerden devam ederler.
class BotDriver {
  BotDriver({
    required this.code,
    required this.myId,
    required RoomRepository rooms,
    required GameRepository game,
    Random? random,
  })  : _rooms = rooms,
        _game = game,
        _random = random ?? Random();

  final String code;
  final String myId;
  final RoomRepository _rooms;
  final GameRepository _game;
  final Random _random;

  StreamSubscription<Room?>? _sub;
  Timer? _timer;
  Room? _latest;
  bool _busy = false;
  bool _disposed = false;

  /// Bu oda sürümünde başarısız olan hamleler (bir sonraki seçeneğe geçmek için).
  final Set<String> _failed = {};
  int _failedVersion = -1;

  void start() {
    _sub ??= _rooms.watchRoom(code).listen(
      _onRoom,
      onError: (Object e) => debugPrint('BotDriver dinleme hatası: $e'),
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
  }

  void _onRoom(Room? room) {
    _latest = room;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final room = _latest;
    if (_disposed || _busy || room == null) return;
    if (room.hostId != myId) return; // botları sadece kurucu yönetir
    if (!room.players.values.any((p) => p.isBot)) return;

    if (room.updatedAtMs != _failedVersion) {
      _failed.clear();
      _failedVersion = room.updatedAtMs;
    }
    final move = BotBrain.decide(room, skip: _failed);
    if (move == null) return;
    _timer = Timer(_delayFor(move), () => _run(move, room.updatedAtMs));
  }

  Future<void> _run(BotMove move, int version) async {
    if (_disposed) return;
    _busy = true;
    var ok = false;
    try {
      await _apply(move);
      ok = true;
    } catch (e) {
      debugPrint('Bot hamlesi başarısız ($move): $e');
      if (_latest?.updatedAtMs == version) _failed.add(move.key);
    } finally {
      _busy = false;
    }
    if (_disposed) return;
    // Başarılıysa yeni oda görüntüsü gelince karar verilir. Görüntü hamle
    // sürerken geldiyse ya da hamle başarısız olduysa hemen yeniden bak.
    if (!ok || _latest?.updatedAtMs != version) _schedule();
  }

  Future<void> _apply(BotMove m) {
    final id = m.botId;
    switch (m.kind) {
      case BotMoveKind.orderRoll:
        return _rooms.rollForOrder(code: code, uid: id);
      case BotMoveKind.roll:
        return _game.rollDice(code, id);
      case BotMoveKind.buy:
        return _game.buy(code, id);
      case BotMoveKind.decline:
        return _game.decline(code, id);
      case BotMoveKind.acknowledgeCard:
        return _game.acknowledgeCard(code, id);
      case BotMoveKind.build:
        return _game.buildHouse(code, id, m.tile!);
      case BotMoveKind.unmortgage:
        return _game.unmortgage(code, id, m.tile!);
      case BotMoveKind.sell:
        return _game.sellBuilding(code, id, m.tile!);
      case BotMoveKind.mortgage:
        return _game.mortgage(code, id, m.tile!);
      case BotMoveKind.payBail:
        return _game.payBail(code, id);
      case BotMoveKind.useJailCard:
        return _game.useJailCard(code, id);
      case BotMoveKind.endTurn:
        return _game.endTurn(code, id);
      case BotMoveKind.bankrupt:
        return _game.declareBankruptcy(code, id);
      case BotMoveKind.bid:
        return _game.placeBid(code, id, m.amount!);
      case BotMoveKind.acceptOffer:
        return _game.acceptOffer(code, id, m.offerId!);
      case BotMoveKind.rejectOffer:
        return _game.rejectOffer(code, id, m.offerId!);
    }
  }

  /// İnsan gibi görünsün diye hamleye göre değişen kısa bekleme.
  /// Zar sonrası kararlar piyon animasyonu bitsin diye biraz daha uzun.
  /// Müzayede teklifleri 5 saniyelik sıfırlama süresinden kısa tutulur.
  Duration _delayFor(BotMove m) {
    final (base, spread) = switch (m.kind) {
      BotMoveKind.buy ||
      BotMoveKind.decline ||
      BotMoveKind.acknowledgeCard =>
        (1600, 800),
      BotMoveKind.bid => (900, 1600),
      BotMoveKind.acceptOffer || BotMoveKind.rejectOffer => (1500, 1000),
      BotMoveKind.build ||
      BotMoveKind.unmortgage ||
      BotMoveKind.sell ||
      BotMoveKind.mortgage =>
        (700, 400),
      _ => (1000, 800),
    };
    return Duration(milliseconds: base + _random.nextInt(spread));
  }
}
