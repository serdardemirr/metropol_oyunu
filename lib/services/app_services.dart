import 'auth_service.dart';
import 'game_repository.dart';
import 'presence_service.dart';
import 'profile_service.dart';
import 'room_repository.dart';
import 'sound_service.dart';
import 'voice_chat_service.dart';

/// Basit servis bulucu. Firebase başlatıldıktan sonra [init] çağrılır.
class AppServices {
  AppServices._();

  static late final AuthService auth;
  static late final ProfileService profile;
  static late final RoomRepository rooms;
  static late final PresenceService presence;
  static late final GameRepository game;
  static late final SoundService sound;
  static late final VoiceChatService voice;

  static void init() {
    auth = AuthService();
    profile = ProfileService();
    rooms = RoomRepository();
    presence = PresenceService();
    game = GameRepository(rooms);
    sound = SoundService();
    // Gerçek sesli sohbet için burada Agora/WebRTC uygulamasıyla değiştir.
    voice = PlaceholderVoiceChatService(presence);
  }
}
