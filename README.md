# Paceora

Türkçe konuşanlar için günlük İngilizce çalışma uygulaması (Flutter).
Kullanıcının seviyesine göre Gemini ile haftalık program üretir, ilerlemeyi
yerel bir SQLite (drift) veritabanında saklar.

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

## Gemini API anahtarı

Anahtar derleme zamanında verilir. Proje kökünde `env.json` oluşturun
(bu dosya `.gitignore`'da, depoya girmez):

```json
{ "GEMINI_API_KEY": "anahtarınız" }
```

Anahtar verilmezse uygulama çalışmaya devam eder; haftalık program yerleşik
yedek listeden gelir ve ana ekranda "çevrimdışı plan" rozeti görünür.

## Çalıştırma

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

Web'de drift, `web/sqlite3.wasm` ve `web/drift_worker.js` dosyalarına ihtiyaç
duyar; ikisi de depoda mevcut. Windows masaüstünde çalıştırmak için Visual
Studio'nun "Desktop development with C++" iş yükü kurulu olmalıdır:

```bash
flutter run -d windows --dart-define-from-file=env.json
```

## iPhone'a kurulum

Windows'ta iOS derlemesi yapılamaz (Xcode yalnızca macOS'ta çalışır), bu yüzden
IPA GitHub Actions'ın macOS runner'ında üretilir; imzalamayı Windows'ta
Sideloadly kendi Apple ID'nle yapar.

1. **Depoyu GitHub'a yükle.** Yalnızca `paceora/` klasörü depo kökü olmalı.
2. **Anahtarı secret olarak ekle:** GitHub → Settings → Secrets and variables →
   Actions → New repository secret → ad `GEMINI_API_KEY`, değer anahtarın.
   Anahtar koda girmez, yalnızca derleme sırasında `--dart-define` ile enjekte
   edilir.
3. **Derlemeyi başlat:** Actions sekmesi → *iOS IPA* → Run workflow.
4. **Çıktıyı indir:** Koşu bitince Artifacts altındaki `Paceora-unsigned-ipa`.
   İçinden `Paceora-unsigned.ipa` çıkar.
5. **Telefona kur:** [Sideloadly](https://sideloadly.io) ile iPhone'u USB'den
   bağla, IPA'yı sürükle, Apple ID'nle imzala ve kur. Kurulumdan sonra
   telefonda Ayarlar → Genel → VPN ve Cihaz Yönetimi'nden profile güven.

Ücretsiz Apple ID kısıtları: imza **7 gün** geçerlidir (süre dolunca aynı
adımla yeniden kurulur), aynı anda en fazla 3 sideload uygulaması bulunabilir
ve her yenilemede USB bağlantısı gerekir. Bu kısıtlar Apple'a aittir,
uygulamayla ilgisi yoktur.

## Testler

```bash
flutter test
```

> `flutter analyze` bu makinede analiz sunucusunu çökertiyor (yine ASCII
> olmayan proje yolu yüzünden). Bunun yerine `dart analyze` kullanın.

## Yapı

```
lib/
  app/          sabitler, tema, router, logo widget'ları
  data/         drift şeması, repository, Riverpod provider'ları, Gemini servisi
  features/
    onboarding/ isim + seviye + günlük süre akışı
    home/       streak, bugünün planı, haftalık program
assets/images/  paceora_mark.png (amblem), paceora_logo.png (tam logo)
```

## Logo

Uygulama içi görseller `assets/images/` altında; platform ikonları
(`web/icons`, `android/.../mipmap-*`, `ios/.../AppIcon.appiconset`) ve Android
açılış ekranı görselleri (`android/.../drawable-*/launch_logo.png`) aynı
kaynaktan üretildi. Logo yenilenirse bu üretilmiş dosyaların da
güncellenmesi gerekir.
