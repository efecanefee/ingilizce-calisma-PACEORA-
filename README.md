<div align="center">

<img src="assets/images/paceora_logo.png" alt="Paceora" width="280">
<img src="assets/pace/wave.png" alt="Maskot Pace el sallıyor" height="200">

**Türkçe konuşanlar için günlük İngilizce çalışma uygulaması**

Seviyene göre haftalık program üretir, her gün ne çalışacağını söyler,
serini (streak) takip eder. Hesap gerekmez; ilerlemen cihazında kalır.

**Sürüm 1.4.0** · [Değişiklik günlüğü](CHANGELOG.md)

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini-Flash-8E75B2?logo=googlegemini&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-AI%20Logic-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-informational)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

---

## Neden?

Kurs uygulamalarının çoğu seni genel bir müfredata sokar. Paceora bunun tersini
yapar: adını, seviyeni ve günde kaç dakika ayırabildiğini sorar, sonra **sana
özel** bir program üretir. Program takvim haftasına değil, **başladığın güne**
bağlıdır: ilk günden itibaren 7 günlük bloklar halinde ilerler, her günün bir
dilbilgisi konusu ve bir kelime teması olur.

## 1.4.0 ile gelenler

- **Anahtarsız yapay zeka** — Firebase AI Logic ile çalışır; kullanıcıdan API
  anahtarı istenmez.
- **Program ilk günden başlar** — önceki günler "kaçırıldı" sayılmaz.
- **Aylık takvim** — güne dokun: dersi tekrar çöz, kaçırdığını telafi et ya da
  konuyu değiştir.
- **Pace her yerde** — tanıtım turu, 20 yeni poz ve hareketli kutlama.
- **Türkçe yardım** — ders, hikaye, sohbet, konuşma, yazma ve kartlarda
  "Türkçesi" düğmesi; çeviri sorularında kelime ipuçları.
- **Yazma pratiği, seviye atlama sınavı, arama** ve 5 dakikalık "Vaktim az" dersi.
- **Uyarlanan seviye testi** — sorular cevaplarına göre zorlaşır ya da kolaylaşır.
- **Sesler** — cevap, bitiş, rozet ve seviye sesleri; üst üste binmez.
- **Bildirimler ve Android ana ekran widget'ı.**

Tamamı: [CHANGELOG.md](CHANGELOG.md)

## Öne çıkanlar

### Öğrenme
- **Kişiye özel program** — Gemini (Flash), seviyene ve sürene göre 7 günlük
  konu akışı üretir; yeni blok gelince program kendiliğinden yenilenir.
- **Çok adımlı günlük ders** — kelime kartları → boşluk doldurma → Türkçeden
  İngilizceye çeviri → test. Soru sayısı günlük süreye göre değişir (5, 15, 30
  ya da 60 dakika). Zamanın yoksa "Vaktim az" ile 5 dakikalık ders açılır.
- **Yarıda bırakabilirsin** — her cevap anında cihaza yazılır; kaldığın adımdan
  devam edersin. Yarının dersi bugünden hazırlanır.
- **Hata defteri** — yanlışların 1, 3 ve 7 gün sonra derse döner; üst üste üç
  doğruda kapanır.
- **Aralıklı tekrar kartları** — SM-2 temelli. "Tekrar / Zor / İyi / Kolay"
  notuna göre yeni kart bugün, 1, 3 ya da 5 gün sonra yeniden gelir.
- **Günün hikayesi** — günün kelimeleriyle okuma parçası, sözlükçe ve anlama
  testi. Kelimeye dokun anlamını gör, istersen tamamını Türkçe oku ya da dinle.
- **8 kademeli seviye** — A2, B1-, B1, B1+, B2-, B2, B2+, C1.
- **Seviye testi** — 116 soruluk havuzdan 20 soru: dilbilgisi, kelime, okuma,
  dinleme. Her bölüm önceki cevaplara göre seçilir.
- **Seviye atlama** — 10 soruluk sınav (7 doğru geçer) ya da haftalık raporun
  önerisi. Öneri cihazda kuralla hesaplanır: en az 3 ders ve %85+ ortalama →
  yukarı; en az 2 ders ve %55 altı → aşağı.

### Pratik
- **AI ile sohbet** — 8 senaryo (kafe, otel, doktor, iş görüşmesi, havalimanı…);
  hatalar anında düzeltilir.
- **Konuşma ve dinle-yaz** — cümle kelime kelime puanlanır; yanlış kelimeye
  dokununca okunur, zorlandıkların listelenir. Yavaş okuma düğmesi var.
- **Yazma** — birkaç cümle yaz; hatalar işaretlenir ve Türkçe açıklanır.
- **Kelime Rallisi** — 60 saniyelik eşleştirme oyunu.

### Motivasyon
- **Seri** — gün atlarsan sıfırlanır; XP ile alınan **seri dondurma** kaçırılan
  bir günü korur. 3, 7, 14, 30… günde kutlama.
- **XP, seviye ve 13 rozet** — "Çaylak"tan "Efsane"ye. XP ayrı saklanmaz,
  çalışma geçmişinden hesaplanır. Yeni seviye ve rozet, hangi ekranda olursan ol
  konfeti ve kendi sesiyle gelir.
- **Maskot Pace** — çita Pace yol gösterir, kutlar, serine göre poz değiştirir.
  Dokununca dolabı açılır: XP ile 6 forma.
- **Bugünkü hedef ve aylık takvim** — sıradaki adım tek dokunuşla açılır.
- **Bildirimler** — günlük hatırlatma, günün kelimesi (09.00) ve pazar raporu
  (19.00). İlk açılışta izin istenir; sunucu kullanılmaz.
- **Android ana ekran widget'ı** — seri ve günün kelimesi.

### Güvenilirlik ve gizlilik
- **İnternetsiz de çalışır** — telefondaki 24 hazır ders ve yedek program
  devreye girer. Model yoğunsa sıradakine geçilir; hata açıkça yazılır.
- **Yerel veri** — ilerleme cihazdaki SQLite'ta. Yapay zekaya yalnızca içerik
  üretirken konu ve cevaplar gider; adın gitmez.
  ([Gizlilik politikası](docs/gizlilik-politikasi.md))
- **Yedekleme** — tüm ilerlemeyi tek bir JSON dosyasına aktar, yeni telefonda
  geri yükle.
- **Koyu/açık tema, 6 vurgu rengi** — koyu tema varsayılan. Renkler WCAG AA
  kontrast testinden geçer; "animasyonları azalt" ayarına uyulur.

## Ekranlar

Alt çubukta 5 sekme var: **Bugün, Pratik, Program, İlerleme, Ayarlar**.

| Ekran | İçerik |
|---|---|
| **Onboarding** | İsim → seviye (test ya da seçim) → günlük süre; sonra Pace turu |
| **Bugün** | Seri, seviye, günün dersi, günlük hedef, haftanın günleri |
| **Ders ve sonuç** | Dört adım, anında geri bildirim, skor ve tekrar listesi |
| **Pratik** | Sohbet, Kelime Rallisi, yazma, kartlar, hikaye, konuşma, dinle-yaz |
| **Program** | Hafta ve ay görünümü, gün ayrıntısı, telafi, arama |
| **İlerleme** | Seri takvimi, haftalık skorlar, biten dersler; kutular dokunulabilir |
| **Haftalık rapor** | Güçlü yönler, odak noktaları ve seviye önerisi |
| **Profil** | Avatar, rozet vitrini, XP |
| **Ayarlar** | Çalışma, Görünüm, Bildirimler, Verilerim, Gelişmiş, Hakkında |

## Kurulum

```bash
flutter pub get
```

Drift kod üretimi (`lib/data/database.g.dart`):

```bash
dart run build_runner build
```

> Proje yolunda ASCII olmayan karakter varsa (ör. `Masaüstü`) `--force-jit` ekle.

### Yapay zeka bağlantısı

Uygulama şu sırayla bağlanır:

1. **Kullanıcının kendi Gemini anahtarı** (isteğe bağlı) — Ayarlar → Gelişmiş.
   Telefonun güvenli kasasında saklanır.
2. **Firebase AI Logic** — anahtarsız, varsayılan yol (Android ve iOS). Gemini
   anahtarı Firebase'de durur; istekler App Check jetonuyla gider.
3. **Derlemeye verilen anahtar** — Firebase'in olmadığı platformlar için.

Üçüncü yol için proje kökünde `env.json` oluştur (`.gitignore`'da, depoya
girmez):

```json
{ "GEMINI_API_KEY": "anahtarınız" }
```

Anahtar [Google AI Studio](https://aistudio.google.com/apikey)'dan alınır.
Bağlantı sorunu olursa Ayarlar → Gelişmiş → **Bağlantıyı test et** nedeni
gösterir. Hiçbir bağlantı yoksa hazır dersler ve yedek program kullanılır.

> **Güvenlik:** `--dart-define` ile verilen anahtar derlenen uygulamanın içine
> girer ve APK/IPA'dan çıkarılabilir. GitHub iş akışlarını elle çalıştırırken
> **sürüm** seçeneğini kullan: `kisisel` anahtarı gömer (yalnızca kendi
> telefonun için), `paylasim` gömmez. `main`'e push'ta kişisel sürüm üretilir;
> o APK'yı başkasına verme.

### Çalıştırma

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

Web'de drift, `web/sqlite3.wasm` ve `web/drift_worker.js` dosyalarına ihtiyaç
duyar; ikisi de depoda mevcut. Windows masaüstü için Visual Studio'nun
"Desktop development with C++" iş yükü kurulu olmalı:

```bash
flutter run -d windows --dart-define-from-file=env.json
```

## iPhone'a kurulum

Windows'ta iOS derlemesi yapılamaz (Xcode yalnızca macOS'ta çalışır), bu yüzden
IPA GitHub Actions'ın macOS runner'ında üretilir; imzalamayı Windows'ta
Sideloadly kendi Apple ID'nle yapar.

1. **Anahtarı secret olarak ekle (isteğe bağlı):** GitHub → Settings → Secrets and variables →
   Actions → New repository secret → ad `GEMINI_API_KEY`, değer anahtarın.
   Anahtar koda girmez, yalnızca derleme sırasında `--dart-define` ile enjekte
   edilir.
2. **Derlemeyi başlat:** Actions sekmesi → *iOS IPA* → Run workflow.
3. **Çıktıyı indir:** Koşu bitince Artifacts altındaki `Paceora-unsigned-ipa`.
   İçinden `Paceora-unsigned.ipa` çıkar.
4. **Telefona kur:** [Sideloadly](https://sideloadly.io) ile iPhone'u USB'den
   bağla, IPA'yı sürükle, Apple ID'nle imzala ve kur. Kurulumdan sonra
   telefonda Ayarlar → Genel → VPN ve Cihaz Yönetimi'nden profile güven.

Ücretsiz Apple ID kısıtları: imza **7 gün** geçerlidir (süre dolunca aynı
adımla yeniden kurulur), aynı anda en fazla 3 sideload uygulaması bulunabilir
ve her yenilemede USB bağlantısı gerekir. Bu kısıtlar Apple'a aittir,
uygulamayla ilgisi yoktur.

## Android'e kurulum

Android sürümü aynı koddan derlenir. APK, GitHub Actions'tan indirilebilir ya da
Android SDK kuruluysa yerelde üretilebilir.

1. **Anahtar (isteğe bağlı):** `GEMINI_API_KEY` secret'ı iOS için eklendiyse
   Android de onu kullanır; eklenmediyse Firebase yolu çalışır.
2. **Derlemeyi başlat:** Actions sekmesi → *Android APK* → Run workflow
   (`main`'e her push'ta da kendiliğinden çalışır).
3. **Çıktıyı indir:** Artifacts altındaki `Paceora-apk` → içinden `Paceora.apk`.
4. **Telefona kur:** APK'yı telefona at, aç; Android "bilinmeyen kaynaklardan
   yükleme" izni ister, o uygulama (Dosyalar, Chrome vb.) için izin ver.

iOS'tan farklı olarak 7 günlük imza süresi yoktur; APK bir kez kurulur.

### Kalıcı imza anahtarı (isteğe bağlı)

Secret verilmezse APK, her derlemede değişebilen debug anahtarıyla imzalanır;
bu durumda güncelleme kurarken Android "imza uyuşmuyor" diyebilir ve eski
sürümü silmek (verilerle birlikte) gerekir. Bunu önlemek ve ileride Play
Store'a çıkmak için bir kez anahtar üret:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

ve şu secret'ları ekle: `ANDROID_KEYSTORE_BASE64` (`.jks` dosyasının base64
hali), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`),
`ANDROID_KEY_PASSWORD`. Yerelde derlerken aynı bilgiler `android/key.properties`
dosyasından okunur (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`);
bu dosya ve `.jks` `.gitignore`'dadır.

Yerelde Android SDK kuruluysa:

```bash
flutter build apk --release                                  # anahtarsız (Firebase)
flutter build apk --release --dart-define-from-file=env.json # gömülü anahtarla
```

## Testler

```bash
flutter test                                   # birim + widget testleri
flutter test --tags golden                     # ekran görüntüsü testleri (Linux)
flutter test --tags golden --update-goldens    # görüntüleri yenile
flutter test integration_test -d <cihaz>       # uçtan uca, temiz kurulumda
```

400+ test. Ekran görüntüsü testleri Linux'ta üretildiği için
diğer sistemlerde atlanır; uçtan uca test GitHub Actions'ta "Entegrasyon testi"
iş akışıyla Android emülatöründe elle çalıştırılır. Ek kapsam: erişilebilirlik
yönergeleri (etiket, 48 dp dokunma alanı, WCAG kontrastı), vurgu renkleri
kontrastı, yedekleme/geri yükleme, veritabanı şeması, gizlilik (adın Gemini'ye
gitmemesi), hazır ders havuzu, sesler (öncelik, dosya süresi ve düzeyi), uyarlanan seviye
testi, saat sabitlenerek haftanın her günü.

Kapsam: Gemini yanıt ayrıştırma ve yedek plana düşme, ders JSON'unun
bozuk öğelere dayanıklı okunması, çeviri puanlaması (noktalama, büyük/küçük harf,
kısaltmalar), hata defteri kuralları, repository (streak, plan yenilerken
ilerlemenin korunması, ders önbelleği), SM-2 aralık hesabı, flash kart destesi,
hikaye ayrıştırma ve puanlama, adaptif seviye kuralı, haftalık istatistikler,
XP/seviye/rozet kuralları, günlük hedef ve
uçtan uca ders / onboarding / flash kart widget testleri.

> Analiz: `dart analyze --fatal-infos`. Proje yolunda ASCII olmayan karakter
> varsa `flutter analyze` çökebilir.

## Yapı

```
lib/
  app/          tema, router, sekmeler, Pace, kutlamalar, sesler, Türkçe yardım,
                tanıtım turu, ana ekran widget'ı
  data/         drift şeması, repository, Riverpod provider'ları, Gemini servisi
                (Firebase / kendi anahtarın), seviye testi, SM-2, rozetler,
                bildirimler, yedekleme
  features/
    onboarding/ placement/ level_exam/        tanışma, seviye testi, sınav
    home/ lesson/ program/                    bugün, ders, takvim
    practice/ roleplay/ speaking/ writing/    pratik sekmesi
    flashcards/ story/ match/ mistakes/       kartlar, hikaye, oyun, hata defteri
    progress/ review/ profile/ wardrobe/      ilerleme, rapor, profil, dolap
    search/ settings/                         arama, ayarlar
assets/
  pace/ mascot/  Pace pozları, kutlama GIF'i, formalar
  sounds/        doğru, yanlış, ders bitti, rozet, seviye
  placement/     seviye testi soruları (116)
  lessons/       internetsiz hazır dersler (24)
  fonts/         Inter (OFL)
```

**Teknolojiler:** Flutter · Riverpod 3 · go_router · drift + SQLite (web'de
WASM) · Firebase AI Logic + App Check · Gemini REST API · flutter_animate ·
flutter_tts · speech_to_text · audioplayers · flutter_local_notifications ·
home_widget · flutter_secure_storage.

### Veri modeli

| Tablo | İçerik | Durum |
|---|---|---|
| `UserProfiles` | ad, CEFR seviyesi, günlük dakika, streak | ✅ kullanımda |
| `WeeklyPlanDays` | haftanın 7 günü: dilbilgisi konusu + kelime teması, durum | ✅ kullanımda |
| `Lessons` | günlük ders içeriği + ilerleme (JSON), skor, süre | ✅ kullanımda |
| `Mistakes` | yanlış yapılan kelime/kalıplar; 1-3-7 gün sonra sorulur, 3 doğruda çözülür | ✅ kullanımda |
| `Flashcards` | SM-2 aralıklı tekrar kartları | ✅ kullanımda |
| `Stories` | günün hikayesi + cevaplar (JSON), test skoru | ✅ kullanımda |
| `WeeklyReviews` | haftalık değerlendirme raporu (JSON) | ✅ kullanımda |

Ders içeriği ve o ders içindeki ilerleme tek bir JSON olarak `contentJson`'a
yazılır; yarıda bırakılan ders bu sayede şemaya kolon eklemeden kaldığı adımdan
devam edebiliyor.

## Yol haritası

- [x] Günlük ders akışı (kelime, boşluk doldurma, çeviri, test) ve puanlama
- [x] Hata defteri — yanlışların takibi ve sonraki derse beslenmesi
- [x] Ayarlar: profil düzenleme, kendi Gemini anahtarın, tema
- [x] Günlük hatırlatma bildirimi (saat seçmeli)
- [x] SM-2 aralıklı tekrarlı flash kartlar
- [x] İlerleme ekranı: streak takvimi, haftalık skor grafiği
- [x] Günün hikayesi + okuduğunu anlama testi
- [x] Haftalık değerlendirme raporu ve adaptif seviye ayarı (B1- ↔ B2+)
- [x] Animasyonlu arayüz ve Türkçe sistem metinleri
- [x] Maskot Pace, forma dolabı ve seri hedefi kutlamaları
- [x] Konuşma, dinle-yaz, AI ile sohbet, Kelime Rallisi
- [x] Seri dondurma, profil ve rozet vitrini, yedekleme
- [x] Anahtarsız yapay zeka (Firebase AI Logic + App Check)
- [x] Aylık takvim, telafi dersi, yazma pratiği, arama
- [x] Uyarlanan seviye testi ve seviye atlama sınavı
- [x] Türkçe yardım, sesler, bildirimler, Android widget'ı
- [ ] Yayın imza anahtarı ve mağaza yayını
- [ ] iOS ana ekran widget'ı
- [ ] Arkadaş sistemi

## Logo

Logo, lime halka içindeki Pace rozetidir (`assets/mascot/pace_badge.png`).
Maskot pozları ve forma maskeleri `assets/mascot/` altında 1x/2x/3x
çözünürlükte durur. Platform ikonları (`web/icons`, `android/.../mipmap-*`,
Android 8+ uyarlanabilir ikon `mipmap-anydpi-v26`, `ios/.../AppIcon.appiconset`)
ve açılış ekranı görselleri (`drawable-*/launch_logo.png`, Android 12+
`drawable-xxhdpi/splash_icon.png`) aynı rozetten üretildi. Logo yenilenirse bu üretilmiş dosyaların da
güncellenmesi gerekir.

Palet: `#C6F432` (Lime Spark) · `#15171A` (Graphite 900)

## Lisans

[MIT](LICENSE)
