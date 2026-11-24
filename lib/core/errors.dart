/// Kullanıcıya olduğu gibi gösterilebilen, Türkçe oyun hatası.
class GameException implements Exception {
  final String message;
  const GameException(this.message);

  @override
  String toString() => message;
}
