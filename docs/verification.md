# Doğrulama ve teslim durumu

Tarih: 24 Ekim 2026. Çalışma alanı EcoVision Flutter + Spring Boot deposudur. Bu rapor canlı Render/Neon üzerinde işlem yapılmış veya APK dağıtılmış olduğu anlamına gelmez.

## Son Android araç zinciri turu

Java 25 / Gradle 8.12 import uyumsuzluğu için proje daemon JVM'i JDK 21'e
sabitlendi; yerel IDE ve yeni terminal ayarları JBR 21'e yönlendirildi. API 36
için AGP 8.10.1 kullanılır. Eksik `sky_engine/lib/async` SDK kaynakları aynı
engine sürümünün resmî paketinden geri yüklendi. Flutter analizi artık
**No issues found**; uygulama kaynaklarındaki 91 tanı temizlendi. Üretilmiş
build dosyaları analiz dışında, uygulama lint kuralları açık tutulur.

**119 Flutter testi geçti** (`--concurrency=1`, 49 sn). Son ARM64 debug APK,
izole anahtarsız ASCII kopyada `scripts/build_android.ps1 -Offline` ile
149,6 sn Gradle süresinde başarıyla derlendi. Çıktı 97.284.372 byte;
SHA-256 `6be486485841e5872749771a4b77ba8c836367a68f718d04b9a64c0f80d7a99b`.
APK telefona kurulmadı veya mağaza yayını için imzalanmadı. SDK/üçüncü taraf
uyarıları, düşük bellek ayarları ve ağ teşhisi ayrıca belgelendi:
[Android/IDE raporu](android-build-and-ide-tr.md),
[makine-okunur doğrulama](android-toolchain-verification.json).
Aşağıdaki önceki APK hash'leri ve test sayıları tarihsel kayıttır.

## Son arayüz / konum / hız turu

Sonuçlar: **107 backend testi**, **116 Flutter testi** ve **7 dosya tabanlı
şehir/veri testi** geçti. Kayıt/grup/etkinlik konum kataloğu artık 81 il / 973
ilçe; eski ortak katalog 359 ilçeydi. Profil düzenlemenin ayrı üç-il kısıtı
kaldırıldı. Topluluk Yenile yanlış callback'i, arama yarışları, gizlilik/market
işlem kilitleri, profil güncelliği, sohbet taslağı, kısa sınav yerleşimi ve ağ
dayanıklılığı düzeltildi. Görev progress okumaları N+1 yerine toplu sorgulanır.

Bu tur web release derlemesi de geçti (81,3 sn). Gerçek Chrome'da topluluk
arama/yenileme 320/390/430 px, yetkili görsel ve fotoğraftan filtreli DOA
haritası/yol tarifi akışı, ayrıca akademi sınavı ve tek seferlik puan kontrolü
geçti. Gözlenen JS/overflow hatası yoktu. Yerel ONNX testi canlı Gemini/Render
doğrulaması veya yeni APK kurulumu olarak yorumlanmamalıdır.

Yeni ayrıntılı rapor: [ui-review-and-performance-tr.md](ui-review-and-performance-tr.md).
81 il DOA tablosu: [doa-city-counts-tr.md](doa-city-counts-tr.md).
Güncel test kanıtı: `ui-audit-verification.json`. Önceki APK/hash/bellek raporları
tarihsel kalır; bu UI revizyonu henüz telefona kurulmuş değildir.

## Önceki güvenlik turu

Güncel kodda medya için dinamik sunucu ACL'si ve yetkili Flutter görselleri,
logout access-token iptali, sürümlü sunucu quiz notlandırması ve günlük
kullanıcı/görsel hash'i bazlı tek tarama ödülü uygulanmıştır. Aşağıdaki eski
revizyonların test sayıları tarihsel kayıttır; güncel sonuç özeti
`final-security-verification.json` dosyasındadır. Bulgular, uyumluluk ve sınırlar:
[final-security-and-tests-tr.md](final-security-and-tests-tr.md).

Son Maven verify: **88 test, 0 hata, 0 başarısız, 0 atlanan**, izole yerel
PostgreSQL dahil. Son Flutter test çalışması: **88 başarılı test**. Gerçek HTTP
medya izin matrisi, eski kayıtlar/üyelikten çıkarılma, access JWT replay,
quiz eşzamanlı tek ödül ve tarama hash tekrarı testleri eklendi. Yeni migration
V6 iki kez uygulanarak idempotency kontrol edildi. Yerel JDK 25 ile test edilmiş
olmak Java 17 runtime doğrulamasının yerine geçmez; temiz paket ayrıca Java 17
konteynerinde `prod`/Hibernate validate ile açıldı. Paketli 278 uygulama sınıfının
en yüksek class major değeri 61 (Java 17); altı Flyway migration doğrulandı.
Başlangıç 42,925 sn sürdü; 4.037 DOA kaydı değişmemiş olarak işlendi ve PostgreSQL
`syntax error at or near default` hatası görülmedi. IDE'nin daha yüksek Java
sürümüyle ürettiği bir ara sınıf ilk smoke testini bozdu; `clean verify` ile
tamamen yeniden paketlendikten sonraki runtime testi başarılıdır.

Son web build 86,8 sn'de başarılı oldu. Gerçek Chrome'da 390 px görünümde özel
profil fotoğrafı Bearer header ile alındı; gerçek dosya seçimi → ONNX analizi →
cam rehberi → glass filtreli DIM haritası → seçili gerçek koordinata Google Maps
isteği geçti. Harita sağlayıcısının son yönlendirme URL'si değil, ilk yön
isteğinin hedef koordinatı kontrol edildi. Akademi arama/ders/sınav/puan/
tamamlandı işareti ve tekrar ödül almama da yeni backend'de geçti; ders
320/390/768 px incelendi. JS ve overflow hatası yok. Kanıtlar:
`security-core-browser-verification.json`, `academy-browser-verification.json`
ve ilgili ekran görüntüleri. Gerçek telefon GPS'i/turn-by-turn sürüşü değildir.

Yeni Java 17 + ONNX smoke testinde 512 MiB cgroup sınırında raporlanan peak
537.321.472 byte (yaklaşık 512,4 MiB), `memory.events max=146`, `oom=0`,
`oom_kill=0`; JVM VmHWM 529.692 kB. Bu kısa testte süreç öldürülmedi ama bellek
baskısı vardır: **512 MiB için güvenli ONNX kapasitesi doğrulanmadı**. Önceki
476 MiB sonucunu yeni sürümün garantisi olarak kullanmayın. Varsayılan
`AI_PROVIDER=gemini`, `ML_ENABLED=false` değişmedi. Üretimde daha fazla bellek
veya ölçülmüş bulut modu değerlendirilmeli; gerçek Gemini anahtarı/kotası bu
yerel çalışmada sınanmadı. Bu sonuç production'daki eski 137'nin kanıtı değildir.

Son test turunda canlı Neon/Render ve APK kurulumu yapılmadı. Sonraki kullanıcı
mesajı kodun GitHub'a gönderilmesine ayrıca izin verdi; push, canlı sağlık
doğrulaması değildir ve Render auto-deploy açıksa dağıtımı tetikleyebilir.
Yetkili medya/quiz sözleşmesi nedeniyle backend ve güncel istemci birlikte
dağıtılmalıdır. Aşağıdaki eski kayıtlar yeni sürümün kapasite sertifikası değildir.

Android ARM64 debug APK da derlendi: `flutter build apk --debug --no-pub
--target-platform android-arm64`, Gradle 201,7 sn. Çıktı
`frontend/build/app/outputs/flutter-apk/app-debug.apk`, 97.252.091 byte.
Önce SDK yolunun UTF-8/Properties okuma farkı settings.gradle.kts içinde
giderildi. Ardından shader aracının Türkçe karakterli çıktı yoluna yazamaması
nedeniyle kaynak taşınmadan ASCII adlı geçici kopyada derlendi; gerçek gizli
constants.dart yerine anahtarsız constants.example.dart kullanıldı. API hedefi
mevcut Render adresidir; bu derleme canlı API test edildi anlamına gelmez.
SDK veya global Flutter ayarı değiştirilmedi. APK telefona kurulmadı ve mağaza
yayını için imzalanmadı. Eski bölümlerdeki “APK yapılmadı” tarihsel kayıttır.

## Önceki arayüz revizyonları

### Climathon: kaynaklı rehber ve AI görünürlüğü

10 modül / 30 soru korunarak içerik yenilendi; kategori araması, tamamlanma
filtreleri, açılabilir ayırma bölümleri, güvenlik/model sınırları ve HTTPS kaynakları
eklendi. Sonuç ekranı provider/model özetini ve ilgili rehbere geçişi gösterir.
Mevcut doğrudan DOA düğmesi ve API sözleşmeleri korunur.

- **77 Flutter testi geçti.** Yeni testler gerçek asset şemasını, Türkçe aramayı,
  HTTPS kısıtını, tamamlanma filtresini, sonuçtan doğru modüle yönlenmeyi ve dört
  temada 320/430 px + 1,6 metin ölçeğinde ders yerleşimini kontrol eder.
- **76 backend testi, 0 hata / başarısız / atlanan.** İlk denemede kapalı yerel
  Docker/PostgreSQL nedeniyle bağlantı reddi oldu; izole test DB açılınca yeniden
  çalıştırıldı. Production veritabanı test hedefi yapılmadı.
- Maven package tamamlandı (exit 0). JAR içeriği ayrıca kontrol edildi:
  ham DOA JSON/manifest, ONNX, lisans ve migration yerinde; türetilmiş CSV,
  GeoJSON ve tekrar JSON dışa aktarımları paket dışında.
- Web release derlendi. Gerçek Chrome'da arama → ders → üç doğru yanıt → backend
  ilerleme ve artan puan bakiyesi → tekrar tamamlamada sıfır ek puan → listede
  tamamlandı akışı geçti. 320/390/768 px ders görüntüleri kaydedildi; JS veya
  taşma hatası yok. Kanıt: `academy-browser-verification.json`.
- Bu önceki test, sunucunun cevapları notlandırdığını kanıtlamıyordu. Son güvenlik
  turunda bu açık kapatıldı; güncel sunucu notlandırması ve testleri yukarıdadır.
- 3 eski tanı ekran görüntüsü ve 67 eski, ignore edilmiş JVM hata/replay logu
  temizlendi (loglar yaklaşık 32,9 MB); en yeni tanı logu korundu. Tanı ekran
  görüntüleri artık ignore edilen build dizinine yazılır. Kaynak/veri/model dosyası
  silinmedi; tekrar veri dışa aktarımları kaynakta kalır, runtime'dan dışlanır.
- Bu turda Render deploy, APK kurulumu, Git commit/push yapılmadı. .env ve
  kullanıcıya ait mevcut CI değişikliği değiştirilmedi. Ayrıntılı açıklar ve
  sonraki adımlar `climathon-readiness-tr.md` dosyasında.

### Profil başlığı ve giriş takvimi

Ayrı giriş serisi kartı kaldırılarak seri sayısı avatar/isim başlığına taşındı. Dokununca yalnız mevcut kullanıcının aylık kayıtlarını okuyan `/api/users/login-history?month=YYYY-MM` endpoint'iyle takvim açılır. Yeni tablo veya migration gerekmedi; mevcut `user_login_days` benzersiz kullanıcı/gün indeksi kullanılır. **76 backend testi (PostgreSQL dahil, 0 atlanan) ve 64 Flutter testi geçti.** Kendi kullanıcı kimliğiyle ay sınırları/leap-day sorgusu, bozuk/gelecek ay reddi, anonim erişimin 401 olması, gerçek kayıtların okunması ve okuma sırasında yeni giriş oluşturmama kontrol edildi. Flutter testleri takvim açma/ay değiştirme/kapatma, hata ve tekrar deneme, eski backend için etiketli son-yedi-gün görünümü, avatar seçiminin anında yansıması, dört temada 320/430 px ve 1,8 kat yazı ölçeğinde taşma olmamasını kapsar. Gerçek Chrome'da yeni başlık, takvim açma/önceki aya geçme/kapatma, 200 HTTP yanıtları ve 320/390/430 px ekran görüntüleri doğrulandı; rapor `profile-browser-verification.json` dosyasındadır. Küçük ekrandaki CO₂ gösterge başlığı da sözcük bölünmesini önleyecek şekilde kısaltıldı; ölçülmemiş veri hâlâ sayısal tasarruf olarak gösterilmez.

Tarama sonucu doğrudan DOA haritası düğmesine döndürüldü; ambalaj kontrolü ve eylem kaydı kaldırıldı. Eski 20 soruluk karbon anketi, soruların altındaki isteğe bağlı elektrik/yakıt girdileriyle yeniden ana akış oldu. **49 Flutter testi geçti**; ek girdilerin doğrulanması, yıllık/aylık dönüşümü, çift sayımın engellenmesi ve doğrudan harita düğmesi için regresyon testleri eklendi. Yüksek ama geçerli tüketim sonuçlarının ödül endpoint'inde reddedilmemesi için yalnız skor doğrulama üst sınırı genişletildi; sabit ve tek seferlik ödül mantığı değiştirilmedi. İlgili backend DTO doğrulama testi geçti.

Yeni Flutter web derlemesi ve gerçek Chrome kontrolü de geçti: giriş/tanıtımdan 20 soruluk ankete geçildi; ilk seçeneklerle 1.000 kg/yıl (1,00 ton) sonucu ve tek seferlik ödül yanıtı görüntülendi. 390/768/1440 px sonuç ekranları incelendi; tarayıcıda JavaScript veya taşma hatası görülmedi. Ek tüketim alanları ayrıca 390 px widget testinde doldurularak, negatif giriş reddi ve 3.152 kg/yıl birleşik sonuç doğrulandı.

Ham JSON ve yerel PostgreSQL karşılaştırması: 4.037 benzersiz kaynak ID'si, 2.162 DIM, 1.764 MIN ve 111 SDM; sayısal olmayan koordinat yok. Ayrıca **önceki turda canlı Neon'a yalnız okuma işlemiyle** bağlanıldı: 4.037 DOA kaydının bütün kaynak ID'leri ve koordinatları dosyayla eşleşti (koordinat toleransı 1e-8 derece). Eski geniş `%urfa%` sorgusu 28 DIM bulmuştu; bu gerçek il sayımı değildir: Diyarbakır/Urfa Yolu adresini de eşleştirir. Yeni adres-il sınıflandırması Şanlıurfa için 27 DIM bulur (`doa-city-counts-tr.md`). Tabloda diğer mevcut kayıtlarla toplam 4.175 satır vardı; hiçbir kayıt silinmedi/değiştirilmedi. Kanıt özeti `doa-count-verification.json`, tekrar kontrol aracı `scripts/verify_doa_counts.py --live-neon-read-only`. Aşağıdaki tablo ilk kapsamlı teslimin tarihsel test kaydıdır.

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
- Android cihaz/emülatör testi ve yeni APK teslimi bu çalışmada yapılmadı. Canlı Neon'da yalnız DOA kataloğunun okunması doğrulandı; üretim kayıt/giriş/yazma akışı, Render otomatik deployment, gerçek Gemini kotası/anahtarı ve provider hata senaryoları ayrıca canlı istekle doğrulanmadı.

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

## Son kapsamlı yerel denetim

24 Ekim 2026: güncel bulgular, kapsam ve açık riskler
[ecovision-final-audit-tr.md](ecovision-final-audit-tr.md) içinde;
makine tarafından okunabilir sonuçlar
[final-audit-verification.json](final-audit-verification.json) içindedir.
Bu turun tamamlanan testleri: **114 backend / 124 Flutter / 11 veri testi**;
Flutter analizinde 0 sorun. 4037 ham/yerel DB/API noktası ve 81 il sayımı
eşleşti. Gerçek STOMP mesaj/typing, grup katılımı, anket ve etkinlik işlemleri
yerel Java 17 prod backend üzerinde doğrulandı. Canlı Render/Neon/GitHub
değiştirilmedi. Bu dosyanın önceki bölümlerindeki ölçümler tarihsel kanıttır.
Son kaynaklarla web derlemesi 56,6 sn'de geçti; ARM64 debug APK 217,3 sn'de
üretildi. Release doğrulaması çevrimdışı önbellekte bulunmayan Flutter engine
bağımlılığı yüzünden tamamlanmadı. Güncel APK hash'i ve açık riskler son rapordadır.
