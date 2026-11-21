# Mağaza materyalleri

Google Play ve App Store'a yükleme için hazır metinler ve görseller.

| Dosya | İçerik |
|---|---|
| `liste-tr.md` | Türkçe mağaza sayfası: ad, kısa ve uzun açıklama, anahtar kelimeler |
| `liste-en.md` | İngilizce mağaza sayfası |
| `play-veri-guvenligi.md` | Play Console "Veri güvenliği" formunun cevapları |
| `derecelendirme.md` | Kategori, içerik derecelendirmesi anketi cevapları, iletişim bilgileri |
| `gorseller/` | Play öne çıkan görsel (1024×500) ve Play simgesi (512×512). App Store simgesi derlemeyle gelir (`ios/Runner/Assets.xcassets`) |
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
python3 -c "import glob; from PIL import Image; [Image.open(f).convert('RGB').save(f, optimize=True) for f in glob.glob('docs/magaza/ekranlar/*.png') + glob.glob('docs/magaza/gorseller/play_one*.png')]"
```

Emoji yazı tipi başka bir yerdeyse yolu `PACE_EMOJI_FONT` ortam değişkeniyle
verilebilir. Normal `flutter test` çalıştırmasında bu test atlanır.

Öne çıkan görsel de aynı komutla `gorseller/` altına çizilir. Play simgesi
iOS'taki 1024'lük simgeden küçültülür:

```bash
python3 -c "from PIL import Image; Image.open('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png').convert('RGBA').resize((512, 512), Image.LANCZOS).save('docs/magaza/gorseller/play_simge_512.png')"
```

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
- [ ] Play: `gorseller/play_simge_512.png` ve `gorseller/play_one_cikan_gorsel.png` yüklendi

---

Yağız
