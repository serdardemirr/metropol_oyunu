/// Sahibinin başlattığı açık artırma (müzayede).
///
/// Süre cihaz saatleriyle ölçülür ([endsAtMs], milisaniye). Süre dolunca
/// herhangi bir istemci sonuçlandırma isteği gönderir; transaction sayesinde
/// sadece ilki uygulanır.
class Auction {
  final int tileIndex;
  final String sellerId;
  final int startPrice;
  final int? highestBid;
  final String? highestBidderId;
  final int endsAtMs;

  /// Her teklifte artar; arayüz yeni teklifi bununla fark eder.
  final int bidCount;

  const Auction({
    required this.tileIndex,
    required this.sellerId,
    required this.startPrice,
    required this.endsAtMs,
    this.highestBid,
    this.highestBidderId,
    this.bidCount = 0,
  });

  /// Bir sonraki geçerli teklifin alt sınırı.
  int get minimumBid => highestBid == null ? startPrice : highestBid! + 1;

  bool isOver(int nowMs) => nowMs >= endsAtMs;

  Auction withBid(String bidderId, int amount, int newEndsAtMs) => Auction(
        tileIndex: tileIndex,
        sellerId: sellerId,
        startPrice: startPrice,
        highestBid: amount,
        highestBidderId: bidderId,
        endsAtMs: newEndsAtMs,
        bidCount: bidCount + 1,
      );

  Map<String, dynamic> toMap() => {
        'tileIndex': tileIndex,
        'sellerId': sellerId,
        'startPrice': startPrice,
        'highestBid': highestBid,
        'highestBidderId': highestBidderId,
        'endsAtMs': endsAtMs,
        'bidCount': bidCount,
      };

  factory Auction.fromMap(Map<String, dynamic> map) => Auction(
        tileIndex: (map['tileIndex'] as num).toInt(),
        sellerId: map['sellerId'] as String,
        startPrice: (map['startPrice'] as num).toInt(),
        highestBid: (map['highestBid'] as num?)?.toInt(),
        highestBidderId: map['highestBidderId'] as String?,
        endsAtMs: (map['endsAtMs'] as num).toInt(),
        bidCount: (map['bidCount'] as num?)?.toInt() ?? 0,
      );
}
