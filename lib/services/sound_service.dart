import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Oyun sesleri. Dosyalar `assets/sounds/<ad>.mp3` (bkz. assets/sounds/README.md).
/// Dosya yoksa ya da çalınamazsa sessizce geçer; oyun asla sesten dolayı çökmez.
enum Sfx { dice, cash, build, siren, card, win }

class SoundService {
  final Map<Sfx, AudioPlayer> _players = {};
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  Future<void> play(Sfx sfx) async {
    if (!enabled.value) return;
    try {
      final player = _players.putIfAbsent(sfx, AudioPlayer.new);
      await player.stop();
      await player.play(AssetSource('sounds/${sfx.name}.mp3'));
    } catch (e) {
      debugPrint('Ses çalınamadı (${sfx.name}): $e');
    }
  }

  void toggle() => enabled.value = !enabled.value;
}
