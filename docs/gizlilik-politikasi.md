# Paceora Gizlilik Politikası

Son güncelleme: 20 Kasım 2026

Paceora, Türkçe konuşanlar için günlük İngilizce çalışma uygulamasıdır. Bu metin
uygulamanın hangi verileri işlediğini ve nereye gönderdiğini açıklar.

## Hesap ve sunucu

Paceora'da hesap yoktur. Paceora'nın verilerini topladığı ya da sakladığı bir
sunucu yoktur.

## Cihazında saklananlar

Aşağıdaki veriler yalnızca telefonunda, uygulamanın kendi depolama alanında
saklanır:

- Profil: adın, seviyen, günlük çalışma süren
- İlerleme: haftalık program, dersler, skorlar, seri, hata defteri, kelime
  kartları, hikayeler, haftalık raporlar
- Ayarlar: tema, vurgu rengi, hatırlatma saati, maskot formaları, seviye testi
  sonucu

Uygulamayı silmek ya da **Ayarlar > Verileri sıfırla** bu verileri cihazdan
kaldırır.

## Yedek dosyası

**Ayarlar > Verileri dışa aktar** tüm ilerlemeni (adın dahil) bir JSON
dosyasına yazar ve seçtiğin yere paylaşır. Dosya şifrelenmez; nereye kaydettiğin
senin kontrolündedir. API anahtarın yedeğe girmez.

## Google Gemini'ye gönderilenler

Haftalık program, günlük ders, günün hikayesi, haftalık rapor yorumu, kelime
çevirisi ve rol yapma sohbeti Google'ın Gemini API'si ile üretilir. Bunun için
şu bilgiler Google'a gönderilir:

- Seviyen (ör. B1) ve günlük çalışma süren
- Günün dilbilgisi konusu ve kelime teması
- Tekrar edilecek, daha önce yanlış yaptığın ifadeler
- Haftalık çalışma istatistiklerin (gün, ders, skor, kart sayıları)
- Rol yapma sohbetinde yazdığın ya da söylediğin mesajlar ve çevirisini
  istediğin kelimeler

**Adın Gemini'ye gönderilmez.**

Bu veriler Google'ın [Gemini API Ek Hizmet Şartları](https://ai.google.dev/gemini-api/terms)
kapsamında işlenir. Ücretsiz Gemini API anahtarlarında Google gönderilen içeriği
ürünlerini geliştirmek için kullanabilir. Kendi ücretli anahtarını kullanırsan
Google'ın ücretli kullanım koşulları geçerlidir.

## Mikrofon ve konuşma tanıma

Konuşma pratiği mikrofon izni ister. Sesin, telefonunun konuşma tanıma
servisiyle (Android'de Google, iOS'ta Apple) metne çevrilir. Paceora ses kaydını
saklamaz; yalnızca tanınan metni puanlamak için kullanır.

## Hata kaydı

Uygulamada beklenmeyen bir hata olursa kısa bir açıklaması (son 20 hata)
yalnızca cihazında tutulur. Kendiliğinden hiçbir yere gönderilmez; istersen
**Ayarlar > Hata kaydı**'ndan paylaşabilir ya da temizleyebilirsin.

## Geri bildirim

**Ayarlar > Geri bildirim gönder** telefonundaki e-posta uygulamasını açar;
e-postayı sen gönderirsin. Gövdede uygulama sürümü ve platform (Android/iOS)
hazır gelir. Hata kaydı yalnızca kutucuğu işaretlersen eklenir.

## Bildirimler

Günlük hatırlatma, telefonunun yerel bildirim sistemiyle kurulur. Bildirim için
hiçbir veri cihazdan çıkmaz.

## API anahtarı

Kendi Gemini anahtarını girersen anahtar telefonunun güvenli kasasında (Android
Keystore / iOS Keychain) şifreli saklanır ve yedeklere girmez.

## Yazı tipi

Uygulamanın yazı tipi uygulamanın içinde gelir; çalışma sırasında internetten
indirilmez.

## Çocuklar

Paceora 13 yaşından küçük çocuklara yönelik değildir.

## İletişim

Sorular için: yagizturkmen1414@gmail.com

---

Yağız
