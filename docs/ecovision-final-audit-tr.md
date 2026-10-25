# EcoVision: son kapsamlı yerel denetim

Tarih: 24 Ekim 2026. Bu rapor yerel çalışma ağacına aittir. Render'a dağıtım,
Neon'a yazma, GitHub'a push veya telefona kurulum yapılmış olduğu anlamına gelmez.
Önceden değiştirilmiş dosyalar korundu; kullanıcı/puan/geçmiş silen migration yoktur.

## 1. Bulgular, kök nedenler ve durum

| Öncelik | Sorun / kök neden | Durum |
|---|---|---|
| P0 | STOMP CONNECT kimliği `StompHeaderAccessor.wrap` ile kopyaya yazılıyordu; sonraki abonelik asıl oturumu bulamıyordu | Asıl `MessageHeaderAccessor` kullanıldı; üyelik kontrolü korunarak CONNECT regresyonu eklendi |
| P1 | Aynı fotoğrafın ödül sorgusu tarihle sınırlıydı; başka gün yeniden puan verilebiliyordu | Aynı kullanıcı/hash için geçmiş ödül aranır; gün değişince ikinci ödül yok |
| P1 | Eski etkinlik -> grup dönüşümü her açılışta adı/açıklamayı/üyeleri yeniden kopyalayabiliyordu | Aktarılmış grup yeniden dönüştürülmez; düzenlenen ad/kapak ve çıkarılan üyeler korunur |
| P1 | Harita sürüklenince viewport değişiyor fakat 10 km yarıçapı eski GPS merkezinde kalıyordu | Viewport sorgusunun merkezi kamera merkezi olur; sonuç yokmuş izlenimi giderilir |
| P1 | Harita il/ilçe araması ve kesilmiş sonuç sayısı hakkında bilgi yoktu | Yeni konum envanteri, sayfalı arama, il/ilçe seçimi ve gösterilen/toplam sayacı |
| P1 | Java 25, Gradle 8.12 ile çalıştırılıyordu | Desteklenen JBR 21'e proje/IDE seçimi; JDK 17 de build script tarafından desteklenir; Java 25 reddedilir |
| P1 | IDE, Java 17 hedefli Maven çıktısını Java 21 sınıflarıyla yeniden yazabiliyordu | Yerel IDE autobuild kapalı; Maven ana/test release 17; wrapper temiz çalıştırma paketi üretir |
| P1 | Windows Maven wrapper `JAVA_HOME`/`MAVEN_OPTS` kullanmıyordu | Her iki wrapper açık JDK seçimini ve Maven JVM seçeneklerini kullanır |
| P1 | Tema değişikliklerinin HTTP yanıtları ters sırada tamamlanabiliyordu | Kayıtlar sıralı; hesap nesli ve yakalanan callback ile diğer hesaba taşınmaz |
| P1 | Nunito fontu ilk açılış/testte internetten indiriliyordu | Açık lisanslı font uygulamaya paketlendi; aynı tipografi çevrimdışı çalışır |
| P2 | Sayısal koordinat dalı NaN/Infinity ve sınır dışını kabul ediyordu | Sayısal/metinsel değerlerde ortak finite ve enlem/boylam aralığı kontrolü |
| P2 | Harita kümeleri her küsuratlı zoom değişiminde yeniden kuruluyordu | Kümeler tam zoom kademesinde güncellenir; kamera ağı 450 ms debounce ile ayrıdır |
| P2 | SDM kayıtları kaynakta var, görünür tür seçeneği yoktu | SDM ayrı ve varsayılan kapalı filtre; tüketici makinesi diye tanıtılmaz |
| P2 | DOA doğrulama script'i `%urfa%` ile Urfa Yolu'nu sayıyordu | UUID/adres-idari alan eşleşmesiyle Şanlıurfa sayımı |

Önceki turdan korunan düzeltmeler: Topluluk Yenile callback'i; 81/973 ortak
katalog; başlangıçta geçici ağ hatasında oturumu koruma; satın alma/gizlilik
tek-işlem kilitleri; sohbet taslağını koruma; görsel sıkıştırmayı mobil isolate'a
taşıma; görev ilerlemelerini toplu okuma; yetkili medya ve sunucu quiz doğrulaması.
Bunların ayrıntısı [önceki UI denetiminde](ui-review-and-performance-tr.md).

## 2. Eski ve yeni davranış

| İşlem | Önce | Şimdi |
|---|---|---|
| Tarama | Fotoğraf -> sonuç -> DOA | Aynı akış; aynı fotoğraf tekrar XP üretmez |
| Karbon | 20 soru + isteğe bağlı ölçülebilir veri | Aynen korundu; geri dönüşüm/karbon kredisi iddiasına çevrilmedi |
| Harita | Yakın/viewport, en fazla 500 sonuç | Eski endpoint durur; yeni arama 100'lük sayfalar, toplam, il/ilçe |
| Şehir değişimi | Haritayı elle sürüklemek gerekiyordu | 81 il envanterinden seç; ilçeler sadece o ile ait; eski ilçe temizlenir |
| Topluluk | Üye STOMP aboneliğinde reddedilebiliyordu | Asıl bağlantı Principal'ı korunur; yetkisiz abone reddedilir |
| Grup yeniden başlatma | Eski veri yeni düzenlemeyi ezebiliyordu | Tamamlanmış dönüşüm tekrar oynatılmaz |
| Tema | Hızlı seçimlerde eski tercih sonradan yazılabiliyordu | Görünüm hemen değişir; kalıcılık sıralı ve hesap ayrımlı |

## 3. Değişen dosyalar

- `backend/.../config/WebSocketConfig.java`: STOMP kimliği ve yetişkin erişimi.
- `backend/.../config/DataInitializer.java`: eski grup göçünün tekrarını engelleme.
- `backend/.../service/ScanService.java`, `repository/ScanHistoryRepository.java`:
  hash bazında tek ödül; mevcut günlük tarih/geçmiş alanları silinmedi.
- `backend/.../service/DoaLocationService.java`: idari adres çözümleme, 81 il/973
  ilçe envanteri, 60 saniyelik sınırlı immutable projection önbelleği.
- `backend/.../service/DoaMapService.java`, `repository/MapPinRepository.java`,
  `controller/MapPinController.java`: sayfalı/il filtreli arama; eski API korunur.
- `backend/src/main/resources/data/turkey_locations.json`: aynı merkezi
  kataloğun sunucu kopyası; Python testi iki kopyanın eşitliğini zorunlu kılar.
- `backend/pom.xml`, `mvnw`, `mvnw.cmd`: ana/test bytecode 17, JDK/JVM seçimi.
- `frontend/lib/screens/map_screen.dart`, `models/map_pin.dart`,
  `models/doa_catalog.dart`, `widgets/doa_area_picker.dart`, `services/api_service.dart`:
  konum seçimi, toplam/sayfalama, iptal/eski yanıt koruması ve koordinat doğrulama.
- `frontend/lib/theme/theme_controller.dart`, `pubspec.yaml`, `assets/fonts/`:
  sıralı hesap-bağlı tema kaydı, paketlenmiş lisanslı Nunito.
- `scripts/audit_locations_and_doa.py`, `test_locations_and_doa.py`,
  `verify_doa_counts.py`: 81/973 kapsamı, ilçe/kalite envanteri ve doğru DB sayımı.
- `scripts/final_audit_runtime.py`, `browser_smoke.py`: gerçek yerel HTTP/STOMP
  ve Chrome kullanıcı akışları; canlı URL kabul edilmez.
- `scripts/build_android.ps1`: seçilen JDK 17/21 ile ASCII geçici dizinde debug
  veya release derleme; sır/keystore kopyalanmaz.
- Backend/Flutter regresyon testleri: konumlar, sayfalama, STOMP, grup göçü,
  aynı fotoğrafın ertesi günü, tema sırası ve hesap geçişi.
- Yerel `.vscode/settings.json` Git dışındadır; paylaşılan mutlak JDK yolu yoktur.

Başlangıçta kirli olan CI/altyapı dosyaları ve kullanıcı veri dışa aktarımları
geri alınmadı. Kullanıldığı belirsiz dosya silinmedi. Yeni DB migration yoktur:
bu tur şema değiştirmez, mevcut indeksin `(user_id,image_hash,...)` öneki ödül
kontrolünü destekler. Mevcut V1-V6 migration'ları korunur.

## 4. DOA envanteri: 81 il

Tam tablo: [81 ilin tür bazlı envanteri](doa-city-counts-tr.md).
İşlenebilir çıktılar: [il CSV](doa-city-counts.csv), [973 ilçe CSV](doa-district-counts.csv),
[il bazlı kalite CSV](doa-city-quality.csv), [ayrıntılı JSON](doa-city-counts.json),
[UUID/il/ilçe eşlemesi](doa-point-city-index.csv).

| İl | DIM | MIN | SDM | Diğer | Toplam |
|---|---:|---:|---:|---:|---:|
| İstanbul | 300 | 408 | 17 | 0 | 725 |
| Ankara | 144 | 146 | 8 | 0 | 298 |
| İzmir | 94 | 33 | 3 | 0 | 130 |
| Kayseri | 29 | 36 | 1 | 0 | 66 |
| Şanlıurfa | 27 | 2 | 2 | 0 | 31 |
| Diyarbakır | 31 | 38 | 4 | 0 | 73 |
| Isparta | 17 | 1 | 1 | 0 | 19 |
| Türkiye + ili çözülemeyenler | 2162 | 1764 | 111 | 0 | 4037 |

- Snapshot: `2026-10-24T08:20:51.364618+00:00`; ham SHA256:
  `2c8cb6afd54826941135f3d3b17e5cd6df544d0201fb05abc5fb84f85ad4bde5`.
- Kaynak UUID'leri benzersiz; eksik/geçersiz sayısal koordinat yok. Türkiye için
  yaklaşık dikdörtgen kontrolünde dışarıda kayıt yok; bu bir resmî sınır testi değildir.
- 65 koordinat grubunda 152 kayıt aynı koordinatı paylaşır. Farklı UUID/türler
  aynı yerde bulunabilir; otomatik mükerrer sayılıp silinmedi.
- 4034 noktanın ili çözüldü; 3 noktanın adresinde kesin il yok. Adres yerine
  mağaza adı veya koordinattan şehir uydurulmadı.
- İli çözülenlerde 6 ilçesi çözülemeyen kayıt var. Özellikle `SAMSUN/44700`
  ve `DİYARBAKIR/KIZILTEPE` kaynak tutarsızlıkları olduğu gibi raporlanır.
- 4037 kaydın güncel telemetri zamanını doğrulayan veri yoktur. `state=true`,
  kaynak hazne bildirimi; teknik malzeme desteği ve programa göre açık/kapalı
  durumu ayrı anlamlardır. Uzaklık çalışma durumuna katılmaz.
- Tüm 81 ilde bu snapshot'ta DIM var. Bu sonuç ülkenin canlı, eksiksiz kurulum
  envanteri garantisi değildir; kaynaktaki kapsamı gösterir. Sıfır veri olursa
  seçicide sıfır görünür, sahte nokta eklenmez.

Yerel PostgreSQL'de sayı, UUID ve koordinatlar ham 4037 kayıtla eşleşti.
Yeni API'nin 81 il sayımı ve sayfalardan tekil nokta kapsamı runtime raporunda
ayrıca doğrulanır. Canlı Neon bu tur sorgulanmadı/değiştirilmedi.

## 5. İl/ilçe verisinin doğrulanması

Resmî [HGM Excel kaynağı](https://www.harita.gov.tr/uploads/files-folder/il_ilce_alanlari.xlsx)
yeniden indirildi; SHA256 kayıtlı
`e6054762f2e03e72b56ef85cb430ea00b012ccc5eba3a8fea08e3a631d3b6447`
ile eşleşti. 81 il ve 973 ilçe vardır. Eski Eyüp/Kazan adlarının normalize
edildiği resmî kaynaklar JSON metadata ve önceki UI raporundadır.

Kayıt, profil düzenleme, grup oluşturma/düzenleme, etkinlik konumu ve topluluk
filtresi `TurkishLocations` kullanır. Yeni harita envanteri aynı kataloğu sunucuda
kullanır. Dart/asset/backend kopyalarının eşitliği testlidir. Tüm il/ilçe
çiftleri iki adres düzeninde (`İL/İLÇE`, `İLÇE/İL`) otomatik sınanır.
Harita seçicisi widget testi 81 ili değiştirip her birinin doğru ilçelerini
ve önceki ilçe seçiminin temizlendiğini kontrol eder.

Ulusal mahalle listesi eklenmedi: sahte/eksik dropdown yerine kullanıcının
gerçek mahalle metni korunur. Şehir aramasında Türkçe karakter normalizasyonu
il/ilçe çözümleyicisinde vardır; bütün serbest metin backend aramalarının
aksan-duyarsız olduğu iddia edilmez.

## 6. Ekranların işlevsel kontrolü

`Kod + test`, gerçek telefonda bütün düğmelerin tek tek denenmesi demek değildir.
Chrome/HTTP/STOMP sonuçları ayrı JSON kanıtlarında tutulur.

| Ekran | Kontrol / kanıt | Sınır |
|---|---|---|
| Splash | Geçerli oturum ve geçici ağ hatası widget testleri | Gerçek Render cold-start ölçülmedi |
| Giriş | Güvenli JSON hata işleme, Chrome e-posta/parola girişi | Google girişi istemcide yok |
| Kayıt | 81 il, ilçe temizleme, yaş/form kuralları | Tüm 973 seçenek fiziksel telefonda tıklanmadı |
| Onboarding | Hesaba bağlı tercih ve Atla navigasyonu | Yerel tercih uygulama verisi silinince sıfırlanabilir |
| Ana sayfa | Sekmeler lazy açılır; fotoğraf/galeri/merkez yönlendirmesi | Gerçek telefon kamerası bu tur denenmedi |
| Sonuç | Rehber + DOA doğrudan düğmesi, belirsiz malzeme ayrımı | Barkod/depozito doğrulaması yok |
| DOA haritası | Sayfalama, OR malzeme, şehir/ilçe, viewport ve sayılar | Canlı kabul teyidi değil |
| Etkinlik konum haritası | Koordinat/güvenli geri navigasyonu kod incelemesi | Eski konum akışı uyumluluk için durur |
| Görevler | Ödül sonrası liste görünür kalma widget testi; DB eşzamanlı claim | Beyan görevleri fiziksel eylem kanıtı değil |
| Akademi listesi | Katalog/arama/ilerleme testleri | İçerik statik kaynaklı eğitimdir |
| Ders ayrıntısı | Okuma/kaynak bağlantıları, Chrome kısa ekran | Dış kaynakların sürekliliği garanti değil |
| Quiz | Sunucu cevap doğrulaması ve tek ödül; küçük/yatay ekran testi | Gizli doğru seçenek istemci puanı olarak kabul edilmez |
| Karbon 20 soru | Opsiyonel elektrik/yakıt ve çakışmayan toplam regresyonu | Yaklaşık anket; sertifikalı envanter değil |
| Ayrıntılı karbon | Kaynak/eksik kapsam testleri, eski kayıt API'si | Ana merkez 20 soru akışına gider |
| Market | Tek satın alma, yetersiz bakiye/hata ve 320px testleri | Sahip olunan tüm kozmetiklerin görünür kuşanması eksik |
| Avatar yolu | Ömür boyu XP ve harcanabilir puan ayrımı | Görseller sanal oyunlaştırmadır |
| Avatar seçimi | API dönüşü UI yenileme, dispose sonrası haptic testi | Gerçek cihaz yeniden kurulum kontrolü yapılmadı |
| Liderlik | Şehir/arkadaşlar, boş durum yenilemesi | Çok büyük şehir listesinde sayfalama eklenmeli |
| Topluluk | Yenile -> oluştur regresyonu, arama yarışları, 18+ kilidi | Gizli grup ayrıntıları üyelik kontrolüyle sınırlı |
| Grup oluşturma | Ortak konum dropdown, şifre/şifresiz akış kod/test | Tüm kapak formatları telefonda denenmedi |
| Grup sohbeti | Gerçek STOMP mesaj/typing, geçmiş ve taslak testleri | Tek-instance broker ölçekleme sınırı var |
| Etkinlik sohbeti | STOMP bağlantı/reconnect geçmiş uzlaştırması | Eski etkinlik uyumluluk ekranı |
| Grup bilgisi | Üye listesi/prefetch, rol ve kalıcı kapak kontrolleri | Kicked bağlantının canlı aboneliği ayrıca sertleştirilmeli |
| Grup ayrıntıları | Üyeler/etkinlikler, rol bazlı oluşturma/silme | Kurucu/yönetici yetkisi sunucuda uygulanır |
| Etkinlik kartı | Oluşturma, RSVP, katılımcı ve silme HTTP testi | Gerçek saha katılımı doğrulanmaz |
| Profil | Yeniden girişte yenileme; responsive başlık/takvim testleri | Uygulama XP'si karbon tasarrufu sayılmaz |
| Public profil | Yaş/gizlilik/friendship medya erişimi DB entegrasyonu | Ekranı gizlemek tek başına güvenlik değil; medya ACL korunur |
| Profil düzenleme | Aynı 81/973 katalog; il/ilçe reset ve mahalle koruma | Ulusal mahalle doğrulaması yok |
| Parola değişimi | Backend BCrypt/credential revocation mevcut regresyonları | Tam e-posta kurtarma akışı yok |
| Tarama geçmişi | Kronolojik veri ve negatif/boş durum kod incelemesi | Eski endpoint tüm geçmişi getirebilir |
| Ayarlar | Sıralı tema, gizlilik kilidi, yetişkin fotoğraf kuralı | Bildirim tercihi backend push ayarı değil |
| Bildirimler | Liste/hata/okundu kontrolü; foreground single-flight sayaç | OS push sağlayıcısı yok |
| Superuser paneli | Rol denetimi, mounted/hata kontrolleri | Bütün moderasyon işlemleri Chrome'da tek tek denenmedi |
| Ana sekmeler | Yalnız ziyaret edilen ekranlar kurulur; 18- topluluk yok | Idle polling tamamen kaldırılmadı |

## 7. Performans: ölçüm ve sınır

- Grup arama: önce 4 HTTP isteği, şimdi 1; widget çağrı sayacıyla doğrulandı.
- Görev değerlendirme: N ayrı progress okuması yerine bir toplu okuma; ilgili
  görev yoksa sıfır progress sorgusu. Bu, uygulama genelinde yüzde hız iddiası değildir.
- Harita: eski 500 noktalık liste yerine varsayılan 100 kayıt; `total/hasMore`
  bilgisi; şehir seçilince adaylar SQL `id in` ile daralır. Backend'de 4037
  entity ve EAGER koleksiyon yerine küçük projection kullanılır.
- Konum envanteri 60 saniye saklanır; cache tüm geçmiş istekleri biriktirmez.
- Kamera istekleri 450 ms debounce, HTTP iptali ve eski yanıt korumasına sahiptir.
  Mesafe hesabı Flutter marker çizimi içinde yapılmaz.
- Mobil görsel sıkıştırma worker'a taşınmış halde korunur; Web worker iddiası yoktur.
- Nunito dış font isteği kaldırıldı; asset 276 KB civarında olup tam boyut
  repodaki dosyadan görülebilir. Font için ağ bekleme/failure yolu ortadan kalkar.
- Yerel örneklerde eski genel 500 nokta yanıtı median 283,26 ms / 197.757 byte;
  Kayseri sorgusu 37,28 ms / 11.391 byte. Farkın önemli kısmı bilinçli kapsam
  daralmasıdır; aynı işin 7,6 kat hızlandığı şeklinde yorumlanmamalıdır.
- Yerel HTTP median/payload karşılaştırmaları `final-runtime-verification.json`
  dosyasındadır. Eski genel arama ile yeni şehir sorgusu farklı kapsamdadır;
  bunlar üretim p95, Android FPS veya aynı kapsamlı bir load test değildir.

## 8. Bellek, status 137 ve timer

137, SIGKILL ile uyumludur; tek başına OOM kanıtı değildir. Üretim Render cgroup
olayları bu tur erişilebilir değildi. Kasıtlı durdurulan yerel test konteynerinin
137 çıkışı da üretim bellek hatası olarak yorumlanmadı.

`GET /api/health` yalnız sabit metin döndürür: DB/model/tüm kayıt okuması yoktur.
15 dakikalık dış pingin kendi başına kapanmaya neden olduğuna dair kanıt yok.
İstemcide bildirim/community sayacı 15 saniyede sorgulanır; foreground ve
in-flight korumaları vardır. Grup polling fallback'i çakışmayı engeller; bağlantı
varken STOMP kullanılır. Backend harita HTTP isteği seed başlatmaz.

ONNX yalnız `ML_ENABLED=true` olursa yüklenir; varsayılan Gemini'dir. Tek analiz
izni, iki intra-op işçisi, kapalı CPU arena/memory-pattern ayarları korunur.
512 MiB konteyner ölçümü, tek kullanıcılı yerel testtir. Önceki turda sınıra
yakın peak/max olayları görüldü; OOM kill yoktu. Bu ortam güvenli kapasite
sertifikası değildir. 512 MB Render için `AI_PROVIDER=gemini`, `ML_ENABLED=false`
önerilir; yerel model için daha yüksek bütçe ve eşzamanlı yük testi gerekir.
Kullanıcının üretim provider ayarı sessizce değiştirilmedi.

Bu turun Java 17 prod/ONNX/512 MiB koşusunda peak **504.090.624 byte**
(yaklaşık 480,7 MiB), `max=0`, `oom=0`, `oom_kill=0` ölçüldü. Startup 104,598
saniyeydi; aynı sırada yerel Windows RAM baskısı vardı, Render startup süresi
diye sunulmaz. Bu tek koşu, önceki sınıra yakın ölçümü geçersiz kılmaz.

## 9. Java / Gradle / SDK

Flutter 3.35.7, Dart 3.9.2, Gradle 8.12, Kotlin 2.1.0, AGP 8.10.1, compile/target
SDK 36. AGP önceki turda API 36 desteği için 8.9.1'den 8.10.1'e alındı;
toplu bağımlılık yükseltmesi yapılmadı.

[Gradle resmî tablosu](https://docs.gradle.org/current/userguide/compatibility.html):
Java 17 >= Gradle 7.3, Java 21 >= 8.5, Java 25 >= 9.1. Dolayısıyla 8.12 için
Java 25 kullanılamaz. [AGP 8.10](https://developer.android.com/build/releases/agp-8-10-0-release-notes)
JDK 17, Gradle 8.11.1+ ve API 36 destekler. Kurulu JBR 21 de Gradle bakımından
uyumludur. Backend ana/test sınıfları major 61 (Java 17) üretir; prod Java 17'de
çalıştırılır. Android Java/Kotlin kaynak hedefi 11 bırakıldı: build JVM'iyle
bytecode hedefi farklı kavramlardır.

JDK 17 Windows paketi resmî Adoptium kaynağından indirilmeye çalışıldı, ağ
sınırında tamamlanamadı; bozuk/yarım paket çalıştırılmadı. Android doğrulaması
kurulu JBR 21 ile yapılır. Script açık `-JavaHome` ile JDK 17'yi de kabul eder.

Unicode Windows yolu native shader çıktısını bozabildiğinden build script'i
ASCII geçici kaynak kopyası kullanır; sırlar/keystore ve cache taşınmaz. Önceki
turda eksik `sky_engine/lib/async` aynı engine'in resmî paketiyle onarıldı;
SDK yükseltilmedi. `flutter doctor` Unicode PATH raporlama hatası hâlâ araç
kurulumuna özgü açık konudur; analiz/web/APK sonuçları ayrı doğrulanır.

Bazı üçüncü taraf Android eklentilerinin `source/target 8 is obsolete` uyarıları
ve `flutter pub get` sırasında sekiz paketin daha yeni uyumsuz sürümü olduğu
bilgisi devam eder. Bunlar derleme başarısızlığı değildir. Uyarıyı susturmak için
eklenti kaynak hedefleri topluca değiştirilmedi; sürüm yükseltmeleri ayrı
uyumluluk regresyonuyla ele alınmalıdır.

## 10. Testler ve gerçek doğrulama

Son tamamlanan sonuç: **114 backend, 124 Flutter, 11 Python veri testi**;
Flutter analizinde **0 sorun** (son koşu 50,8 sn); son web derlemesi **56,6 sn**.
Chrome'da gerçek giriş/Atla/şehir haritası
akışı geçti. Gerçek STOMP metin/typing ve HTTP etkinlik/anket işlemleri geçti.
Tamamen tekrar denenmeyen eski tarayıcı akışlarının önceki kanıtları ayrı
raporlarda tarihsel olarak korunur; bu turun sonucu diye yeniden sayılmaz.

Güncel ARM64 debug APK başarıyla üretildi: Gradle **217,3 sn**, **94.703.672 byte**.
Dosya: `frontend/build/app/outputs/flutter-apk/app-debug.apk`.
SHA256: `e9ee0f41ef57f95af43e63e97a9c2e65952e3335e926543bdc540e318d30a25f`.
Telefona kurulmadı. Bu APK canlı yeni backend dağıtılmış anlamına gelmez.

Release denemesi **geçmedi**: 81,3 sn sonunda çevrimdışı Gradle önbelleğinde
`io.flutter:arm64_v8a_release:1.0.0-d3d45dcf251823c1769909cd43698d126db38deb`
bulunmadığı için durdu. Bu Java/classfile veya uygulama kaynak hatası değildir;
normal ağ erişimiyle `scripts/build_android.ps1 -Mode release` (`-Offline`
olmadan) yeniden denenmeli. Release doğrulandı ya da mağaza imzası tamamlandı
diye raporlanmadı.
Çıktı klasöründe önceki çalışmalardan kalmış bir `app-release.apk` bulunması,
bu turun release derlemesinin başarılı olduğu anlamına gelmez; eski dosya silinmedi.

Güncel komutlar/sayılar/artefaktlar `final-audit-verification.json` dosyasına
kaydedilir. Önceki 107/116/7 başlangıç referansı olarak korundu; yeni sonuçlar
eski raporların geçtiğini varsayarak yazılmadı.

- Backend: temiz paket, gerçek PostgreSQL 15 entegrasyonu ve Java 17/Linux test
  koşusu. Test ajanı yalnız Mockito için yüklenir, uygulama runtime'ına eklenmez.
- Flutter: `flutter test --concurrency=1 --reporter=expanded`.
- Statik analiz: `flutter analyze --no-pub`.
- Veri: `python scripts/test_locations_and_doa.py` ve
  `python scripts/audit_locations_and_doa.py`.
- Yerel DB: `python scripts/verify_doa_counts.py`; read-only, Neon seçeneği kullanılmadı.
- HTTP/STOMP: `.venv-ml\Scripts\python.exe scripts/final_audit_runtime.py`.
- Web: `flutter build web --no-pub --no-wasm-dry-run --dart-define=API_BASE_URL=http://127.0.0.1:18081`.
- Chrome: `scripts/browser_smoke.py` yerel build ile temel akışlar; ekran
  görüntüleri `docs/screenshots/` altında. Fiziksel telefon testi değildir.
- Android: `powershell -File scripts/build_android.ps1 -Offline`; isteğe bağlı
  `-Mode release`. Mevcut release debug anahtarıyla imzalanır, mağaza yayınına uygun değildir.

## 11. Yerel / canlı farkları ve dağıtım

Yerel test DB: yalnız `ecovision_test`; test URL'si explicit allowlist ile
loopback'te 25439/5432 portlarına sınırlandırılır. Canlı Neon/Render için bu
sonuçlar doğrudan başarı kanıtı değildir. Yeni il seçicisi sunucunun
`/api/map-pins/locations` ve `/search` endpoint'lerini gerektirir. Eski `/nearby`
ve `/nearest` imzaları korunur; yeni istemci, eski sunucuda genel aramada 404
alırsa `/nearby` yoluna dönebilir. İl araması için sunucu güncellenmelidir.

Render'da prod profil, environment datasource/JWT/Gemini ayarları ve migration
doğrulaması korunmalı. Snapshot seed hash'i değişmediyse yeniden yazılmaz.
API anahtarları/gerçek kullanıcı verileri rapora veya log çıktısına eklenmedi.
GitHub/Render dağıtımı kullanıcı onayına bırakıldı.

## 12. Açık riskler / tamamlanmayanlar

1. Canlı Gemini hesabının kota/billing/anahtar erişimi ve Render performansı bu
   yerel turda çağrılmadı. Yapılandırılan `gemini-3.6-flash`,
   [resmî dokümana](https://ai.google.dev/gemini-api/docs/models/gemini-3.6-flash)
   göre görsel giriş destekler; modelin varlığı hesaba erişim garantisi değildir.
   Fotoğraf tekrarı SHA256 ile aynı dosya baytları içindir; yeniden kodlanmış veya
   fiziksel olarak yeniden çekilmiş aynı nesneyi kusursuz ayıran bir anti-fraud sistemi değildir.
2. Tek-instance in-memory STOMP broker iki backend replikasında mesaj tutarlılığı
   sağlamaz. Broker relay ve bağlantı yönlendirme/yük testleri gerekir.
3. Üyelikten çıkarılan kullanıcının önceden açık WebSocket aboneliğini anında
   kapatma; uzun bağlantıda token/ban iptali ayrıca sertleştirilmelidir.
   HTTP/medya ve yeni abonelik üyelik kontrolleriyle bunun aynı şey olduğu iddia edilmez.
4. Eski geçmiş/liderlik/katalog göçü ve toplu bildirim akışlarında büyüyen veriyle
   tam liste okuma yolları kalır. Kullanıcı ölçeğinde sayfalama/batch taşınmalıdır.
5. 512 MiB ONNX kapasitesi güvenli ilan edilmedi; gerçek eşzamanlılık/load testi yok.
   Windows/JBR21'de görülen ONNX DLL başlatma hatası bu tur Windows üzerinde
   çözülmüş sayılmadı; gerçek ONNX testleri Java17/Linux'ta geçti. Windows'ta
   yerel model geliştirmek için JDK17/native runtime kurulumu ayrıca doğrulanmalı.
6. Şehir ilçe tam, mahalle kataloğu ulusal olarak doğrulanmış değil. Şüpheli
   kaynak adresleri veri sağlayıcısı teyidi olmadan düzeltilmedi.
7. Fiziksel Android/iOS kamera/GPS/izin/arka plan pil testi ve mağaza imzası bu
   masaüstü doğrulamasıyla tamamlanmış sayılmaz.
8. Parola kurtarma e-posta teslimi, gerçek ödül/kupon/karbon kredisi ve işletim
   sistemi push entegrasyonu tamamlanmış özellikler değildir.

## 13. Öncelikli sonraki adımlar

1. Yerel doğrulanan backend'i kontrollü staging'e dağıt; gerçek Gemini anahtarı
   ile tek fotoğraf, timeout ve kota durumlarını izle; ardından APK saha testi.
2. Gerçek telefonlarda harita/kamera/sohbet senaryolarını ağ kesintisi ve küçük
   ekran/büyük yazı altında yürüt; p95, FPS ve pil ölç.
3. WebSocket üyelik/oturum iptali ve broker relay'i yük testiyle tamamla.
4. DOA kaynağıyla 3 belirsiz il ve 6 ilçe adresini teyit et; snapshot güncellemeyi
   kaynak sürümü/hash'li kontrollü import olarak işlet.
5. Leaderboard/geçmiş/broadcast/startup backfill'lerini bounded DB batch'e taşı;
   örneklem trafikle CPU/heap/native/DB plan ölçümlerini birlikte izle.
