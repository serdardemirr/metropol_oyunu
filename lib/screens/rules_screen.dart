import 'package:flutter/material.dart';

import '../core/constants/game_rules.dart';
import '../models/game_speed.dart';

/// Üst bardaki "Kurallar" ikonundan açılan, kategorilere ayrılmış kurallar.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, this.settings});

  /// Odanın oyun modu; verilirse kurallar bu moda göre gösterilir.
  final GameSettings? settings;

  static Future<void> open(BuildContext context, {GameSettings? settings}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RulesScreen(settings: settings),
        ),
      );


  static final List<_Section> _sections = [
    _Section(Icons.flag, 'Amaç', [
      'Arsa, ulaşım hattı ve kamu kurumu satın al, kira topla.',
      'Diğer tüm oyuncular iflas ettiğinde ayakta kalan son oyuncu kazanır.',
      'Başlangıç parası ve maaş oyun moduna göre değişir: Hızlı 1.500M / 150M, Normal 2.500M / 200M, Maraton 4.000M / 300M.',
    ]),
    _Section(Icons.map, 'Harita (Türkiye İlleri)', [
      'Harita, oyunu başlatan oyuncu sayısına göre otomatik seçilir:',
      '  • 2-3 oyuncu: Kompakt harita — 28 kare, 16 popüler il, hızlı tempo.',
      '  • 4-5 oyuncu: Standart harita — 44 kare, 7 bölgeden dengeli 25 il.',
      '  • 6+ oyuncu: Dev Türkiye haritası — 108 kare, 81 ilin tamamı.',
      "İller ucuzdan pahalıya dizilir: Başlangıç'tan sonra uygun fiyatlı iller "
          '(Bayburt, Kilis...), ortada bölge/sanayi şehirleri (Samsun, Kayseri, '
          'Bursa...), sonda en pahalılar (Antalya, İzmir, Ankara, İstanbul).',
      'Arsa fiyatı, ev maliyeti ve kiralar ilin kademesine göre formülle hesaplanır.',
    ]),
    _Section(Icons.casino, 'Sıra Belirleme (Zar Düellosu)', [
      'Oyun başında herkes sırayla iki zar atar. En yüksek toplamı atan ilk oynar.',
      'Eşitlik olursa sadece berabere kalanlar kendi aralarında tekrar atar.',
      'Bu döngü tüm sıralama (1., 2., 3., ...) kesinleşene kadar sürer.',
    ]),
    _Section(Icons.directions_walk, 'Tur ve Zar', [
      'Sıran geldiğinde zar at; piyonun toplam kadar ilerler.',
      'Çift atarsan hamleni bitirdikten sonra bir kez daha atarsın.',
      'Üst üste ${GameRules.doublesToJail} kez çift atarsan doğrudan kodese girersin.',
      'Başlangıç karesinden her geçişinde oyun moduna göre maaş alırsın.',
      'Hamlen bitince "Sırayı Devret" ile sırayı sonraki oyuncuya verirsin.',
    ]),
    _Section(Icons.home_work, 'Satın Alma ve Kira', [
      'Sahipsiz bir kareye gelirsen tapu kartı açılır: "Satın Al" ya da "Pas Geç".',
      'Başkasının arsasına gelirsen kira ödersin. İpotekli arsadan kira alınmaz.',
      'Bir renk grubunun tamamına sahipsen boş arsalarının kirası iki katına çıkar.',
      'Ulaşım hatları: sahip olunan hat sayısına göre 25M / 50M / 100M / 200M.',
      'Kamu kurumları: zar toplamı × 4 (1 kurum), × 10 (2 kurum), × 20 (3 kurum).',
    ]),
    _Section(Icons.apartment, 'İnşaat', [
      'Normal ve Maraton modda: Bir renk grubundaki TÜM illerin sahibiysen, kendi sırandayken bina dikebilirsin.',
      'Hızlı modda: Grup şartı ve eşit dağılım yoktur; sahip olduğun tek ile bile bina dikebilirsin.',
      'Seviyeler: Arsa → 1 Ev → 2 Ev → 3 Ev → 4 Ev → Gökdelen.',
      'Eşit dağılım kuralı: bir arsaya 2. evi dikmek için gruptaki diğer arsalarda en az 1 ev olmalı.',
      'Her seviye kirayı katlayarak artırır. Gruptaki bir arsa ipotekliyse bina dikilemez.',
      'Binaları yarı fiyatına bankaya geri satabilirsin (yine eşit dağılımla, yüksekten başlayarak).',
    ]),
    _Section(Icons.style, 'Şans ve Kamu Fonu', [
      'Bu karelere gelince desteden bir kart çekilir ve hemen uygulanır.',
      'Örnekler: "En yakın istasyona ilerle", "Banka hatası lehine 150M", '
          '"Doğrudan kodese git", "Her oyuncudan 50M topla".',
      '"Kodesten Çıkış Kartı"nı gerekene kadar saklayabilirsin.',
    ]),
    _Section(Icons.local_police, 'Kodes', [
      'Kodese "Kodese Git" karesi, bir kart ya da 3 kez üst üste çift ile girilir.',
      'Kodesteyken sıran gelince üç seçeneğin var:',
      '  • Çift atmayı dene: çift gelirse çıkar ve o kadar ilerlersin.',
      '  • ${GameRules.jailBail}M kefalet öde ve normal zar at.',
      '  • Varsa "Kodesten Çıkış Kartı"nı kullan.',
      '${GameRules.maxJailTurns}. denemede de çift gelmezse kefaleti ödeyip zarın kadar ilerlersin.',
      'Kodesteyken de kira toplamaya devam edersin.',
    ]),
    _Section(Icons.account_balance, 'İpotek', [
      'Parası yetmeyen oyuncu, binasız arsalarını bankaya ipotek ettirip fiyatının yarısını alabilir.',
      'İpoteği kaldırmak için ipotek bedeli + %${(GameRules.mortgageInterest * 100).round()} faiz ödenir.',
      'İpotek etmek için o renk grubunda hiç bina olmamalıdır.',
    ]),
    _Section(Icons.money_off, 'Borç ve İflas', [
      'Ödeme yapamazsan paran eksiye düşer; zar atamaz ve sırayı devredemezsin.',
      'Borcunu kapatmak için bina satabilir ya da arsa ipotek ettirebilirsin.',
      'Hiçbir şekilde kapatamıyorsan "İflas Et" ile oyundan çekilirsin; '
          'mülklerin bankaya döner.',
      'Oyun sırasında odadan ayrılmak da iflas sayılır.',
    ]),
    _Section(Icons.gavel, 'Açık Artırma (Müzayede)', [
      "Kendi sırandayken (ya da borçluyken) Mülklerim'den bir tapuyu \"Açık Artırmaya Çıkar\" ve başlangıç fiyatını belirle.",
      'Herkesin ekranında müzayede penceresi açılır; süre ${GameRules.auctionDuration.inSeconds} saniyedir.',
      'Her yeni teklif kalan süreyi en az ${GameRules.auctionBidReset.inSeconds} saniyeye çıkarır. "+50M", "+100M" ya da özel tutar verilebilir.',
      'Süre bitince en yüksek teklifi veren tapuyu alır, para otomatik aktarılır. Teklif gelmezse tapu sahibinde kalır.',
      'Müzayede sürerken zar atılamaz ve sıra devredilemez.',
    ]),
    _Section(Icons.handshake, 'Doğrudan Teklif ve Takas', [
      'Başka bir oyuncunun iline dokun ya da üstteki oyuncu şeridinden oyuncuya dokun → "Teklif Gönder".',
      'Teklife nakit, kendi tapuların (takas) ya da ikisi birden konabilir; karşı taraftan para da istenebilir.',
      'Alıcı teklifi Kabul Et, Reddet ya da Karşı Teklif ile yanıtlar.',
      'Kural: Üzerinde ev/gökdelen bulunan bir grubun ili satılamaz, takas edilemez ve açık artırmaya çıkarılamaz; önce binalar bankaya yarı fiyatına satılmalıdır.',
      'İpotekli bir il el değiştirirse ipotekli olarak devredilir.',
    ]),
    _Section(Icons.mic, 'Uzaktan Oyun ve Mikrofon', [
      'Oda koduyla aynı odada ya da farklı şehirlerden birlikte oynanabilir.',
      'Üst bardaki mikrofon ikonu mikrofonunu açar/kapatır; diğer oyuncuların durumu oyuncu şeridinde görünür.',
      'Gerçek zamanlı sesli sohbet servisi (WebRTC/Agora) bağlanmaya hazırdır.',
    ]),
  ];

  /// En üstte: bu oyunun modu (verildiyse) ve tüm modların karşılaştırması.
  List<_Section> _modeSections() {
    final current = settings;
    return [
      if (current != null)
        _Section(
          Icons.speed,
          'Bu Oyunun Modu: ${current.speed.emoji} ${current.speed.label}',
          current.speed.summary(timerEnabled: current.timerEnabled),
        ),
      _Section(Icons.tune, 'Oyun Modları', [
        for (final s in GameSpeed.values) ...[
          '${s.emoji} ${s.label} (${s.duration}):',
          for (final line in s.summary(timerEnabled: false)) '  • $line',
          if (s.optionalTimeLimit != null)
            '  • İsteğe bağlı ${s.optionalTimeLimit!.inMinutes} dakikalık geri sayım açılabilir.',
        ],
        'Net Varlık = nakit + tapu değerleri (ipotekliyse ipotek düşülür) + bina maliyetleri.',
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Oyun Kuralları')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (i, s) in [..._modeSections(), ..._sections].indexed)
            ExpansionTile(
              initiallyExpanded: i == 0,
              leading: Icon(s.icon, color: theme.colorScheme.primary),
              title: Text(s.title, style: theme.textTheme.titleMedium),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in s.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      line.startsWith('  ') ? line : '• $line',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String title;
  final List<String> lines;
  const _Section(this.icon, this.title, this.lines);
}
