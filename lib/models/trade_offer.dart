/// Oyuncudan oyuncuya doğrudan satın alma / takas teklifi.
///
/// [fromId], [toId]'den [requestedTiles] karelerini ister; karşılığında
/// [offeredTiles] karelerini ve [cash] kadar parayı verir.
/// [cash] negatifse para ters yönde akar ([toId] öder).
class TradeOffer {
  final String id;
  final String fromId;
  final String toId;
  final List<int> requestedTiles;
  final List<int> offeredTiles;
  final int cash;
  final int createdAtMs;

  /// Karşı teklifse, yanıt verilen teklifin id'si.
  final String? counterOf;

  const TradeOffer({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.requestedTiles,
    required this.offeredTiles,
    required this.cash,
    required this.createdAtMs,
    this.counterOf,
  });

  bool involves(String playerId) => fromId == playerId || toId == playerId;

  bool touchesTile(int index) =>
      requestedTiles.contains(index) || offeredTiles.contains(index);

  bool get isEmpty =>
      requestedTiles.isEmpty && offeredTiles.isEmpty && cash == 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'requestedTiles': requestedTiles,
        'offeredTiles': offeredTiles,
        'cash': cash,
        'createdAtMs': createdAtMs,
        'counterOf': counterOf,
      };

  factory TradeOffer.fromMap(Map<String, dynamic> map) => TradeOffer(
        id: map['id'] as String,
        fromId: map['fromId'] as String,
        toId: map['toId'] as String,
        requestedTiles: _ints(map['requestedTiles']),
        offeredTiles: _ints(map['offeredTiles']),
        cash: (map['cash'] as num?)?.toInt() ?? 0,
        createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
        counterOf: map['counterOf'] as String?,
      );

  static List<int> _ints(Object? raw) =>
      [for (final v in (raw as List? ?? const [])) (v as num).toInt()];
}
