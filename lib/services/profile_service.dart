import 'package:shared_preferences/shared_preferences.dart';

import '../models/pawn_token.dart';

class UserProfile {
  final String name;
  final PawnToken pawn;

  const UserProfile({required this.name, required this.pawn});
}

/// Kullanıcı adı ve piyon tercihini cihazda saklar.
class ProfileService {
  static const _kName = 'profile.name';
  static const _kSymbol = 'profile.symbol';
  static const _kColor = 'profile.color';

  static const int minNameLength = 2;
  static const int maxNameLength = 14;

  Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName);
    if (name == null || name.trim().isEmpty) return null;
    return UserProfile(
      name: name,
      pawn: PawnToken(
        PawnSymbol.fromName(prefs.getString(_kSymbol)),
        PawnColor.fromName(prefs.getString(_kColor)),
      ),
    );
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, profile.name.trim());
    await prefs.setString(_kSymbol, profile.pawn.symbol.name);
    await prefs.setString(_kColor, profile.pawn.tint.name);
  }

  /// Hata mesajı döner; geçerliyse null.
  static String? validateName(String? raw) {
    final name = raw?.trim() ?? '';
    if (name.length < minNameLength) {
      return 'En az $minNameLength karakter olmalı.';
    }
    if (name.length > maxNameLength) {
      return 'En fazla $maxNameLength karakter olabilir.';
    }
    return null;
  }
}
