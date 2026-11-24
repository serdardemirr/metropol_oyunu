import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/voice_chat_service.dart';

/// Üst bardaki mikrofon düğmesi: kapalı / açık / konuşuyor durumlarını gösterir.
class MicButton extends StatefulWidget {
  const MicButton({super.key});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _toldNoAudio = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final voice = AppServices.voice;
    await voice.toggleMic();
    if (!mounted) return;
    if (!voice.isAudioConnected &&
        voice.micState.value != MicState.off &&
        !_toldNoAudio) {
      _toldNoAudio = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sesli sohbet servisi henüz bağlı değil. Mikrofon '
            'durumun diğer oyunculara gösteriliyor.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MicState>(
      valueListenable: AppServices.voice.micState,
      builder: (context, state, _) {
        if (state == MicState.speaking) {
          if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
        } else if (_pulse.isAnimating) {
          _pulse.stop();
          _pulse.value = 0;
        }
        final (icon, color, tip) = switch (state) {
          MicState.unavailable => (Icons.mic_off, Colors.grey, 'Sesli sohbet yok'),
          MicState.off => (Icons.mic_off, Colors.white70, 'Mikrofonu aç'),
          MicState.on => (Icons.mic, Colors.greenAccent, 'Mikrofonu kapat'),
          MicState.speaking =>
            (Icons.graphic_eq, Colors.greenAccent, 'Konuşuyorsun'),
        };
        return IconButton(
          tooltip: tip,
          onPressed: state == MicState.unavailable ? null : _toggle,
          icon: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: state == MicState.off
                      ? Colors.transparent
                      : color.withValues(alpha: 0.4 + 0.6 * _pulse.value),
                  width: 2 + 2 * _pulse.value,
                ),
              ),
              child: child,
            ),
            child: Icon(icon, color: color),
          ),
        );
      },
    );
  }
}

/// Oyuncu şeridindeki küçük mikrofon göstergesi.
class MicIndicator extends StatelessWidget {
  const MicIndicator({super.key, required this.state, this.size = 14});

  final MicState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      MicState.on => Icon(Icons.mic, size: size, color: Colors.greenAccent),
      MicState.speaking =>
        Icon(Icons.graphic_eq, size: size, color: Colors.greenAccent),
      _ => Icon(Icons.mic_off, size: size, color: Colors.white38),
    };
  }
}
