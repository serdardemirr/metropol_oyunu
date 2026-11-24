import '../core/utils/dice.dart';

/// Zar düellosundaki tek bir atış kaydı.
class DuelRollRecord {
  final int round;
  final String playerId;
  final DiceRoll roll;

  const DuelRollRecord({
    required this.round,
    required this.playerId,
    required this.roll,
  });

  Map<String, dynamic> toMap() => {
        'round': round,
        'playerId': playerId,
        ...roll.toMap(),
      };

  factory DuelRollRecord.fromMap(Map<String, dynamic> map) => DuelRollRecord(
        round: (map['round'] as num).toInt(),
        playerId: map['playerId'] as String,
        roll: DiceRoll.fromMap(map),
      );
}

/// "Zar Düellosu ile Sıra Belirleme" durumu ve kuralları.
///
/// Algoritma:
///  * [groups] sıralı bir grup listesidir. Önceki gruptaki herkes sonraki
///    gruptaki herkesten önce oynar. Tek kişilik grup = sırası kesinleşmiş.
///  * Başta tüm oyuncular tek bir gruptadır.
///  * "Aktif grup", birden fazla kişi içeren İLK gruptur. Bu gruptakiler
///    sırayla (grup içi sırayla) zar atar.
///  * Gruptaki herkes attığında grup, toplam zara göre büyükten küçüğe
///    sıralanır ve eşit atanlar aynı alt grupta kalacak şekilde bölünür.
///    Böylece sadece eşitlik yaşayanlar kendi aralarında tekrar atar.
///  * Tüm gruplar tek kişilik olduğunda sıralama tamamdır.
///
/// Sınıf değişmezdir (immutable); her atış yeni bir nesne döndürür.
class OrderDuel {
  final List<List<String>> groups;
  final Map<String, DiceRoll> currentRolls;
  final int round;
  final List<DuelRollRecord> history;
  final DuelRollRecord? lastRoll;

  const OrderDuel({
    required this.groups,
    this.currentRolls = const {},
    this.round = 1,
    this.history = const [],
    this.lastRoll,
  });

  factory OrderDuel.start(List<String> playerIds) {
    if (playerIds.length < 2) {
      throw ArgumentError('Düello için en az 2 oyuncu gerekir.');
    }
    return OrderDuel(groups: [List.unmodifiable(playerIds)]);
  }

  int get activeGroupIndex => groups.indexWhere((g) => g.length > 1);

  bool get isComplete => activeGroupIndex == -1;

  /// Şu an zar atan grup (eşitlik turunda sadece berabere kalanlar).
  List<String> get activeGroup =>
      isComplete ? const [] : groups[activeGroupIndex];

  /// Aktif gruptakiler daha önceki bir turda zaten attıysa bu bir eşitlik turudur.
  bool get isTieBreak =>
      !isComplete &&
      history.any((r) => r.round < round && activeGroup.contains(r.playerId));

  /// Sıradaki zar atacak oyuncu (yoksa null).
  String? get currentRollerId {
    for (final id in activeGroup) {
      if (!currentRolls.containsKey(id)) return id;
    }
    return null;
  }

  /// Kesinleşmiş sıra. Sadece [isComplete] true iken tam listedir.
  List<String> get finalOrder => [for (final g in groups) ...g];

  /// Bir oyuncunun en son attığı zar (sıralama tablosu için).
  DiceRoll? lastRollOf(String playerId) {
    for (final r in history.reversed) {
      if (r.playerId == playerId) return r.roll;
    }
    return null;
  }

  /// [playerId] oyuncusunun [roll] atışını uygular.
  /// Sırası gelmeyen oyuncu atarsa [StateError] fırlatır.
  OrderDuel applyRoll(String playerId, DiceRoll roll) {
    if (isComplete) {
      throw StateError('Sıralama zaten kesinleşti.');
    }
    if (currentRollerId != playerId) {
      throw StateError('Şu an zar atma sırası sende değil.');
    }

    final record = DuelRollRecord(round: round, playerId: playerId, roll: roll);
    final newRolls = Map<String, DiceRoll>.from(currentRolls)
      ..[playerId] = roll;
    final newHistory = List<DuelRollRecord>.from(history)..add(record);

    final group = activeGroup;
    final allRolled = group.every(newRolls.containsKey);

    if (!allRolled) {
      return OrderDuel(
        groups: groups,
        currentRolls: newRolls,
        round: round,
        history: newHistory,
        lastRoll: record,
      );
    }

    // Grup tamamlandı → büyükten küçüğe sırala, eşitleri birlikte tut.
    final indexed = group.asMap().entries.toList()
      ..sort((a, b) {
        final byTotal =
            newRolls[b.value]!.total.compareTo(newRolls[a.value]!.total);
        // Dart'ın sort'u kararlı değildir; eşitlikte ilk sırayı koru.
        return byTotal != 0 ? byTotal : a.key.compareTo(b.key);
      });

    final buckets = <List<String>>[];
    int? lastTotal;
    for (final e in indexed) {
      final total = newRolls[e.value]!.total;
      if (total != lastTotal) {
        buckets.add(<String>[]);
        lastTotal = total;
      }
      buckets.last.add(e.value);
    }

    final idx = activeGroupIndex;
    final newGroups = <List<String>>[
      ...groups.sublist(0, idx),
      ...buckets.map(List<String>.unmodifiable),
      ...groups.sublist(idx + 1),
    ];

    return OrderDuel(
      groups: newGroups,
      currentRolls: const {},
      round: round + 1,
      history: newHistory,
      lastRoll: record,
    );
  }

  /// Oyuncu düello sırasında odadan ayrılırsa onu tüm gruplardan çıkarır.
  OrderDuel removePlayer(String playerId) {
    final newGroups = groups
        .map((g) => g.where((id) => id != playerId).toList())
        .where((g) => g.isNotEmpty)
        .toList();
    final newRolls = Map<String, DiceRoll>.from(currentRolls)
      ..remove(playerId);
    return OrderDuel(
      groups: newGroups,
      currentRolls: newRolls,
      round: round,
      history: history,
      lastRoll: lastRoll,
    );
  }

  // Firestore iç içe dizi (array of arrays) desteklemez → gruplar map listesi.
  Map<String, dynamic> toMap() => {
        'groups': [
          for (final g in groups) {'ids': g}
        ],
        'currentRolls': {
          for (final e in currentRolls.entries) e.key: e.value.toMap()
        },
        'round': round,
        'history': [for (final r in history) r.toMap()],
        'lastRoll': lastRoll?.toMap(),
      };

  factory OrderDuel.fromMap(Map<String, dynamic> map) {
    final rawGroups = (map['groups'] as List? ?? const []);
    final rawRolls =
        Map<String, dynamic>.from(map['currentRolls'] as Map? ?? const {});
    final rawHistory = (map['history'] as List? ?? const []);
    final rawLast = map['lastRoll'];

    return OrderDuel(
      groups: [
        for (final g in rawGroups)
          List<String>.from((g as Map)['ids'] as List),
      ],
      currentRolls: {
        for (final e in rawRolls.entries)
          e.key: DiceRoll.fromMap(Map<String, dynamic>.from(e.value as Map)),
      },
      round: (map['round'] as num?)?.toInt() ?? 1,
      history: [
        for (final r in rawHistory)
          DuelRollRecord.fromMap(Map<String, dynamic>.from(r as Map)),
      ],
      lastRoll: rawLast == null
          ? null
          : DuelRollRecord.fromMap(Map<String, dynamic>.from(rawLast as Map)),
    );
  }
}
