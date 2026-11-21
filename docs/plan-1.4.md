# Sürüm 1.4 planı

Kararlaştırılan üç ana iş ve hemen yapılması gereken bir altyapı işi.

## 1. Program ilk açılış gününden başlar

Sorun: Haftalık plan pazartesiye bağlı (`mondayOf`). Perşembe başlayan biri
için pazartesi–çarşamba "kaçırıldı" görünüyor. Hazır dersler `dayIndex`e göre
seçildiği için yeni kullanıcı programa ortadan giriyor.

Yapılacaklar:
- İlk açılışta (veya seviye testi bitince) başlangıç günü saklanır.
- Program "1. Gün"den başlar; haftalar başlangıç gününden itibaren 7 günlük
  bloklar (1–7, 8–14, …).
- Başlangıçtan önceki günler takvimde görünmez/gri; "kaçırıldı" sayılmaz,
  seriyi bozmaz.
- Seviye testi sonucu o seviyenin ilk konusundan başlatır.
- Var olan kullanıcıların verisi korunur (geçiş: başlangıç günü = ilk plan
  haftası ya da ilk tamamlanan gün).
- Ek: aylık görünüm (hangi gün çalışıldığını gösteren ay takvimi).

## 2. Pace tanıtım turu ve daha çok Pace

- Seviye testinden sonra yalnızca ilk açılışta tur: Pace konuşma balonuyla
  karşılar, 5 sekmeyi sırayla tanıtır. "Atla" düğmesi; Ayarlar'dan yeniden
  izlenebilir. Görüldü bilgisi prefs'te.
- Pace'in görüneceği yeni yerler: boş ekranlar, hata ekranları, ders sonu,
  seri tehlikedeyken bildirim, ana ekranda günün ipucu; ruh hali seriye göre.

## 3. Ayarlar sadeleşir

Şu an her grubun kendi parlak rengi var, kalabalık duruyor.
Varsayılan öneri (A): simgeler tek tip nötr kutuda; renk yalnızca ana vurgu
(seçili değer, açma/kapama) ve tehlikeli işlerde kırmızı. İsteğe bağlı C ile
birleşim: üstte Pace'li profil kartı, altında büyük kategori kartları.
Başlamadan önce kullanıcıya A mı, A+C mi diye sorulacak.

## Altyapı (öncelikli)

- Yayın imza anahtarı oluştur, GitHub secret olarak ekle, SHA parmak izini
  Firebase'e (App Check / Play Integrity) ekle. 21 Ocak 2027 App Check
  zorunluluğundan önce şart.
- CI'da `GEMINI_API_KEY` gömmesini kaldır.

## Sonraki adaylar

Yapay zeka ile yazma düzeltme, günün kelimesi + widget, haftalık rapor, okuma
metinleri, cümle kurma oyunu, sınav hazırlık modu (YDS/YÖKDİL/IELTS), A1
seviyesi, deyimler, akıllı hatırlatma saati, lig/arkadaş (sunucu gerekir).
