<div align="center">

<img src="assets/images/paceora_logo.png" alt="Paceora" width="320">

**Türkçe konuşanlar için günlük İngilizce çalışma uygulaması**

Seviyene göre haftalık program üretir, her gün ne çalışacağını söyler,
serini (streak) takip eder. Veriler tamamen cihazında kalır.

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini-2.0%20Flash-8E75B2?logo=googlegemini&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-informational)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

---

## Neden?

Kurs uygulamalarının çoğu seni genel bir müfredata sokar. Paceora bunun tersini
yapar: adını, CEFR seviyeni ve günde kaç dakika ayırabildiğini sorar, sonra
**sana özel** bir haftalık program üretir. Pazartesiden pazara her günün bir
dilbilgisi konusu ve bir kelime teması olur; pazar günü haftanın tekrarına ayrılır.

## Öne çıkanlar

- **Kişiye özel haftalık program** — Gemini 2.0 Flash, seviyene ve süreni göre
  7 günlük konu akışı üretir; konular kolaydan zora ilerler ve tekrar etmez.
- **Çok adımlı günlük ders** — o günün konusundan kelime kartları → boşluk
  doldurma → Türkçe'den İngilizce'ye çeviri → çoktan seçmeli test üretilir.
  Soru sayısı seçtiğin günlük süreye göre ölçeklenir.
- **Hata defteri ve adaptif tekrar** — yanlış yaptığın kelime/kalıplar kaydedilir
  ve sonraki dersin üretimine beslenir. Üç kez üst üste doğru yapınca kayıt
  kapanır; araya bir yanlış girerse seri sıfırlanır.
- **Yarıda bırakabilirsin** — her cevap anında cihaza yazılır; dersi kapatıp
  geri döndüğünde kaldığın adımdan devam edersin ve aynı gün için ikinci kez
  Gemini'ye istek gitmez.
- **Kendi API anahtarını kullanabilirsin** — Ayarlar'dan girdiğin anahtar
  uygulamayla gelene göre önceliklidir ve yalnızca cihazında saklanır.
- **Anahtarsız da çalışır** — API anahtarı yoksa, ağ koparsa ya da yanıt bozuksa
  uygulama kilitlenmez: haftalık program B1/B2 için yerleşik yedek listeden gelir
  ve ana ekranda *çevrimdışı plan* rozeti görünür.
- **Seri (streak) takibi** — gün atlarsan sıfırlanır, aynı gün iki kez
  tamamlarsan şişmez; yaz saati kaymalarından etkilenmeyen gün hesabı kullanır.
- **İlerlemen korunur** — programı yenilediğinde çalıştığın günlerin durumu
  silinmez, dolayısıyla serin de bozulmaz. Yeni haftaya geçtiğinde program
  kendiliğinden üretilir.
- **Tamamen yerel veri** — her şey cihazdaki SQLite'ta (drift). Hesap yok,
  sunucu yok; Gemini'ye yalnızca içerik üretirken istek gider.
- **6 kademeli seviye** — B1-, B1, B1+, B2-, B2, B2+ (adaptif zorluk için ara
  kademeler).
- **Açık/koyu tema** — "Lime Spark + Graphite" paleti, Ayarlar'dan seçilebilir.

## Ekranlar

| Ekran | İçerik |
|---|---|
| **Onboarding** | İsim → seviye → günlük süre (10/15/20 dk); sonunda program üretilir |
| **Ana ekran** | Seri sayacı, bugünün konusu ve skoru, haftanın tamamı |
| **Ders** | Adım adım kelime / boşluk doldurma / çeviri / test, anında geri bildirim |
| **Sonuç** | Yüzdelik skor, doğru sayısı ve tekrar edilecekler listesi |
| **Ayarlar** | Profil, Gemini anahtarı, tema, verileri sıfırlama |

## Kurulum

```bash
flutter pub get
```

Drift kod üretimi (`lib/data/database.g.dart`):

```bash
dart run build_runner build --force-jit
```

> `--force-jit` gerekli: proje yolu ASCII olmayan karakter içerdiği için
> (`Masaüstü`) build_runner'ın AOT derlemesi bu makinede başarısız oluyor.

### Gemini API anahtarı

Anahtar derleme zamanında verilir, koda gömülmez. Proje kökünde `env.json`
oluştur (bu dosya `.gitignore`'da, depoya girmez):

```json
{ "GEMINI_API_KEY": "anahtarınız" }
```

Anahtarı [Google AI Studio](https://aistudio.google.com/apikey)'dan
ücretsiz alabilirsin. Alternatif olarak uygulama içinden **Ayarlar → Gemini API
anahtarı** alanına yapıştırabilirsin; oradaki anahtar derlemeye gömülü olana göre
önceliklidir ve yalnızca o cihazda saklanır.

Hiç anahtar vermezsen haftalık program yerleşik yedek listeden gelir, ancak
günlük ders üretimi çalışmaz — ders ekranı bunu söyler ve günü elle
işaretlemene izin verir.

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

1. **Anahtarı secret olarak ekle:** GitHub → Settings → Secrets and variables →
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

Uygulama Flutter olduğu için Android sürümü aynı koddan derlenir. Bu makinede
Android SDK kurulu olmadığından APK, iOS'taki gibi GitHub Actions'ta üretilir.

1. **Anahtar:** `GEMINI_API_KEY` secret'ı iOS için eklendiyse Android de onu
   kullanır.
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
flutter build apk --release --dart-define-from-file=env.json
```

## Testler

```bash
flutter test
```

70 test. Kapsam: Gemini yanıt ayrıştırma ve yedek plana düşme, ders JSON'unun
bozuk öğelere dayanıklı okunması, çeviri puanlaması (noktalama, büyük/küçük harf,
kısaltmalar), hata defteri kuralları, repository (streak, plan yenilerken
ilerlemenin korunması, ders önbelleği) ve uçtan uca ders akışı widget testleri.

> `flutter analyze` bu makinede analiz sunucusunu çökertiyor (yine ASCII
> olmayan proje yolu yüzünden). Bunun yerine `dart analyze` kullanın.

## Yapı

```
lib/
  app/          sabitler, tema, router, logo widget'ları
  data/         drift şeması, repository, Riverpod provider'ları, Gemini servisi,
                ders modelleri ve puanlama
  features/
    onboarding/ isim + seviye + günlük süre akışı
    home/       streak, bugünün planı ve skoru, haftalık program
    lesson/     adım adım ders akışı ve sonuç ekranı
    settings/   profil, API anahtarı, tema, veri sıfırlama
assets/images/  paceora_mark.png (amblem), paceora_logo.png (tam logo)
```

**Teknolojiler:** Flutter · Riverpod (durum yönetimi) · drift + SQLite
(yerel veritabanı, web'de WASM) · Google Fonts · `http` · Gemini REST API.

### Veri modeli

| Tablo | İçerik | Durum |
|---|---|---|
| `UserProfiles` | ad, CEFR seviyesi, günlük dakika, streak | ✅ kullanımda |
| `WeeklyPlanDays` | haftanın 7 günü: dilbilgisi konusu + kelime teması, durum | ✅ kullanımda |
| `Lessons` | günlük ders içeriği + ilerleme (JSON), skor, süre | ✅ kullanımda |
| `Mistakes` | yanlış yapılan kelime/kalıplar, 3 doğruda çözülür | ✅ kullanımda |
| `Flashcards` | SM-2 aralıklı tekrar kartları | 🔜 şema hazır |
| `Stories` | günün hikayesi + test sonucu | 🔜 şema hazır |
| `WeeklyReviews` | haftalık değerlendirme raporu | 🔜 şema hazır |

Ders içeriği ve o ders içindeki ilerleme tek bir JSON olarak `contentJson`'a
yazılır; yarıda bırakılan ders bu sayede şemaya kolon eklemeden kaldığı adımdan
devam edebiliyor.

## Yol haritası

- [x] Günlük ders akışı (kelime, boşluk doldurma, çeviri, test) ve puanlama
- [x] Hata defteri — yanlışların takibi ve sonraki derse beslenmesi
- [x] Ayarlar: profil düzenleme, kendi Gemini anahtarın, tema
- [ ] Günlük hatırlatma bildirimi (saat seçmeli)
- [ ] SM-2 aralıklı tekrarlı flash kartlar
- [ ] İlerleme ekranı: streak takvimi, haftalık skor grafiği
- [ ] Günün hikayesi + okuduğunu anlama testi
- [ ] Haftalık değerlendirme raporu ve adaptif seviye ayarı (B1- ↔ B2+)

## Logo

Uygulama içi görseller `assets/images/` altında; platform ikonları
(`web/icons`, `android/.../mipmap-*`, `ios/.../AppIcon.appiconset`) ve Android
açılış ekranı görselleri (`android/.../drawable-*/launch_logo.png`) aynı
kaynaktan üretildi. Logo yenilenirse bu üretilmiş dosyaların da
güncellenmesi gerekir.

Palet: `#C6F432` (Lime Spark) · `#15171A` (Graphite 900)

## Lisans

[MIT](LICENSE)
