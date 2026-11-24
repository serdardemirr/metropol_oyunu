/// Türkiye'nin 81 ili, UCUZDAN PAHALIYA sıralı.
///
/// Sıralama; il ekonomisinin büyüklüğü, nüfus ve turizm potansiyeli göz
/// önüne alınarak oyun dengesi için yapılmış yaklaşık bir kademelendirmedir
/// (resmi bir istatistik değildir). Listenin sırası = ilin "değer sırası";
/// tahtada Başlangıç'tan sonra ucuz iller, bitişe doğru pahalı iller gelir.
enum Region {
  marmara('Marmara'),
  ege('Ege'),
  akdeniz('Akdeniz'),
  icAnadolu('İç Anadolu'),
  karadeniz('Karadeniz'),
  doguAnadolu('Doğu Anadolu'),
  guneydogu('Güneydoğu Anadolu');

  const Region(this.label);
  final String label;
}

class City {
  final int plate;
  final String name;
  final Region region;

  /// 1 = en ucuz, 81 = en pahalı.
  final int rank;

  const City(this.plate, this.name, this.region, this.rank);
}

class CitiesData {
  CitiesData._();

  static const _m = Region.marmara;
  static const _e = Region.ege;
  static const _a = Region.akdeniz;
  static const _i = Region.icAnadolu;
  static const _k = Region.karadeniz;
  static const _d = Region.doguAnadolu;
  static const _g = Region.guneydogu;

  static const List<City> all = [
    // ── Kademe: en uygun fiyatlı iller ──
    City(69, 'Bayburt', _k, 1),
    City(75, 'Ardahan', _d, 2),
    City(62, 'Tunceli', _d, 3),
    City(79, 'Kilis', _g, 4),
    City(29, 'Gümüşhane', _k, 5),
    City(76, 'Iğdır', _d, 6),
    City(30, 'Hakkari', _d, 7),
    City(73, 'Şırnak', _g, 8),
    City(49, 'Muş', _d, 9),
    City(13, 'Bitlis', _d, 10),
    City(4, 'Ağrı', _d, 11),
    City(12, 'Bingöl', _d, 12),
    City(36, 'Kars', _d, 13),
    City(56, 'Siirt', _g, 14),
    City(8, 'Artvin', _k, 15),
    City(57, 'Sinop', _k, 16),
    City(74, 'Bartın', _k, 17),
    City(18, 'Çankırı', _i, 18),
    City(40, 'Kırşehir', _i, 19),
    City(66, 'Yozgat', _i, 20),
    City(24, 'Erzincan', _d, 21),
    City(2, 'Adıyaman', _g, 22),
    City(72, 'Batman', _g, 23),
    City(51, 'Niğde', _i, 24),
    City(70, 'Karaman', _i, 25),
    City(71, 'Kırıkkale', _i, 26),
    City(68, 'Aksaray', _i, 27),
    // ── Kademe: orta ölçekli iller ──
    City(5, 'Amasya', _k, 28),
    City(60, 'Tokat', _k, 29),
    City(37, 'Kastamonu', _k, 30),
    City(19, 'Çorum', _k, 31),
    City(11, 'Bilecik', _m, 32),
    City(78, 'Karabük', _k, 33),
    City(80, 'Osmaniye', _a, 34),
    City(15, 'Burdur', _a, 35),
    City(47, 'Mardin', _g, 36),
    City(28, 'Giresun', _k, 37),
    City(52, 'Ordu', _k, 38),
    City(53, 'Rize', _k, 39),
    City(77, 'Yalova', _m, 40),
    City(81, 'Düzce', _k, 41),
    City(64, 'Uşak', _e, 42),
    City(43, 'Kütahya', _e, 43),
    City(32, 'Isparta', _a, 44),
    City(3, 'Afyonkarahisar', _e, 45),
    City(14, 'Bolu', _k, 46),
    City(67, 'Zonguldak', _k, 47),
    City(58, 'Sivas', _i, 48),
    City(23, 'Elazığ', _d, 49),
    City(65, 'Van', _d, 50),
    City(44, 'Malatya', _d, 51),
    City(25, 'Erzurum', _d, 52),
    City(46, 'Kahramanmaraş', _a, 53),
    City(63, 'Şanlıurfa', _g, 54),
    // ── Kademe: gelişmiş bölge / sanayi şehirleri ──
    City(21, 'Diyarbakır', _g, 55),
    City(39, 'Kırklareli', _m, 56),
    City(22, 'Edirne', _m, 57),
    City(50, 'Nevşehir', _i, 58),
    City(17, 'Çanakkale', _m, 59),
    City(31, 'Hatay', _a, 60),
    City(61, 'Trabzon', _k, 61),
    City(10, 'Balıkesir', _m, 62),
    City(45, 'Manisa', _e, 63),
    City(9, 'Aydın', _e, 64),
    City(20, 'Denizli', _e, 65),
    City(54, 'Sakarya', _m, 66),
    City(59, 'Tekirdağ', _m, 67),
    City(55, 'Samsun', _k, 68),
    City(26, 'Eskişehir', _i, 69),
    City(38, 'Kayseri', _i, 70),
    City(33, 'Mersin', _a, 71),
    City(27, 'Gaziantep', _g, 72),
    City(42, 'Konya', _i, 73),
    City(1, 'Adana', _a, 74),
    City(41, 'Kocaeli', _m, 75),
    City(16, 'Bursa', _m, 76),
    // ── Kademe: en pahalı iller ──
    City(7, 'Antalya', _a, 77),
    City(48, 'Muğla', _e, 78),
    City(35, 'İzmir', _e, 79),
    City(6, 'Ankara', _i, 80),
    City(34, 'İstanbul', _m, 81),
  ];

  static City byName(String name) => all.firstWhere((c) => c.name == name);

  /// İsimlerle seçilen illeri değer sırasına göre döner.
  static List<City> pick(List<String> names) =>
      names.map(byName).toList()..sort((a, b) => a.rank.compareTo(b.rank));

  /// 2-3 oyuncu: popüler 16 il.
  static final List<City> compact = pick(const [
    'Bayburt', 'Kilis', //
    'Sinop', 'Amasya', 'Rize', //
    'Nevşehir', 'Trabzon', 'Samsun', //
    'Eskişehir', 'Kayseri', 'Gaziantep', //
    'Bursa', 'Antalya', 'İzmir', //
    'Ankara', 'İstanbul',
  ]);

  /// 4-5 oyuncu: 7 bölgeden dengeli seçilmiş 25 il.
  static final List<City> standard = pick(const [
    // Karadeniz
    'Bayburt', 'Sinop', 'Trabzon', 'Samsun',
    // Doğu Anadolu
    'Ardahan', 'Kars', 'Erzurum',
    // Güneydoğu Anadolu
    'Kilis', 'Mardin', 'Gaziantep',
    // İç Anadolu
    'Nevşehir', 'Eskişehir', 'Kayseri', 'Ankara',
    // Akdeniz
    'Hatay', 'Adana', 'Antalya',
    // Ege
    'Denizli', 'Aydın', 'Muğla', 'İzmir',
    // Marmara
    'Edirne', 'Çanakkale', 'Bursa', 'İstanbul',
  ]);
}
