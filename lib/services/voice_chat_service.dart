import 'dart:async';

import 'package:flutter/foundation.dart';

import 'presence_service.dart';

/// Mikrofonun görünen durumu.
enum MicState {
  /// Sesli sohbet servisi bağlı değil / bu cihazda desteklenmiyor.
  unavailable,

  /// Mikrofon kapalı (sessiz).
  off,

  /// Mikrofon açık, şu an ses yok.
  on,

  /// Mikrofon açık ve kullanıcı konuşuyor.
  speaking;

  static MicState fromName(Object? name) => MicState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => MicState.off,
      );
}

/// Gerçek zamanlı sesli sohbet için modüler arayüz.
///
/// Arayüz (mikrofon ikonu, oyuncu şeridindeki göstergeler) yalnızca bu
/// sınıfa bağlıdır. Gerçek bir sağlayıcı eklemek için bu arayüzü uygulayan
/// bir sınıf yazıp [AppServices.init] içinde değiştirmek yeterlidir:
///
/// * **Agora** (`agora_rtc_engine`): [join] → `joinChannel(channelId: roomCode)`,
///   [setMicEnabled] → `muteLocalAudioStream(!on)`,
///   `onAudioVolumeIndication` → konuşma algılama → [MicState.speaking].
/// * **WebRTC** (`flutter_webrtc`): oda başına mesh/SFU bağlantısı; sinyalleşme
///   için mevcut Firebase Realtime Database kullanılabilir.
///
/// Her iki durumda da mikrofon izni (Android `RECORD_AUDIO`, iOS
/// `NSMicrophoneUsageDescription`) eklenmelidir.
abstract class VoiceChatService {
  /// Bu cihazdaki mikrofonun durumu.
  ValueListenable<MicState> get micState;

  /// Gerçek ses taşıyan bir sağlayıcı bağlı mı?
  bool get isAudioConnected;

  Future<void> join({required String roomCode, required String uid});
  Future<void> leave();
  Future<void> setMicEnabled(bool on);

  Future<void> toggleMic() => setMicEnabled(micState.value == MicState.off);
}

/// Ses taşımayan yer tutucu uygulama: mikrofon durumunu yönetir ve diğer
/// oyunculara (Realtime Database üzerinden) yayınlar, ama ses iletmez.
/// Gerçek sağlayıcı bağlanana kadar arayüz bununla tam çalışır.
class PlaceholderVoiceChatService extends VoiceChatService {
  PlaceholderVoiceChatService(this._presence);

  final PresenceService _presence;
  final ValueNotifier<MicState> _state = ValueNotifier(MicState.off);
  String? _roomCode;
  String? _uid;

  @override
  ValueListenable<MicState> get micState => _state;

  @override
  bool get isAudioConnected => false;

  @override
  Future<void> join({required String roomCode, required String uid}) async {
    _roomCode = roomCode;
    _uid = uid;
    _state.value = MicState.off;
    await _publish();
  }

  @override
  Future<void> leave() async {
    _state.value = MicState.off;
    _roomCode = null;
    _uid = null;
  }

  @override
  Future<void> setMicEnabled(bool on) async {
    _state.value = on ? MicState.on : MicState.off;
    await _publish();
  }

  Future<void> _publish() async {
    final code = _roomCode, uid = _uid;
    if (code == null || uid == null) return;
    try {
      await _presence.setMic(roomCode: code, uid: uid, state: _state.value);
    } catch (e) {
      debugPrint('Mikrofon durumu yayınlanamadı: $e');
    }
  }
}
