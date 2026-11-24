import '../data/board_layout.dart';

/// Oyun hızı / süre modu. Oda kurucusu bekleme odasında seçer.
enum GameSpeed {
  fast(
    label: 'Hızlı Oyun',
    duration: '20–30 dk',
    emoji: '⚡',
    startingMoney: 1500,
    salary: 150,
    quickBuild: true,
    endOnFirstBankruptcy: true,
    timeLimit: Duration(minutes: 25),
  ),
  normal(
    label: 'Normal Oyun',
    duration: 'Standart süre',
    emoji: '🎲',
    startingMoney: 2500,
    salary: 200,
    optionalTimeLimit: Duration(minutes: 60),
  ),
  marathon(
    label: 'Maraton',
    duration: 'Uzun oyun',
    emoji: '🏔️',
    startingMoney: 4000,
    salary: 300,
    forceGiantBoard: true,
  );

  const GameSpeed({
    required this.label,
    required this.duration,
    required this.emoji,
    required this.startingMoney,
    required this.salary,
    this.quickBuild = false,
    this.endOnFirstBankruptcy = false,
    this.forceGiantBoard = false,
    this.timeLimit,
    this.optionalTimeLimit,
  });

  final String label;
  final String duration;
  final String emoji;
  final int startingMoney;
  final int salary;

  /// Renk grubunun tamamı gerekmeden tek ile bile ev/otel dikilebilir.
  final bool quickBuild;

  /// İlk iflasta oyun biter; net varlığı en yüksek olan kazanır.
  final bool endOnFirstBankruptcy;

  /// Oyuncu sayısından bağımsız olarak en geniş Türkiye haritası açılır.
  final bool forceGiantBoard;

  /// Her zaman uygulanan süre sınırı.
  final Duration? timeLimit;

  /// Kurucunun açıp kapatabildiği süre sınırı.
  final Duration? optionalTimeLimit;

  BoardSize boardFor(int playerCount) => forceGiantBoard
      ? BoardSize.giant
      : BoardSize.forPlayerCount(playerCount);

  /// Bu ayarlarla oyunun süre sınırı (yoksa null).
  Duration? limitWith({required bool timerEnabled}) =>
      timeLimit ?? (timerEnabled ? optionalTimeLimit : null);

  /// Lobide ve kurallar ekranında gösterilen kısa özet.
  List<String> summary({required bool timerEnabled}) {
    final limit = limitWith(timerEnabled: timerEnabled);
    return [
      'Başlangıç parası ${startingMoney}M, tur maaşı ${salary}M.',
      quickBuild
          ? 'Hızlandırılmış inşaat: Renk grubunu tamamlamak gerekmez, sahip olduğun tek ile bile ev/gökdelen dikebilirsin.'
          : 'Klasik inşaat: Ev dikmek için renk grubundaki tüm illere sahip olmalısın.',
      if (forceGiantBoard)
        'Kişi sayısından bağımsız olarak 81 ilin tamamını içeren Dev Türkiye haritası açılır.'
      else
        'Harita kişi sayısına göre seçilir (2-3: Kompakt, 4-5: Standart, 6+: Dev Türkiye).',
      if (endOnFirstBankruptcy)
        'İlk oyuncu iflas ettiği anda${limit == null ? '' : ' ya da ${limit.inMinutes} dakika dolduğunda'} oyun biter; Net Varlığı en yüksek olan kazanır.'
      else if (limit != null)
        'Son oyuncu kalana kadar ya da ${limit.inMinutes} dakika dolana kadar sürer; süre dolarsa Net Varlığı en yüksek olan kazanır.'
      else
        'Son oyuncu ayakta kalana kadar sürer.',
    ];
  }

  static GameSpeed fromName(Object? name) => GameSpeed.values.firstWhere(
        (s) => s.name == name,
        orElse: () => GameSpeed.normal,
      );
}

/// Oda ayarları (bekleme odasında kurucu değiştirir).
class GameSettings {
  final GameSpeed speed;

  /// Normal modda isteğe bağlı 60 dakikalık süre sınırı.
  final bool timerEnabled;

  const GameSettings({this.speed = GameSpeed.normal, this.timerEnabled = false});

  Duration? get timeLimit => speed.limitWith(timerEnabled: timerEnabled);

  GameSettings copyWith({GameSpeed? speed, bool? timerEnabled}) => GameSettings(
        speed: speed ?? this.speed,
        timerEnabled: timerEnabled ?? this.timerEnabled,
      );

  Map<String, dynamic> toMap() =>
      {'speed': speed.name, 'timerEnabled': timerEnabled};

  factory GameSettings.fromMap(Object? raw) {
    if (raw is! Map) return const GameSettings();
    return GameSettings(
      speed: GameSpeed.fromName(raw['speed']),
      timerEnabled: raw['timerEnabled'] == true,
    );
  }
}

/// Oyunun neden bittiği.
enum GameEndReason {
  lastStanding('Son oyuncu ayakta kaldı'),
  firstBankruptcy('İlk iflas — Net Varlık sıralaması'),
  timeUp('Süre doldu — Net Varlık sıralaması');

  const GameEndReason(this.label);
  final String label;

  static GameEndReason? fromName(Object? name) {
    for (final r in GameEndReason.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}
