# Final mobil duzeltme - 25 Ekim 2026

Bu belge 1.0.1 surumunun test kaydidir. Harita kamera sorgusu davranisi
1.0.2'de GPS'e sabitlendi; guncel davranis ve yeni APK icin
[GPS ve geri donusum notlarina](gps-recycling-update-tr.md) bakiniz.

## Tarama animasyonu

Tarama durumu artik kok Overlay uzerinde tam ekrandir: alt navigasyon ve
arkadaki butonlar analiz sirasinda kullanilamaz. Basari, hata ve dispose
yollarinda overlay kaldirilir. Mevcut AI cagrisi ve puan akisi degismedi.

Sabit 600 piksel minimum yukseklik ve kaydirilan tam ekran kaldirildi.
SafeArea ve sinirli Expanded tarama cercevesi kullanilir. Acik/koyu dort
temanin surface/onSurface/primaryContainer renkleri izlenir; inverseSurface
ile temanin tersine donen sabit bir kaplama yoktur. Animasyon cizgisi
CustomPainter/repaint ile izole alanda cizilir; her karede widget agaci
yeniden kurulmaz. Azaltilmis hareket tercihi cizgi animasyonunu durdurur.

## Harita: sinirlar ve tekrar eden is

- UI'daki Sinirsiz secenegi kaldirildi: yaricap 1-50 km, varsayilan 10 km.
  Taramadan ilgili malzemeyle girilince de null/sinirsiz yerine 50 km kullanilir.
- Harita zoom'u 3-18, tile native zoom'u en fazla 18. Onceki MapOptions'ta
  maxZoom yoktu; gruplama formulu ise sinirsiz zoom'u pow/floor'a veriyordu.
  Yeni indeks finite olmayan zoom'u ve kutup koordinatlarini guvenli ele alir.
- Goruntu alaninda 100'luk sayfalama korunur. Bellekte en fazla 300 nokta
  tutulur; diger noktalar icin bolgeye kaydirma/yakinlastirma kullanilir.
  Kaynak veya veritabani kayitlari silinmedi, sahte nokta eklenmedi.
- Kamera hareketi kok ekrani setState ile yeniden kurmaz. Isaretci katmani
  ayridir; projeksiyon FlutterMap EPSG3857 ile bir kez, kumeler veri/tam zoom
  degisince hesaplanir. Pan/ayni zoom'daki rebuild bu listeleri tekrar kullanir.
- Pan buffer 0, tile keep buffer 1; gereksiz ekran disi karo talebi azaltilir.
- 550 ms debounce, iptal ve eski yanit korumasi korunur. 200 hareketli testte
  yalniz bir yeni API istegi gider. Konum beklerken 4 hareket patlamasi da
  tek GPS istegini paylasir; konumu gec tamamlanan eski arama HTTP'ye gitmez.
- Ayni koordinattaki noktalar zoom 18'de kume halinde kalirsa listeyle
  secilebilir; sonsuza kadar yakinlastirmayi deneyen tiklama kaldirildi.
- OSM atfi ve malzeme/durum ayrimi korunur. Radius harita merkezine gore
  backend'de hesaplanir; Flutter render dongusunde mesafe hesabi yoktur.

Bunlar kodda bulunan somut risk/tekrarlarin duzeltilmesidir. Fiziksel telefonda
ANR kaydi veya native profiler olcumu alinmadigi icin onceki kilitlenmenin tek
ve kesin nedeni ya da her cihazda kesin FPS sonucu olarak sunulmaz.

## Liderlik

Genel liste onceki teslimde `/api/leaderboard/global` ile tum kullanicilari
kapsiyordu. Sekme adi simdi acikca **Tum sehirler**. Sehir filtresi bos
baslar; kisi isterse 81 ilden birini secer, sonra tekrar Tum sehirler'e
donebilir. Arkadaslarim ayridir. Backend veya gizlilik kurali degismedi.

## Dogrulama

Ilk odakli kosu: 18 test gecti; dort tema, 320x480 ve yatay 700x320 ekran,
buyuk yazi, harita pin/zoom/mesafe sinirlari, debounce ve liderlik filtresi.
GPS korumasi sonrasi yeni odakli kosu: 4 harita testi gecti. Devam eden ilk
tam kosu, son GPS korumasi oncesi derlenen kaynakla 145 basarili/1 hataliydi;
bu kosu basarili sayilmadi. Nihai kaynaklarla tam kosu tekrarlandi:
**146 test basarili, 0 hata/basarisizlik, 2 dakika 24 saniye**.
Komut: `flutter test --no-pub --concurrency=1 --reporter=expanded`.
`dart analyze lib test`: **No issues found**.

Yerel mikrobenchmark (500 guncelleme, 300 nokta): eski tekrar gruplama
79.400 mikrosaniye, hazir indeks/ayni zoom 123 mikrosaniye. Bu birim-test VM
olcumudur; telefon frame suresi, tam uygulama hizi veya FPS iddiasi degildir.

Backend/Neon/AI modeli degismedi. Bir onceki backend teslimindeki 124 test
bu turun yeni backend testi diye sunulmaz. APK 1.0.1+2, Android ARM64,
release modu/mevcut debug imzasi; Play Store production imzasi degildir.

## Son paket ve yayin

- Kod commit'i: `245b2c4ac20a5ffaa08c5baaefaf2f51487cec34`, EcoVision main.
- [CI 40223607093](https://github.com/BnymGnc/EcoVision/actions/runs/40223607093): success.
- Son APK derlemesi: 293,3 saniye, exit 0; versionName=1.0.1, versionCode=2,
  API24+, ARM64. `aapt dump badging` ve `apksigner verify` exit 0.
- Boyut 27.563.350 byte. SHA256:
  `c06c76ed17c9400d5ad41e12019ba1528dfbbc1f2859b80d72e14891af8257fa`.
- [Final APK indir](https://github.com/BnymGnc/EcoVision/releases/download/jury-2026-10-25-final/EcoVision-jury-arm64.apk).
  Public indirme kimlik bilgisi gonderilmeden tamamlandi: HTTP 200, ayni
  boyut ve SHA256. Onceki GitHub Releases dosyalari degistirilmedi/silinmedi.
- Web JS release: 219,5 saniye, exit 0. WASM dry-run uyumsuzluk uyarilari
  logda korundu; uretilen paket WASM degildir. Yerel sunucu HTTP 200,
  Brave `http://127.0.0.1:7357/?build=1.0.1-final` ile yeniden acildi.
- Son canli GET `/api/health/live`: 200 ve gercek uygulama metni;
  `/actuator/health/readiness`: 200, status UP. Render panelindeki calisan
  SHA bu turda bagimsiz okunmadi. Backend davranisi/model secimi degismedi.
- APK'nin bu turda fiziksel telefona kurulumu/ANR profiler olcumu yapilmadi.
