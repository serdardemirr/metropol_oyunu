/// Oyunun haritadan bağımsız sabit kuralları.
/// Haritaya bağlı değerler (kare sayısı, kodes konumu, başlangıç parası,
/// maaş) [BoardLayout] içindedir. Para birimi "M" (milyon) cinsinden tam sayı.
class GameRules {
  GameRules._();

  // Oda
  static const int minPlayers = 2;
  static const int maxPlayers = 8;
  static const int roomCodeLength = 4;

  /// Bu süreden eski odalar "terk edilmiş" sayılır ve kodları yeniden kullanılabilir.
  static const Duration staleRoomAfter = Duration(hours: 12);

  /// Oyuncu modelinin varsayılan parası (oyun başında haritanınkiyle değişir).
  static const int startingMoney = 2500;

  // Kodes
  static const int jailBail = 100;
  static const int maxJailTurns = 3;
  static const int doublesToJail = 3; // üst üste 3 çift = kodes

  // İnşaat: 0 = arsa, 1-4 = ev, 5 = gökdelen
  static const int maxBuildingLevel = 5;
  static const int skyscraperLevel = 5;

  // İpotek
  /// İpotek kaldırma bedeli = ipotek değeri * (1 + faiz)
  static const double mortgageInterest = 0.10;

  // Açık artırma (müzayede)
  static const Duration auctionDuration = Duration(seconds: 15);

  /// Her yeni tekliften sonra kalan süre bu değere sıfırlanır.
  static const Duration auctionBidReset = Duration(seconds: 5);
  static const List<int> auctionQuickBids = [50, 100];

  // Ticaret teklifleri
  static const int maxOpenOffers = 12;

  // Kayıt
  static const int maxLogEntries = 40;
}
