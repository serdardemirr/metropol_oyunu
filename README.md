# Metropol

Arkadaşlarla aynı odada, her biri kendi telefonundan gerçek zamanlı oynanan
Metropol tarzı emlak oyunu. Flutter + Firebase.

## Kurulum

### A. Sadece testler (Firebase gerekmez)

Oyun kuralları (`lib/logic`, `lib/models`, `lib/data`, `lib/core`) Firebase'e
bağlı değildir; testler Firebase kurulmadan çalışır.

```
flutter --version        # 3.27 veya üstü olmalı (Dart 3.6+)
flutter create --project-name metropol --platforms android,ios .
flutter pub get
flutter analyze
flutter test
```

`flutter create .` yalnızca eksik dosyaları (android/, ios/, .gitignore...)
ekler; mevcut `lib/`, `test/` ve `pubspec.yaml` dosyalarının üzerine yazmaz.

### B. Uygulamayı telefonda çalıştırmak

1. **Firebase konsolu** (console.firebase.google.com) → yeni proje, sonra:
   - Authentication → Sign-in method → **Anonymous**'ı aç
   - **Firestore Database** oluştur
   - **Realtime Database** oluştur — bunu `flutterfire configure`'dan ÖNCE yap,
     yoksa yapılandırmaya `databaseURL` girmez ve çevrimiçi takibi çalışmaz.
2. **CLI araçları** (bir kere):
   ```
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. **Projeyi bağla** (`lib/firebase_options.dart` yer tutucusunun üzerine yazar,
   Android için `google-services.json`, iOS için `GoogleService-Info.plist` ekler):
   ```
   flutterfire configure --platforms=android,ios
   ```
4. **Güvenlik kurallarını yükle** (`firebase.json` hazır):
   ```
   firebase use --add
   firebase deploy --only firestore:rules,database
   ```
5. **Platform ayarları** (`flutter create` sonrasında bir kere):
   - **Android** `android/app/build.gradle(.kts)` → `minSdk = 23`
     (Firebase Auth bunu ister; `flutter.minSdkVersion` daha düşükse derleme hata verir).
   - **Android** `android/app/src/main/AndroidManifest.xml` → `<manifest>` içine
     `<uses-permission android:name="android.permission.INTERNET"/>`
     (debug derlemede otomatik var, release derlemede yoksa Firebase bağlanamaz).
   - **iOS** `ios/Podfile` → en üstte `platform :ios, '13.0'` (Firebase iOS SDK
     en az iOS 13 ister); ardından `cd ios; pod install`.
6. **Çalıştır:** `flutter run`
7. (Önerilir) Firestore → **TTL** politikası: `rooms` koleksiyonu, `expireAt` alanı.
   Terk edilmiş odalar 12 saat sonra silinir, 4 haneli kodlar yeniden kullanılır.

### Sık hatalar

| Hata | Çözüm |
|------|-------|
| `Firebase yapılandırılmadı...` (UnsupportedError) | `flutterfire configure` çalıştırılmadı |
| `minSdkVersion 21 cannot be smaller than 23` | Adım 5, Android `minSdk = 23` |
| iOS `pod install` hatası / deployment target | Adım 5, `platform :ios, '13.0'` |
| `databaseURL` / Realtime Database bağlanamıyor | RTDB'yi oluşturup `flutterfire configure`'ı tekrar çalıştır |
| `permission-denied` | Adım 4'teki kurallar yüklenmedi ya da Anonymous giriş kapalı |
| `pub get` sürüm çakışması | `flutter pub upgrade --major-versions` |
| Ses çalmıyor | Normal: `assets/sounds/` içine MP3 dosyaları eklenmeli |

## Klasör yapısı

```
lib/
  core/constants/game_rules.dart   Tüm sabitler (2500M başlangıç, 200M maaş, kodes...)
  core/utils/                      Zar, oda kodu üretici
  models/                          Player, Tile, TileState, GameCard, GameState, OrderDuel, Room
  data/cities_data.dart            81 il, ucuzdan pahalıya sıralı (plaka, bölge)
  data/board_layout.dart           Oyuncu sayısına göre 28 / 44 / 108 karelik harita üreticisi
  data/card_data.dart              Şans / Kamu Fonu desteleri
  logic/game_engine.dart           Tüm oyun kuralları (saf fonksiyonlar, birim testli)
  services/                        Auth, profil, oda/oyun deposu (Firestore), çevrimiçi + mikrofon
                                   durumu (RTDB), ses, sesli sohbet arayüzü (voice_chat_service.dart)
  screens/                         Profil, ana ekran, oda, bekleme odası, zar düellosu, kurallar
  screens/game/                    Tahta, kareler, tapu kartı, eylem paneli, mülklerim, müzayede,
                                   teklif/takas ekranları, oyun ekranı
  widgets/                         Piyon sembolleri ve seçici, 3D zar, mikrofon, efektler
assets/sounds/                     Ses dosyaları (adlar için klasördeki README'ye bak)
```

## Mimari notları

- Tüm oda durumu tek Firestore dokümanında (`rooms/{kod}`) tutulur ve her değişiklik
  transaction ile yazılır; eşzamanlı zar atma/katılma veriyi bozmaz.
- Realtime Database sadece çevrimiçi/çevrimdışı takibi için (`onDisconnect`).
- Hamleler `GameEngine` içinde saf fonksiyon olarak çalışır ve `updateRoom`
  transaction'ı ile yazılır. Efektler oyun günlüğündeki sıra numaralı olaylardan
  tetiklenir; böylece her telefon aynı sesi/animasyonu aynı anda oynatır.
- Zar şu an istemcide atılıyor. Arkadaş grubu için yeterli; ileride hile
  koruması için Cloud Functions'a taşınmalı.

## Oyun modları

Oda kurucusu bekleme odasında seçer; herkes seçili modu ve kurallarını görür.

| Mod | Başlangıç | Maaş | İnşaat | Bitiş | Harita |
|-----|-----------|------|--------|-------|--------|
| ⚡ Hızlı (20–30 dk) | 1.500M | 150M | Tek ile bile ev/gökdelen | İlk iflasta ya da 25 dk dolunca; Net Varlık en yüksek kazanır | Kişi sayısına göre |
| 🎲 Normal | 2.500M | 200M | Klasik (grubun tamamı) | Son oyuncu kalana kadar; isteğe bağlı 60 dk sayaç | Kişi sayısına göre |
| 🏔️ Maraton | 4.000M | 300M | Klasik | Son oyuncu kalana kadar | Her zaman Dev Türkiye |

Net Varlık = nakit + tapu değerleri (ipotekliyse ipotek düşülür) + bina maliyetleri.
Süre sınırı cihaz saatleriyle ölçülür; süre dolunca istemciler oyunu bitirme
isteği gönderir, sunucu ilk geçerli isteği uygular.

## Haritalar

| Oyuncu | Harita | Kare | İl |
|--------|--------|------|----|
| 2-3 | Kompakt | 28 | 16 popüler il |
| 4-5 | Standart | 44 | 7 bölgeden 25 il |
| 6-8 (ya da Maraton) | Dev Türkiye | 108 | 81 ilin tamamı |

İller `cities_data.dart` içinde ucuzdan pahalıya sıralıdır (oyun dengesi için
yapılmış yaklaşık bir sıralama). Fiyat: kademeye göre 60M → 400M; kira = fiyat ×
[0.08, 0.4, 1.15, 2.9, 3.7, 4.5]; ev maliyeti 50M → 200M.

## Botlar (tek başına test)

Bekleme odasında kurucu **Bot Ekle** ile odaya bilgisayar oyuncusu ekler
(benzersiz isim, boş sembol ve renk). Kurucu botu ✕ ile çıkarabilir.

- Bot hamlelerini **kurucunun telefonu** yapar (`lib/services/bot_driver.dart`);
  karar mantığı Firebase'siz ve test edilebilir (`lib/logic/bot_brain.dart`).
- Bot sırası gelince 1–2 sn bekleyip zar atar, il alır, bina diker, borcunu
  kapatır ve sırayı devreder; müzayedede tapu fiyatına kadar artırır, kârlı
  takası kabul eder.
- Kurucu uygulamayı arka plana alırsa botlar bekler, geri dönünce devam eder.
- Kurucu her zaman bir insandır; odada sadece botlar kalırsa oda kapanır.

## Sesli sohbet

`PlaceholderVoiceChatService` mikrofon durumunu (kapalı/açık/konuşuyor) diğer
oyunculara gösterir ama ses taşımaz. Gerçek ses için `VoiceChatService`
arayüzünü Agora (`agora_rtc_engine`) ya da WebRTC (`flutter_webrtc`) ile uygulayıp
`AppServices.init()` içinde değiştirin; mikrofon izinlerini (Android
`RECORD_AUDIO`, iOS `NSMicrophoneUsageDescription`) eklemeyi unutmayın.
