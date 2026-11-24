import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'voice_chat_service.dart';

/// Realtime Database ile "çevrimiçi mi?" takibi.
///
/// Firestore'un bağlantı kopmasını algılayan bir mekanizması yok; RTDB'nin
/// `onDisconnect` özelliği telefon kapandığında/uygulama öldüğünde bile
/// sunucu tarafında çalışır. Yol: `presence/{roomCode}/{uid}`.
class PresenceService {
  PresenceService({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;
  StreamSubscription<DatabaseEvent>? _connSub;
  DatabaseReference? _myRef;

  /// Odaya girince çağır. Bağlantı her geri geldiğinde kaydı yeniler.
  Future<void> goOnline({required String roomCode, required String uid}) async {
    await goOffline();
    final ref = _db.ref('presence/$roomCode/$uid');
    _myRef = ref;

    _connSub = _db.ref('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value != true) return;
      await ref.onDisconnect().set({
        'online': false,
        'mic': MicState.off.name,
        'lastSeen': ServerValue.timestamp,
      });
      // update: mikrofon durumunu silmesin
      await ref.update({
        'online': true,
        'lastSeen': ServerValue.timestamp,
      });
    });
  }

  /// Odadan çıkınca çağır.
  Future<void> goOffline() async {
    await _connSub?.cancel();
    _connSub = null;
    final ref = _myRef;
    _myRef = null;
    if (ref != null) {
      await ref.onDisconnect().cancel();
      await ref.remove();
    }
  }

  /// Odadaki oyuncuların çevrimiçi durumları: uid -> online.
  Stream<Map<String, bool>> watchRoom(String roomCode) {
    return _db.ref('presence/$roomCode').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return const <String, bool>{};
      return {
        for (final e in raw.entries)
          e.key.toString():
              (e.value is Map && (e.value as Map)['online'] == true),
      };
    });
  }

  /// Bu oyuncunun mikrofon durumunu diğerlerine yayınlar.
  Future<void> setMic({
    required String roomCode,
    required String uid,
    required MicState state,
  }) =>
      _db.ref('presence/$roomCode/$uid').update({'mic': state.name});

  /// Odadaki oyuncuların mikrofon durumları: uid -> durum.
  Stream<Map<String, MicState>> watchMics(String roomCode) {
    return _db.ref('presence/$roomCode').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return const <String, MicState>{};
      return {
        for (final e in raw.entries)
          if (e.value is Map)
            e.key.toString(): (e.value as Map)['online'] == true
                ? MicState.fromName((e.value as Map)['mic'])
                : MicState.off,
      };
    });
  }
}
