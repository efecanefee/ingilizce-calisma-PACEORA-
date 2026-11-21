# Değişiklik günlüğü

## 1.2.0

### Yeni
- **Yeni logo ve maskot Pace:** Lime halka içinde Pace rozeti ve PACEORA
  kelime markası. Android, iOS, web ve Windows ikonları yenilendi; Android 8+
  için uyarlanabilir ikon, Android 12+ için sistem açılış ekranı eklendi.
- **Pace:** Koşu, kutlama, çalışma ve şaşkın pozları. Ana ekranda serinin
  durumuna göre poz değiştirir; dokununca dolabı açılır.
- **Vurgu rengi:** Ayarlar > Görünüm'de 6 vurgu rengi. Grafit zemin ve
  açık/koyu mod korunur.
- **Pace'in dolabı:** Harcanabilir XP ile 6 forma; satın almadan önce onay,
  sonra kutlama.
- **A2 ve C1 seviyeleri:** Başlangıç ve ileri seviye kullanıcılar için yeni
  kademeler; yedek haftalık program ve seviye önizlemeleriyle.
- **Kısa seviye testi:** Onboarding'de 16 soru. Her seferinde havuzdan karışık
  sorular, sonunda yanlışların incelemesi, yarıda çıkarken onay.
- **Seviye önizlemesi:** Seviye seçildikten sonra odak konuları ve isteğe bağlı
  4 soruluk kontrol; sonuca göre alt/üst seviye önerisi.
- **"Bu hafta" kutucukları:** Ana ekranda dokunulabilir gün kutucukları; günün
  konusunu açar.
- **Seri hedefleri:** Seri rozetinde dönen alev çerçevesi ve hedef barı;
  3, 7, 14, 30, 50, 100, 200, 365 güne ulaşınca kutlama.
- **Yedekleme:** Ayarlar > Verilerim'den tüm ilerlemeyi dosyaya aktarma ve
  yedekten geri yükleme.
- **Hazır dersler:** Gemini'ye ulaşılamadığında 24 konuluk yerleşik ders
  havuzundan çalışma; A2, B1, B2 ve C1 için programdaki konuyla aynı ders.
- **Süre seçenekleri:** 5, 10, 15, 20, 30, 45 ve 60 dakika, açıklamalarıyla.
  30, 45 ve 60 dakikada ders de uzar (daha çok kelime ve alıştırma).
- **Animasyonlu açılış:** Sistem açılış ekranının devamı; rozetin çevresinde
  dönen hale, üstte harf harf beliren PACEORA, solarak uygulamaya geçiş.
  Karşılama ekranındaki logo da hareketli.
- **Doğru/yanlış sesleri:** Derslerde, eşleştirmede ve seviye testinde kısa
  sesler; telefon sessizdeyse çalmaz. Ayarlar > Ses efektleri ile kapatılır.
- **Seviye testinde renkli geri bildirim:** Seçilen cevap yeşil/kırmızı,
  doğru seçenek işaretlenir.
- **Pace'in konuşma balonu:** Güne, seriye ve saate göre kısa mesajlar.
- **Kişisel hatırlatma:** Bildirim metni seriye göre değişir; o gün
  çalışıldıysa hatırlatma gelmez.
- **Geri bildirim:** Ayarlar > Geri bildirim gönder; hata kaydı isteğe bağlı.
- **Mağaza puanlama isteği:** 7 günlük seride bir kez.

### Gizlilik ve güvenlik
- Gemini API anahtarı cihazın güvenli kasasında (Keystore/Keychain) saklanır.
- Kullanıcının adı Gemini'ye hiçbir zaman gönderilmez.
- Ayarlar > Gizlilik metni düzeltildi; ayrıntılı açıklama ve
  `docs/gizlilik-politikasi.md`.
- Dağıtım derlemesi anahtarsız (`surum: paylasim`) ya da kişisel (anahtarlı)
  seçilebilir; AAB ve kod gizleme.
- Android: kesin alarm izni kaldırıldı, yedekleme kuralları eklendi.
  iOS: gizlilik bildirimi (PrivacyInfo.xcprivacy).

### Değişti
- Ayarlar'da seviye, seviye testi çözülmeden değiştirilemez.
- Yüklenemeyen ekranlarda teknik hata yerine anlaşılır mesaj ve Tekrar dene.
- Uygulama dikey yöne kilitli; iOS'ta yalnız iPhone.
- Inter yazı tipi uygulamayla birlikte gelir (çevrimdışı da aynı görünüm).
- Android 14+ öngörülü geri hareketi.
- Açık modda Program başlık kartı ve ders sonu XP rozeti daha okunaklı.
- Vurgu renkleri tema uzantısından okunur; renk değişince her ekran anında
  güncellenir.

### Erişilebilirlik ve performans
- "Animasyonları azalt" açıksa Pace, seri çerçevesi, parıltı ve alev durur;
  açılış animasyonu kısalır.
- Dokunma alanları en az 48 dp, düğmelerde etiket, kontrast iyileştirmeleri.
- Cihazda İngilizce ses yoksa sesli okumanın nasıl açılacağı anlatılır.
- Pace görselleri 1x/2x/3x çözünürlükte ve açılışta önbelleğe alınır.
- Ekran okuyucu Pace'in pozunu ve gün kutucuklarının durumunu okur.

### Düzeltildi
- Verileri sıfırla, forma dolabını ve seviye testi kaydını da temizler.

### Geliştirme
- PR'larda analiz, testler, kapsam özeti ve Android derlemesi
  (`kontrol.yml`); emülatörde uçtan uca test (`entegrasyon.yml`, elle).
- Genel hata yakalama ve cihazda tutulan hata kaydı.
- Veritabanı göç altyapısı ve şema dökümü; tarihe bağlı kodda `clock`.
- Ek lint kuralları; golden, erişilebilirlik, gizlilik ve ayarlar testleri
  (304 test).
- Mağaza materyalleri: `docs/magaza/` (metinler, veri güvenliği, ekran
  görüntüleri, öne çıkan görsel).
- PR ve konu şablonları, dependabot.
