# Play Console — Veri güvenliği formu

Cevaplar `docs/gizlilik-politikasi.md` ile tutarlıdır. Politika değişirse bu
dosya da güncellenmelidir.

## Genel sorular

| Soru | Cevap |
|---|---|
| Uygulama, zorunlu kullanıcı verisi türlerinden herhangi birini topluyor ya da paylaşıyor mu? | **Evet** |
| Toplanan tüm kullanıcı verileri aktarım sırasında şifreleniyor mu? | **Evet** (Gemini API'ye HTTPS) |
| Kullanıcılar verilerinin silinmesini isteyebilir mi? | **Evet** — Ayarlar > Verileri sıfırla ya da uygulamayı silmek; sunucuda veri tutulmaz |
| Hesap oluşturma var mı? | **Hayır** |

> Not: Yalnızca cihazda işlenen ve cihazdan çıkmayan veriler Play tanımına göre
> "toplanan" sayılmaz (profil, ilerleme, ayarlar, hata kaydı, bildirimler).

## Veri türleri

| Kategori | Veri türü | Toplanıyor | Paylaşılıyor | Neden | Zorunlu mu |
|---|---|---|---|---|---|
| Uygulama etkinliği | Diğer kullanıcı tarafından oluşturulan içerik (rol yapma mesajları, tekrar edilecek yanlış ifadeler) | Evet | Evet — Google (Gemini API, hizmet sağlayıcı) | Uygulama işlevselliği | Hayır — yapay zekâ özellikleri kullanılmazsa gönderilmez |
| Uygulama etkinliği | Uygulama etkileşimleri (haftalık çalışma istatistikleri) | Evet | Evet — Google (Gemini API) | Uygulama işlevselliği (haftalık rapor) | Hayır |
| Ses | Ses kayıtları | **Hayır** — ses cihazın konuşma tanıma servisinde metne çevrilir, Paceora kaydetmez ya da göndermez | — | — | — |
| Kişisel bilgiler | Ad | **Hayır** — ad yalnızca cihazda tutulur, Gemini'ye gönderilmez | — | — | — |
| Konum, kişiler, fotoğraflar, finans, sağlık | — | Hayır | — | — | — |
| Uygulama bilgileri ve performansı | Kilitlenme günlükleri | **Hayır** — hata kaydı yalnızca cihazda, kullanıcı isterse kendisi paylaşır | — | — | — |
| Cihaz veya diğer kimlikler | — | Hayır | — | — | — |

Seviye, günlük süre, ders konusu gibi bilgiler kişiyle ilişkilendirilemeyen
ders parametreleridir; yine de şeffaflık için "Uygulama etkileşimleri" altında
beyan edilir.

## App Store gizlilik etiketi karşılığı

- **Data Not Linked to You:** User Content (Other User Content), Usage Data
  (Product Interaction) — amaç: App Functionality
- **Data Not Collected:** diğer tüm kategoriler
- **Tracking:** Hayır

---

Yağız
