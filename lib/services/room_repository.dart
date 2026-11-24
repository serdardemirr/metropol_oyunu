import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/game_rules.dart';
import '../core/errors.dart';
import '../core/utils/dice.dart';
import '../core/utils/room_code.dart';
import '../logic/bot_factory.dart';
import '../logic/game_engine.dart';
import '../models/models.dart';
import 'game_initializer.dart';
import 'profile_service.dart';

/// Oda işlemlerindeki kullanıcıya gösterilebilir hata.
class RoomException extends GameException {
  const RoomException(super.message);
}

class JoinResult {
  final String code;

  /// İstenen piyon odada başkasındaysa verilen yeni piyon; değişmediyse null.
  final PawnToken? reassignedPawn;

  const JoinResult(this.code, {this.reassignedPawn});
}

class _CodeTaken implements Exception {}

/// Oda kurma, katılma, ayrılma, oyunu başlatma ve zar düellosu.
///
/// Tüm durum değişiklikleri Firestore transaction'ı içinde yapılır:
/// iki oyuncu aynı anda zar atsa ya da odaya girse bile veri bozulmaz.
class RoomRepository {
  RoomRepository({FirebaseFirestore? firestore, Dice? dice})
      : _db = firestore ?? FirebaseFirestore.instance,
        _dice = dice ?? Dice();

  final FirebaseFirestore _db;
  final Dice _dice;

  static const String collection = 'rooms';
  static const int _maxCodeAttempts = 15;

  DocumentReference<Map<String, dynamic>> _ref(String code) =>
      _db.collection(collection).doc(code);

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Odayı tek seferde yazar ve meta alanları ekler.
  /// `expireAt`, Firestore TTL politikası için: terk edilmiş odalar
  /// otomatik silinir ve 4 haneli kodlar tekrar kullanılabilir hale gelir.
  void _write(Transaction tx, Room room) {
    final now = _now;
    final map = room.copyWith(updatedAtMs: now).toMap()
      ..['expireAt'] = Timestamp.fromMillisecondsSinceEpoch(
          now + GameRules.staleRoomAfter.inMilliseconds);
    tx.set(_ref(room.code), map);
  }

  Future<Room> _read(Transaction tx, String code) async {
    final snap = await tx.get(_ref(code));
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw const RoomException('Oda bulunamadı. Kodu kontrol et.');
    }
    return Room.fromMap(data);
  }

  // ───────────────────────────────────────────────────────────────
  // Dinleme
  // ───────────────────────────────────────────────────────────────

  /// Odanın canlı akışı. Oda silinirse `null` yayınlar.
  Stream<Room?> watchRoom(String code) {
    return _ref(code).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return Room.fromMap(data);
    });
  }

  // ───────────────────────────────────────────────────────────────
  // Oda kur
  // ───────────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String uid,
    required UserProfile profile,
  }) async {
    for (var attempt = 0; attempt < _maxCodeAttempts; attempt++) {
      final code = RoomCode.generate();
      try {
        await _db.runTransaction((tx) async {
          final snap = await tx.get(_ref(code));
          if (snap.exists) throw _CodeTaken();

          final now = _now;
          final host = Player(
            id: uid,
            name: profile.name.trim(),
            pawn: profile.pawn,
            isHost: true,
            joinedAtMs: now,
          );
          _write(
            tx,
            Room(
              code: code,
              hostId: uid,
              status: RoomStatus.waiting,
              players: {uid: host},
              createdAtMs: now,
              updatedAtMs: now,
            ),
          );
        });
        return code;
      } on _CodeTaken {
        continue; // başka kod dene
      }
    }
    throw const RoomException(
        'Boş oda kodu bulunamadı. Lütfen biraz sonra tekrar dene.');
  }

  // ───────────────────────────────────────────────────────────────
  // Odaya katıl
  // ───────────────────────────────────────────────────────────────

  Future<JoinResult> joinRoom({
    required String code,
    required String uid,
    required UserProfile profile,
  }) async {
    if (!RoomCode.isValid(code)) {
      throw const RoomException('Oda kodu 4 haneli bir sayı olmalı.');
    }

    return _db.runTransaction<JoinResult>((tx) async {
      final room = await _read(tx, code);

      // Zaten odadaysa (uygulama yeniden açıldı vb.) sadece geri dön.
      if (room.players.containsKey(uid)) return JoinResult(code);

      if (room.status != RoomStatus.waiting) {
        throw const RoomException('Bu odada oyun çoktan başladı.');
      }
      if (room.players.length >= GameRules.maxPlayers) {
        throw const RoomException(
            'Oda dolu (en fazla ${GameRules.maxPlayers} oyuncu).');
      }

      // Renk ya da sembol başkasındaysa ilk boş olanı ver.
      final pawn =
          profile.pawn.resolveAgainst(room.players.values.map((p) => p.pawn));
      final reassigned = pawn == profile.pawn ? null : pawn;

      // Aynı isim varsa numara ekle: "Ali", "Ali 2"...
      final takenNames =
          room.players.values.map((p) => p.name.toLowerCase()).toSet();
      final baseName = profile.name.trim();
      var name = baseName;
      for (var n = 2; takenNames.contains(name.toLowerCase()); n++) {
        name = '$baseName $n';
      }

      final player = Player(
        id: uid,
        name: name,
        pawn: pawn,
        joinedAtMs: _now,
      );

      _write(
        tx,
        room.copyWith(players: {...room.players, uid: player}),
      );
      return JoinResult(code, reassignedPawn: reassigned);
    });
  }

  // ───────────────────────────────────────────────────────────────
  // Bekleme odasında piyon değiştir
  // ───────────────────────────────────────────────────────────────

  Future<void> changePawn({
    required String code,
    required String uid,
    required PawnToken pawn,
  }) {
    return _db.runTransaction((tx) async {
      final room = await _read(tx, code);
      final me = room.player(uid);
      if (me == null) throw const RoomException('Bu odada değilsin.');
      if (room.status != RoomStatus.waiting) {
        throw const RoomException('Oyun başladıktan sonra piyon değişmez.');
      }
      final others = room.players.values.where((p) => p.id != uid);
      if (others.any((p) => p.pawn.tint == pawn.tint)) {
        throw const RoomException('Bu renk başka bir oyuncuda.');
      }
      if (others.any((p) => p.pawn.symbol == pawn.symbol)) {
        throw const RoomException('Bu sembol başka bir oyuncuda.');
      }
      _write(
        tx,
        room.copyWith(players: {...room.players, uid: me.copyWith(pawn: pawn)}),
      );
    });
  }

  // ───────────────────────────────────────────────────────────────
  // Botlar (tek başına test için; sadece kurucu, bekleme odasında)
  // ───────────────────────────────────────────────────────────────

  /// Odaya benzersiz isim ve boş piyonla bir bot ekler. Eklenen botun id'sini döner.
  Future<String> addBot({required String code, required String uid}) {
    return _db.runTransaction<String>((tx) async {
      final room = await _read(tx, code);
      if (!room.isHost(uid)) {
        throw const RoomException('Bot ekleyebilmek için oda kurucusu olmalısın.');
      }
      if (room.status != RoomStatus.waiting) {
        throw const RoomException('Oyun başladıktan sonra bot eklenemez.');
      }
      if (room.players.length >= GameRules.maxPlayers) {
        throw const RoomException(
            'Oda dolu (en fazla ${GameRules.maxPlayers} oyuncu).');
      }
      final bot = BotFactory.create(room, now: _now);
      _write(tx, room.copyWith(players: {...room.players, bot.id: bot}));
      return bot.id;
    });
  }

  /// Kurucu bekleme odasında bir botu çıkarır.
  Future<void> removeBot({
    required String code,
    required String uid,
    required String botId,
  }) {
    return _db.runTransaction((tx) async {
      final room = await _read(tx, code);
      if (!room.isHost(uid)) {
        throw const RoomException('Botu sadece oda kurucusu çıkarabilir.');
      }
      if (room.status != RoomStatus.waiting) {
        throw const RoomException('Oyun başladıktan sonra bot çıkarılamaz.');
      }
      if (!(room.players[botId]?.isBot ?? false)) return;
      _write(
        tx,
        room.copyWith(players: Map.of(room.players)..remove(botId)),
      );
    });
  }

  // ───────────────────────────────────────────────────────────────
  // Odadan ayrıl
  // ───────────────────────────────────────────────────────────────

  Future<void> leaveRoom({required String code, required String uid}) {
    return _db.runTransaction((tx) async {
      final snap = await tx.get(_ref(code));
      final data = snap.data();
      if (!snap.exists || data == null) return;
      final room = Room.fromMap(data);
      if (!room.players.containsKey(uid)) return;

      switch (room.status) {
        case RoomStatus.waiting:
        case RoomStatus.orderDuel:
        case RoomStatus.finished:
          _leaveBeforeGame(tx, room, uid);
        case RoomStatus.playing:
          _leaveDuringGame(tx, room, uid);
      }
    });
  }

  void _leaveBeforeGame(Transaction tx, Room room, String uid) {
    final remaining = Map<String, Player>.from(room.players)..remove(uid);
    if (remaining.isEmpty) {
      tx.delete(_ref(room.code));
      return;
    }
    if (remaining.values.every((p) => p.isBot)) {
      // Sadece botlar kaldı: oda kapanır. Güvenlik kuralları silmeye yalnızca
      // tek oyuncu kaldığında izin verdiği için oyuncular boşaltılır ve oda
      // "bitti" olarak bırakılır; TTL politikası onu sonra siler.
      _write(tx, room.copyWith(status: RoomStatus.finished, players: const {}));
      return;
    }

    var updated = room.copyWith(players: _withHost(remaining, room.hostId));
    updated = updated.copyWith(hostId: _hostIdOf(updated.players));

    if (room.status == RoomStatus.orderDuel && room.orderDuel != null) {
      if (remaining.length < GameRules.minPlayers) {
        // Düello için yeterli kişi kalmadı → bekleme odasına dön.
        updated = updated.copyWith(
          status: RoomStatus.waiting,
          clearOrderDuel: true,
        );
      } else {
        final duel = room.orderDuel!.removePlayer(uid);
        updated = duel.isComplete
            ? _beginGame(updated, duel)
            : updated.copyWith(orderDuel: duel);
      }
    }
    _write(tx, updated);
  }

  /// Oyun sırasında ayrılan oyuncu iflas etmiş sayılır, arsaları bankaya döner.
  void _leaveDuringGame(Transaction tx, Room room, String uid) {
    var updated = GameEngine.eliminate(
      room,
      uid,
      reason: '${room.players[uid]!.name} oyundan ayrıldı.',
    );
    if (room.hostId == uid) {
      // Botları yöneten kurucu her zaman bir insandır.
      final humans = updated.players.values
          .where((p) => !p.isBot && p.id != uid)
          .toList();
      final alive = humans.where((p) => !p.isBankrupt).toList();
      final newHost = alive.isNotEmpty
          ? alive.first.id
          : (humans.isNotEmpty ? humans.first.id : room.hostId);
      updated = updated.copyWith(
        hostId: newHost,
        players: _withHost(updated.players, newHost),
      );
    }
    _write(tx, updated);
  }

  /// Kurucu ayrıldıysa en eski (insan) oyuncuyu kurucu yapar.
  Map<String, Player> _withHost(Map<String, Player> players, String hostId) {
    final effectiveHost = players.containsKey(hostId)
        ? hostId
        : (players.values.toList()
              ..sort((a, b) {
                // Kurucu bir insan olmalı: botlar sona.
                if (a.isBot != b.isBot) return a.isBot ? 1 : -1;
                return a.joinedAtMs.compareTo(b.joinedAtMs);
              }))
            .first
            .id;
    return {
      for (final e in players.entries)
        e.key: e.value.copyWith(isHost: e.key == effectiveHost),
    };
  }

  String _hostIdOf(Map<String, Player> players) =>
      players.values.firstWhere((p) => p.isHost).id;

  /// Genel amaçlı atomik güncelleme: odayı okur, [update] ile dönüştürür, yazar.
  /// Oyun içi tüm hamleler (GameRepository) bunu kullanır.
  Future<void> updateRoom(String code, Room Function(Room room) update) {
    return _db.runTransaction((tx) async {
      final room = await _read(tx, code);
      _write(tx, update(room));
    });
  }

  // ───────────────────────────────────────────────────────────────
  // Oyun hızı / süre modu (bekleme odasında, sadece kurucu)
  // ───────────────────────────────────────────────────────────────

  Future<void> updateSettings({
    required String code,
    required String uid,
    required GameSettings settings,
  }) {
    return _db.runTransaction((tx) async {
      final room = await _read(tx, code);
      if (!room.isHost(uid)) {
        throw const RoomException('Oyun modunu sadece oda kurucusu seçebilir.');
      }
      if (room.status != RoomStatus.waiting) {
        throw const RoomException('Oyun başladıktan sonra mod değişmez.');
      }
      _write(tx, room.copyWith(settings: settings));
    });
  }

  // ───────────────────────────────────────────────────────────────
  // Oyunu başlat → Zar Düellosu
  // ───────────────────────────────────────────────────────────────

  Future<void> startGame({required String code, required String uid}) {
    return _db.runTransaction((tx) async {
      final room = await _read(tx, code);
      if (!room.isHost(uid)) {
        throw const RoomException('Oyunu sadece oda kurucusu başlatabilir.');
      }
      if (room.status != RoomStatus.waiting) {
        throw const RoomException('Oyun zaten başlatıldı.');
      }
      if (room.players.length < GameRules.minPlayers) {
        throw const RoomException(
            'Başlamak için en az ${GameRules.minPlayers} oyuncu gerekli.');
      }

      final ids = [for (final p in room.playersByJoinOrder) p.id];
      _write(
        tx,
        room.copyWith(
          status: RoomStatus.orderDuel,
          orderDuel: OrderDuel.start(ids),
          players: GameInitializer.resetPlayers(
              room.players, room.settings.speed.startingMoney),
          clearGame: true,
        ),
      );
    });
  }

  /// Sıra belirleme zarı atar. Atılan zarı döner (yerel animasyon için).
  /// Son atışla sıralama kesinleşirse oyun aynı transaction'da başlar.
  Future<DiceRoll> rollForOrder({required String code, required String uid}) {
    return _db.runTransaction<DiceRoll>((tx) async {
      final room = await _read(tx, code);
      final duel = room.orderDuel;
      if (room.status != RoomStatus.orderDuel || duel == null) {
        throw const RoomException('Şu an sıra belirleme aşamasında değiliz.');
      }

      final roll = _dice.roll();
      final OrderDuel next;
      try {
        next = duel.applyRoll(uid, roll);
      } on StateError catch (e) {
        throw RoomException(e.message);
      }

      _write(
        tx,
        next.isComplete ? _beginGame(room, next) : room.copyWith(orderDuel: next),
      );
      return roll;
    });
  }

  /// Düello bitti → oyun durumunu kur. Düello kaydı sıralama tablosunu
  /// göstermek için odada kalır.
  Room _beginGame(Room room, OrderDuel finishedDuel) {
    final order = finishedDuel.finalOrder
        .where(room.players.containsKey)
        .toList();
    // Harita oyuncu sayısına göre (maraton modunda her zaman en geniş)
    // seçilir; para ve maaş oyun hızından gelir.
    final speed = room.settings.speed;
    final boardSize = speed.boardFor(order.length);
    final players =
        GameInitializer.resetPlayers(room.players, speed.startingMoney);
    return room.copyWith(
      status: RoomStatus.playing,
      orderDuel: finishedDuel,
      players: players,
      game: GameInitializer.create(
        order,
        players,
        boardSize: boardSize,
        settings: room.settings,
        nowMs: _now,
      ),
    );
  }
}
