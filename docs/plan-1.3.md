# Sürüm 1.3 planı

Kararlar 2026-11-21'de verildi. Sıra, bağımlılığa ve riske göre belirlendi.

## 1. Koyu tema varsayılan (küçük)
- `ThemeModeNotifier` kayıt yoksa `ThemeMode.dark` döner; kullanıcının daha önce seçtiği tema korunur.

## 2. Günlük süre: 5, 15, 30, 60
- `dailyMinuteOptions` = [5, 15, 30, 60]; açıklamalar güncellenir.
- 5 dk gerçekten kısa olur: `LessonSize` 3 kelime / 3 boşluk / 1 çeviri / 3 quiz.
- Göç: kayıtlı 10 → 15, 20 → 15, 45 → 30.
- Hazır (çevrimdışı) dersler süreye göre kırpılır/uzatılır.

## 3. Renk sistemi: özellik renkleri
- `FeatureColors` tema uzantısı: her özellik için açık/koyu modda okunur renk.
  - Ders: vurgu rengi · Kartlar: mor · Hikaye: mavi · Konuşma: pembe · Dinle-yaz: nane
  - Hata defteri: mercan · Rapor: turkuaz · AI sohbet: buz mavisi · Ralli: kehribar
- Kontrast testi (WCAG AA) her renk için.

## 4. Pratik sekmesi
- Alt menü: Bugün · Pratik · Program · İlerleme · Ayarlar.
- Pratik ekranı: her özellik kendi rengiyle; AI sohbet ve Ralli öne çıkan büyük kartlar.
- Bugün ekranı Duolingo gibi sadeleşir: Pace + seri, bugünün dersi, günlük hedef, "Bu hafta".
- Ana ekrandaki anahtar kartı kalkar.

## 5. Ayarlar yenilemesi
- Gruplar: Profil · Çalışma · Görünüm · Bildirimler · Verilerim · Gelişmiş · Hakkında.
- Her grubun tek, anlamlı rengi; kırmızı yalnız tehlikeli işlerde (sıfırla).
- Ana ekranla tekrar eden öğeler (Hata defterim, Haftalık rapor) Ayarlar'dan kalkar.
- "Kendi Gemini anahtarın" ve "Bağlantıyı test et" Gelişmiş'e taşınır.
- 1616 satırlık dosya grup başına dosyalara bölünür.

## 6. Yeni seviye testi
- 20 soru, bloklu ve dalgalı zorluk:
  1. 2 kolay (A2) + 1 orta (B1) + 1 zor (B2)
  2. 3 orta (B1/B1+) + 3 zor (B2/B2+)
  3. 2 orta-üst + 2 zor + 2 çok zor (C1)
  4. 4 karışık kontrol sorusu (önceki bloklara göre seçilir)
- Türler: dilbilgisi, kelime, kısa okuma, dinleme (cihazın sesli okuması; ses yoksa atlanır).
- Bir dilbilgisi konusundan en fazla 2 soru; geçmiş zaman sınırlı.
- Puan zorluğa göre ağırlıklı; sonuç alt seviyeye (B1-, B1, B1+ …) eşlenir.
- ~120 soruluk elle yazılmış havuz (`assets/placement/*.json`).

## 7. Firebase AI Logic (kullanıcı eylemi gerekir)
- Kullanıcı: Firebase projesi açar, Android/iOS uygulamasını ekler, AI Logic'i (Gemini Developer API) ve App Check'i (Play Integrity / App Attest) etkinleştirir, `google-services.json` ve `GoogleService-Info.plist` dosyalarını verir.
- Uygulama: `firebase_core`, `firebase_ai`, `firebase_app_check`; `GeminiService` arkasına Firebase sağlayıcısı; kullanıcı kendi anahtarını girerse doğrudan REST yolu kalır.
- Gömülü anahtar (`--dart-define`) dağıtım derlemelerinden kaldırılır.
