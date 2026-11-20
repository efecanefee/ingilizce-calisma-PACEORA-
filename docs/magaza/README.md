# Mağaza materyalleri

Google Play ve App Store'a yükleme için hazır metinler ve görseller.

| Dosya | İçerik |
|---|---|
| `liste-tr.md` | Türkçe mağaza sayfası: ad, kısa ve uzun açıklama, anahtar kelimeler |
| `liste-en.md` | İngilizce mağaza sayfası |
| `play-veri-guvenligi.md` | Play Console "Veri güvenliği" formunun cevapları |
| `derecelendirme.md` | Kategori, içerik derecelendirmesi anketi cevapları, iletişim bilgileri |
| `ekranlar/` | Ekran görüntüleri (`play_*` 1080×1920, `ios_*` 1290×2796; uygulama yalnız iPhone, iPad görüntüsü gerekmez) |

## Ekran görüntülerini yeniden üretmek

Görüntüler uygulamanın kendisinden, sabit tarih ve örnek veriyle bir test
tarafından çizilir; arayüz değişince tek komutla yenilenir (Linux):

```bash
sudo apt install fonts-noto-color-emoji   # emoji'ler için, bir kez
flutter test --tags magaza --run-skipped
```

App Store alfa kanallı görsel kabul etmez; üretimden sonra kanalı kaldırıp
dosyaları küçültmek için:

```bash
python3 -c "import glob; from PIL import Image; [Image.open(f).convert('RGB').save(f, optimize=True) for f in glob.glob('docs/magaza/ekranlar/*.png')]"
```

Emoji yazı tipi başka bir yerdeyse yolu `PACE_EMOJI_FONT` ortam değişkeniyle
verilebilir. Normal `flutter test` çalıştırmasında bu test atlanır.

Sıralama mağazadaki sırayla aynıdır:

1. Bugün — ana ekran, seri ve günün dersi
2. Pace'in dolabı — XP ile açılan formalar
3. Haftalık program
4. İlerleme — seviye, seri takvimi, istatistikler
5. Seviye testi
6. Koyu tema
7. Karşılama ekranı

## Yükleme öncesi kontrol listesi

- [ ] Gizlilik politikası herkese açık bir adreste yayında
  (`docs/gizlilik-politikasi.md`; ör. GitHub Pages) ve adres her iki mağazaya
  girildi
- [ ] Play: `surum: paylasim` ile üretilmiş AAB yüklendi (gömülü anahtar yok)
- [ ] Play: Veri güvenliği formu `play-veri-guvenligi.md`'ye göre dolduruldu
- [ ] Play: İçerik derecelendirmesi anketi `derecelendirme.md`'ye göre dolduruldu
- [ ] Play: Hedef kitle 13+ seçildi
- [ ] App Store: Uygulama gizlilik etiketi `play-veri-guvenligi.md`'deki
  tabloyla tutarlı dolduruldu
- [ ] Uygulama simgesi 512×512 (Play) ve 1024×1024 (App Store) yüklendi
- [ ] Öne çıkan görsel 1024×500 (Play) hazırlandı

---

Yağız
