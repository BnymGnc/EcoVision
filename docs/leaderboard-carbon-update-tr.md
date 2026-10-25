# Liderlik ve karbon duzeltmeleri - 25 Ekim 2026

## Degisen davranis

- Liderlik ilk sekmesi artik Genel. Sehir secilmediginde tum hesaplar ayni
  Eko Puan siralamasina dahildir. Sehir filtresinde 81 illik merkezi katalog
  kullanilir; varsayilan bir il atanmaz. Arkadaslarim sekmesi korunur.
- Yeni `GET /api/leaderboard/global?city=...&page=0&size=50` endpoint'i,
  `items`, `hasMore` ve `total` dondurur. Telefon tum kullanicilari tek seferde
  indirmez; Diger kullanicilar dugmesi sonraki sayfayi getirir. Sayfalama
  sinirlidir (en fazla 100 kayit/istek), es puanda ad ve ID siralamasi kararlidir.
- Eski `/city` ve `/friends` endpoint'leri eski APK'lar icin korunur.
  DTO'daki fotograf gizliligi ve kabul edilmis arkadas kontrolu degismedi.
- Karbon anketinin herhangi bir sorusunda ozel sayi girilince secili sik
  kaldirilir; siklar soluk ve dokunulamaz olur. Degeri temizlemek siklari
  yeniden acar. Bu durum 20 sorunun tamaminda regresyon testine alindi.
- Ulasim/isinma gibi nitelik gerektiren sayisal hesapta tur, ayri acilir
  listede secilir. Mesafe tek basina aracin turunu belirlemez; bu bilgi
  hesaplamadan atilmadi. Hizli anket ve onceki agirliklar korunur.
- Profilde sabit cizgi yazan Olculen CO2 alani kaldirildi. Artik son kayitli
  yillik anket sonucu Tahmini CO2e olarak gorunur. Tuketime dayali eski kismi
  sonuc varsa Kismi CO2e diye ayrilir. Bu deger tasarruf veya karbon kredisi
  olarak sunulmaz; puanlardan turetilmez.
- Kayit yoksa Hesapla, ag hatasinda Tekrar Dene, gercek sifir degerinde
  0,0 kg/yil gosterilir. Profilde hesaplamadan donunce veri yenilenir.
- Mevcut `POST /api/gamification/carbon-footprint` artik anket sonucunu mevcut
  `carbon_assessments` tablosunda saklar. Ayni hesabin tekrar hesaplamasi
  degeri gunceller; mevcut kilitli tek-odul servisi sayesinde ikinci kez
  75 puan eklemez. Yeni migration veya veri silme gerekmez.
- Onceki surumde sonucun kaydi tutulmadigi icin eski anket toplami geriye
  donuk uretilemez. Bu hesaplarda bir kez yeniden hesaplama gerekir.

## Koku bulunan test sorunlari

Gercek PostgreSQL testinde nullable sehir parametresi `lower(bytea)` hatasi
uretti. Genel sorguda null yerine bos String kullanilarak duzeltildi; SQL
parametreleri bagli kalir, metin birlestirme/SQL injection eklenmedi.

Ilk tum Flutter kosusunda yeni API testinin oturum fixture'i eksikti:
136 basarili, 1 basarisiz. Gercek API guvenligini gevsetmek yerine testte
mock giris yapildi. Duzeltilen API dosyasi yeniden 5/5 gecti.

Ilk tum backend kosusu: 124 test, 0 assertion hatasi, 1 PostgreSQL sorgu
hatasiydi. Bu basarisiz kosu basarili sayilmaz.

Nihai tekrar: Java 17 + izole PostgreSQL, `mvn -B -q test`, **43 sinif /
124 test, 0 hata, 0 basarisizlik, 0 atlama** (Surefire XML'den sayildi).
Tum Flutter paketi `flutter test --no-pub --concurrency=1 --reporter=expanded`:
**137 test basarili**, 8 dakika 50 saniye. `dart analyze lib test`: hata veya
uyari yok. Yerel Docker/PostgreSQL kullanildi; bu testler Neon verisini silmez.

Windows PowerShell'de web build logu yonlendirildiginde, Flutter'in WASM
dry-run uyarisi native stderr yuzunden script'i erken durduruyordu. Build
script'i artik native ciktiyi koruyup asil process exit code'unu denetler;
nonzero build sonucu halen hatadir. Uyarilar gizlenmez; hedef JS release'tir.

## Dagitim ve APK

Yeni endpoint ve karbon kaydi icin backend deploy'u gerekir; yalniz APK'yi
kurmak eski sunucuya yeni endpoint eklemez. Kod push'u Render deploy basarisi
sayilmaz. Kullanici/Neon verisi sifirlanmaz, gizli panel degerleri degistirilmez.

Juri APK'si release modunda, mevcut proje debug anahtariyla imzalidir.
Play Store imzali surum degildir. Yeni paket icin onceki public asset silinmez;
ayri release etiketi ve SHA256 dogrulamasi kullanilir.

Nihai ARM64 release APK derlemesi basarili (542,7 saniye; eszamanli yerel
derleme/test yukunde). Imza `apksigner verify` ile dogrulandi, exit 0.
Boyut 27.563.346 byte, SHA256:
`4882b968a350091da9f5bd36a73b5628f8510c938ac1c90c273905776c6251bb`.
