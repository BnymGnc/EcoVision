# Doğrulama ve teslim durumu

Tarih: 24 Ekim 2026. Çalışma alanı EcoVision Flutter + Spring Boot deposudur. Bu rapor canlı Render/Neon üzerinde işlem yapılmış veya APK dağıtılmış olduğu anlamına gelmez.

## Gerçekten çalıştırılan kontroller

| Kontrol | Sonuç |
|---|---|
| `backend: .\mvnw.cmd -q clean verify`, ardından `verify` | 73 test, 0 hata, 0 başarısız, 0 atlanan; PostgreSQL test değişkeni açık |
| PostgreSQL 15.19 entegrasyonu | İzole yerel `ecovision_test`; gerçek 4.037 kayıt, tekrar import, DIM/Şanlıurfa sorgusu, V3 migration tekrar çalıştırma |
| Neon uyumlu aktarım işlemi | Transaction advisory lock; 101 mevcut kaydı güncelleyip 100'lük flush/clear sınırını geçen PostgreSQL testi geçti, fixture değişiklikleri geri alındı |
| İşlem güvenliği | Eşzamanlı iki görev claim'i toplam tek ödül verdi; eylem anahtarı replay'i tek kayıt bıraktı; gramaj değişince toplam iki katına çıktı; silme toplamı güncelledi |
| Giriş serisi | Aynı gün tekrar çağrı tek gün kaydı; ardışık/atlanan gün ve en uzun seri birim testi |
| Anonim erişim | Harita API'si 401; `/api/health` 200 |
| Hedefli oturum iptali | Parola sürümü değişince yalnız hedef hesabın eski JWT'si geçersiz oldu; yeni JWT ve diğer hesabın JWT'si geçerli kaldı |
| Model | Gerçek ONNX dosyası ve SHA-256 doğrulaması; altı gerçek test görselinde Python/Java ön işleme ve skor paritesi |
| Flutter `flutter test --no-pub` | 39 test geçti; görev ödülü beyaz ekran regresyonu, akademi, tema, avatar ve yeni karbon formu dahil |
| Mobil/geniş yerleşim | Karbon formu 390/768/1440 genişlikte widget testi; 390 px dropdown taşması bulundu ve düzeltildi |
| Flutter web release | Yerel API adresiyle `flutter build web --no-pub --no-wasm-dry-run` geçti |
| Gerçek Chrome etkileşimi | Giriş → tanıtımı atlama → ana ekran → karbon hesabı → 200 kWh/ay için 93,8 kg/ay ve 1.125,6 kg/yıl sonucu; 390/768/1440 px ekran görüntüleri, JavaScript/overflow hatası yok |
| Java 17 dağıtım paketi | Paket içindeki uygulama sınıflarında Java 17 üstü bytecode yok; Java 17 konteynerinde `prod`/Hibernate validate ile açıldı |
| Paketli veri | 5 Flyway migration doğrulandı; yeniden açılışta 4.037 değişmemiş DOA kaydı için yazma atlandı; `syntax error at or near default` görülmedi |
| HTTP gerçek fotoğraf | Multipart PNG → Java ONNX CPU → tarama veritabanı yanıtı; statik analiz yanıtı kullanılmadı |
| Diğer HTTP kontrolleri | Gerçek kayıt, 200 görev, DIM + OR malzeme filtresi ve cam ambalaj uygunluğu geçti |
| Compose şeması | `docker compose config --quiet` geçti; canlı Neon'a bağlı compose servisleri yeniden başlatılmadı |

PostgreSQL test komutu yalnız açıkça seçilmiş yerel porta izin verir:

```powershell
cd backend
$env:ECOVISION_TEST_JDBC_URL='jdbc:postgresql://127.0.0.1:25439/ecovision_test'
.\mvnw.cmd -q clean verify
```

Test veritabanı gerçek üretim veritabanı değildir. Üretim kullanıcılarına, parolalara veya ilerlemelerine yazılmadı. Başarısız broker'ı simüle eden mevcut testin ERROR kaydı beklenen test senaryosudur; Surefire sonucu başarısız değildir.

## Model ve performans

Model: `ecovision-mobilenetv2-trashnet-20261024-v2`, frozen MobileNetV2 + gerçek fotoğraflarla eğitilen lineer başlık. 2.524 benzersiz fotoğraf, 1.754/375/395 grup ayrımlı train/validation/test. Test macro-F1 **0,7881**, accuracy **0,8253**. 0,65 ret eşiğinde ret oranı **%20,51**, kabul edilen alt kümede doğruluk **0,9140**. Çoğunluk baseline macro-F1 **0,0624**.

Python CPU inference p95 yaklaşık **9,27 ms**; bu yalnız model çalıştırmasıdır. Gerçek HTTP + DB akışı çok daha farklıdır: `api-verification.json` 12 ardışık isteğin en yakın sıra p95'ini içerir. Aynı bilinen fotoğraf tekrarlandığından saha doğruluğu/çok kullanıcılı yük testi değildir.

Java 17 backend + gerçek ONNX inference, 512 MiB Docker sınırında denendi. Ölçülen cgroup peak **499.154.944 byte** (yaklaşık 476 MiB), `oom=0`, `oom_kill=0`; JVM VmHWM 485.476 kB idi. Test sınırlıdır ve kalan pay küçüktür; Render'ın gerçek CPU/bellek davranışı için garanti değildir. CPU arena ve memory-pattern önbellekleri kapatıldı; ONNX eşzamanlılık 1, model CPU thread sayısı 2. Render manifestindeki heap/metaspace/direct/code-cache sınırları bu yerel denemeyle uyumlu hale getirildi.

Verilen eski status 137 logu SIGKILL ile uyumludur; production OOM veya restart sebebi bu yerel ölçümden kesin kanıtlanamaz. `/api/health` basit metin döndürür, veri import etmez. 15 dakikalık dış ping'in kapanmaya yol açtığına dair kanıt yoktur. Önceki `columnDefinition` içine gömülü DEFAULT sorunu ayrı bir PostgreSQL DDL hatasıdır; var olan V1/V2 düzeltmeleri korunup test edildi.

## Araç ve platform sınırları

- Windows Flutter analyzer bu SDK kurulumunda `Bad state: No definition of type Future` ile çöktü. Analiz temizmiş gibi raporlanmıyor; başarılı release derlemesi ve testler ayrı kanıttır.
- Türkçe karakterli yerel build yolunda shader aracı dosya yazamadığından web çıktısı ASCII geçici dizine alındı. Kaynak yolları değiştirilmedi.
- IDE'den kalmış Java 21 sınıfları temiz build ile giderildi. Çalışan konteynere bind edilen JAR değiştirilmedi; her paket değişiminde konteyner durdurularak sabit kopya güncellendi.
- Gerçek Chrome'da çekirdek giriş/karbon akışı geçti; `browser-verification.json` ve temsilî ekran görüntüleri kaydedildi. CanvasKit erişilebilirlik ağacının bazı dekoratif başlıkları dışarıda bırakması nedeniyle test sonuçta gerçekten çizilen sayısal değeri bekler. Widget testlerini bütün sayfaların gerçek cihaz testinin yerine koymuyoruz.
- Android cihaz/emülatör testi ve yeni APK teslimi bu çalışmada yapılmadı. Canlı Neon bağlantısı, Render otomatik deployment, gerçek Gemini kotası/anahtarı ve provider hata senaryoları canlı istekle doğrulanmadı.

## Bilerek açık bırakılan kapsam

- Kısa karbon hesabı elektrik ve kişisel benzin/dizel tüketimidir. Isınma, beslenme, toplu taşıma, uçuş ve diğer alışverişler eksik kapsam olarak görünür; tam kişisel karbon envanteri iddiası yoktur.
- 200 görev kataloğu korunarak genişletildi. Yeni 100 görevin kanıtı kullanıcı beyanıdır; eski bütün olay tetikleyicileri gerçek saha akışıyla tek tek doğrulanmadı.
- Veri gruplaması yinelenen/yakın fotoğraf sızıntısını azaltır. TrashNet'te nesne kimlikleri olmadığından nesne bazlı tam sızıntısızlık garantisi yoktur. Bilinmeyen nesne/çoklu nesne/kötü ışık saha seti henüz yoktur.
- Hesapsız misafir modu, resmî DOA iade/ödeme teyidi, gerçek kupon/ağaç dikme ve doğrulanmış karbon kredisi yoktur. Jüri için ayrı normal test hesabı kullanılmalıdır.
- Mevcut admin parolası okunmadı/değiştirilmedi. Güvenli yerel sıfırlama CLI'si hazırdır; yetkili operatör gizli istemde parolayı kendisi belirler.
- Yarışma formları, YouTube videosu veya başvuru otomatik gönderilmedi. Yarışma metinleri taslaktır; kişisel motivasyon ve önceki proje değişikliği organizatör tarafından doğrulanmalıdır.

## Dağıtımdan önce

`render-neon-delivery.md` ortam değişkenleri tablosunu izleyin. Mevcut Neon/JWT sırlarını koruyun. Yeni endpoint'ler için backend ve Flutter birlikte dağıtılmalıdır. Gemini örnek anahtarla çalışmaz. Yerel motor için **`AI_PROVIDER=local`, `ML_ENABLED=true`** gerekir; varsayılan bulut modudur. `prod` profilini ancak mevcut şema/migration baseline'ı doğrulandıktan sonra kullanın. Canlı schema restore/drop/reset uygulanmadı.

Ekran/özellik envanteri ve eski-yeni karşılaştırması: `features-and-changes-tr.md`. Model ayrıntısı: `../ml/MODEL_CARD.md`. Katsayı/kapsam: `impact-methodology.md`.
