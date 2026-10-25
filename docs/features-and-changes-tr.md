# EcoVision: uygulama rehberi ve eski-yeni karşılaştırması

Bu belge 24 Ekim 2026 tarihindeki kod incelemesine ve bu çalışma sırasında uygulanan değişikliklere dayanır. Kodda bulunmak, canlı Render servisinde veya telefondaki eski APK'da yayınlanmış olmak anlamına gelmez. Test ve dağıtım durumu `verification.md` dosyasında ayrıca tutulur.

25 Ekim güncellemesi ve canlı doğrulama sınırları:
[final teslim kaydı](final-delivery-2026-10-25-tr.md).

## Ürün ne işe yarıyor?

Son arayüz/il-ilçe/hız denetimi: [ui-review-and-performance-tr.md](ui-review-and-performance-tr.md).
81 ilin DOA makine ve merkez sayıları: [doa-city-counts-tr.md](doa-city-counts-tr.md).

Son güvenlik turu: [önce/sonra tablosu](old-vs-new-final-tr.md),
[yetki ve test raporu](final-security-and-tests-tr.md),
[dağıtım hazırlığı](deployment-readiness-tr.md).

Son Climathon incelemesi, öncelikli mantık/gizlilik bulguları, AI ve optimizasyon
önerileri: [climathon-readiness-tr.md](climathon-readiness-tr.md).

EcoVision, bir atığı fotoğraftan tanımaya, doğru ayrıştırma yolunu öğrenmeye ve uygun içecek ambalajı için ilgili DOA iade noktasını bulmaya yardımcı olur. Görevler, akademi, avatarlar ve topluluk bu davranışın devam etmesini destekler. Ambalajın resmî iadesi ve depozito ödemesi DOA'nın kendi sisteminde gerçekleşir.

Güncel temel yol: **Fotoğraf → malzeme tahmini → DOA makinelerini göster → harici harita uygulamasında yol tarifi.**

Son kapsamlı yerel denetim ve açık kalan riskler:
[ecovision-final-audit-tr.md](ecovision-final-audit-tr.md). Backend il/ilçe
envanterini ve sayfalamayı destekler; son kullanıcı tercihiyle haritadaki il/ilçe
seçimi ve “Bu alanda ara” düğmesi kaldırıldı. Kamera hareketi otomatik sorgulanır. Aynı fotoğraf dosyası
aynı kullanıcıya başka gün de tekrar ödül vermez; bu kontrol resmî iade kanıtı değildir.

### Son arayüz düzenlemesi

Rehber artık Türkçe karakter toleranslı arama ve tamamlanma filtreleri içerir.
10 modül ve 30 soru korunurken teslim yolu, uygun/uygun olmayan örnekler,
hazırlık, güvenlik, sık hatalar, yeniden kullanım ve açılabilir kaynaklar
eklendi. Sonuç sayfasındaki yeni rehber bağlantısı tanınan kategoriye gider;
AI özeti provider/model sürümünü ve tahminin sınırlarını açıklar.

Kullanıcının sonraki tercihiyle tarama sonucu yeniden sadeleştirildi: ambalaj soru formu ve “Gerçekleştirdiğim Eylemi Kaydet” düğmesi kaldırıldı. Sonuçtan doğrudan **DOA Makinelerini Haritada Göster** düğmesiyle haritaya geçilir. PET/cam/alüminyum açıkça tanındıysa ilgili malzeme filtresi uygulanır; genel plastik/metal gibi belirsiz sınıfta harita malzeme filtresi olmadan açılır. Düğme ön konum/API sorgusuna bağlı gizlenmez. Makineye yönlendirme, resmî depozito kabulü anlamına gelmez.

Eco Merkezi'ndeki karbon girişi **20 soruluk ankete** açılır. Her sorunun altında isteğe bağlı sayısal girdi vardır; ayrıca bir “detaylı hesaplama” açılması gerekmez. Örneğin haftalık araç mesafesi doğrudan 250 km girilebilir. Boş alanlar eski yanıt ağırlıklarını aynen korur. Veri girilirse ilgili yaklaşık ağırlığın yerine geçer, aynı kullanım ikinci kez toplanmaz. Ulaşım/ısınma yöntemi gibi nitel seçimler yine gereklidir. Sonuç yaklaşık anket hesabıdır; eğitilmiş karbon makine öğrenmesi modeli değildir. Backend uygunluk/eylem endpoint'leri ve eski kayıtlar silinmedi.

## Eski sürümden ne değişti?

| Konu | Önce | Bu çalışmadaki davranış |
|---|---|---|
| DOA veri kaynağı | Eski 130 kayıt ve 14 Şanlıurfa kaydı; seed toplamı 144'e sabitlenmişti | Manifestiyle birlikte 4.037 noktalık tam ham snapshot okunuyor |
| Nokta türleri | Her şey makine gibi gösteriliyordu | DIM, MIN, KIM, SDM ve UNKNOWN ayrı saklanıyor; varsayılan harita DIM, merkezler isteğe bağlı |
| Kimlik ve eşleştirme | Ad veya yalnız koordinat üzerinden güncelleme | Önce DOA UUID; eski kayıtlar yalnız tekil ad+adres+koordinat eşleşmesiyle bağlanıyor |
| Tekrarlanan seed | Açılışta ve bazı harita isteklerinde tekrar yazılabiliyordu | Başlangıçta dry-run; dosya hash'i değişmemişse yazma atlanıyor; HTTP harita isteği seed başlatmıyor |
| Ham veri | Kaynak kimliği, zamanlar, program ve durum alanları kayboluyordu | Kaynak kodları, binList, ham durumlar, snapshot/import zamanları ve kalite etiketleri korunuyor |
| Malzeme ve durum | Destek ve o andaki hazne durumu tek anlama indirgenmişti | Teknik destek, kaynak hazne bildirimi ve bilinmeyen telemetri zamanı ayrı tutuluyor |
| Çalışma saatleri | Kaynak programı işlenmiyordu | İstanbul saatinde açık/kapalı/bilinmiyor hesabı; gece yarısı ve önceki günden taşan aralıklar destekleniyor |
| Harita performansı | Tüm entity ve koleksiyonlar alınabiliyordu | Küçük projection/DTO, koordinat ön filtresi, sonuç sınırı, viewport sorgusu, 450 ms debounce, eski yanıt koruması ve marker gruplama |
| Depozito uygunluğu | PET/alüminyum etiketi doğrudan uygunluk sayılıyordu; cam dışlanıyordu | Malzeme tahmini kabul garantisi değildir; sonuçtan doğrudan harita açılır. Ayrı uygunluk API'si korunur, görünür ambalaj soru formu yoktur |
| Genel metal | Bazı eşlemelerde otomatik alüminyum sayılıyordu | Yeni harita ve uygunluk akışı genel metali alüminyum kabul etmiyor |
| AI kotası | Bir hata farklı modellere ve yeniden denemelere yayılabiliyordu | Yapılandırılan tek Gemini modeli kullanılıyor; otomatik farklı model zinciri kaldırıldı |
| AI sonucu | Model skoru kesin güven izlenimi verebiliyordu | Skorun kalibre doğruluk olmadığı belirtiliyor; belirsiz/çoklu nesne için tekrar fotoğraf yolu gösteriliyor; önbellek sonucu etiketleniyor |
| Yerel görsel model | Yalnız Gemini bulut analizi vardı | Gerçek TrashNet fotoğraflarıyla eğitilmiş MobileNetV2 özellikleri + sınıflandırma başlığı, Java ONNX CPU adaptörü ve ölçüm dosyaları eklendi; etkinleştirmek için sunucu ayarı gerekiyor |
| Görev kataloğu | 100 görev | Mevcut 100 görev + 100 ayrı alışkanlık eylemi; kararlı kodlar ve eski ilerleme korunuyor |
| Görev ödülü | Eşzamanlı claim yanıtları yanıltıcı ödül bilgisi verebiliyordu | Kullanıcı kilidi claim yanıtının hesabını da kapsıyor; mevcut DB kilitli ödül akışı korunuyor |
| Giriş serisi | Tarama serisi görünürken giriş geçmişi sınırlıydı | Giriş ve tarama serisi ayrı; güncel/en uzun giriş serisi ve son yedi gün saklanıyor |
| Karbon | 20 soruluk sabit ağırlık anketi; profilde puan×katsayı tasarrufları | 20 soruda hızlı yanıt veya doğrudan sayısal girdi; çakışan tahminler toplanmaz; puanlardan tasarruf türetilmez |
| Atık etkisi | Tarama ile geri dönüşüm birbirine karışabiliyordu | Tartılmış kütle ve yönetim yoluyla, ayrı kullanıcı beyanı kayıtları; tekrarlanan aynı kayıt anahtarı ikinci kayıt oluşturmuyor |
| Admin erişimi | Kodda bilinen başlangıç parolası vardı | Yeni kurulumda rastgele hash; mevcut admin için gizli parola istemli yerel sıfırlama aracı ve oturum iptali |
| Tanıtım | Son sayfaya kadar ilerleme gerekiyordu | Hesaba bağlı tanıtıma Atla düğmesi eklendi |

## Sayfalar ve özellikler

### 1. Açılış, kayıt ve giriş

- `main.dart` başlangıçta saklanan oturumu denetler. Splash bu kontrol sürerken gösterilir; geçerli oturum varsa ana akışa geçilir.
- Kayıt; ad, soyad, kullanıcı adı, e-posta, parola, doğum tarihi, il/ilçe ve zorunlu sözleşme kabullerini toplar. Backend 13 yaş altını reddeder.
- Parola BCrypt ile hashlenir. E-posta/parola girişi access JWT ve döndürülen refresh token ile çalışır. Mobil token saklama `flutter_secure_storage` üzerinden yapılır.
- Beş başarısız girişten sonra geçici hesap kilidi uygulanır. HTTP hataları standart JSON yanıtına çevrilir; HTML hata sayfası Flutter JSON çökmesine dönüştürülmez.
- Parolamı unuttum akışının mevcut endpoint'i yalnız genel kabul yanıtı üretir. E-posta gönderimi/tamamlanmış parola kurtarma sistemi olarak sunulmamalıdır.
- Flutter'da Google giriş düğmesi yoktur; backend'de eski Google doğrulama yolu hâlâ bulunmaktadır.

### 2. Hesaba bağlı tanıtım

Başarılı giriş/kayıttan sonra `hasSeenOnboarding_<userId>` yerel tercihi kontrol edilir. Dünya rehberi; tarama, puan, görev ve topluluk akışını dört sayfada anlatır. Hemen Başla veya Atla tercihi kaydeder. Bu tercih cihazdaki uygulama verisiyle saklanır; uygulama verileri silinince tekrar gösterilebilir.

### 3. Ana sayfa / Tarama

Fotoğraf Çek veya Galeriden Seç ile `image_picker` görseli alınır. Fotoğraf backend'e multipart olarak gönderilir. Backend seçilen görsel analiz sağlayıcısını çağırır; malzeme adayları döner. Başarılı sınıflandırma ScanHistory'ye bağlanır ve puan miktarını sunucunun WasteMaterial tablosu belirler. Tarama kaydı, resmî geri dönüşüm belgesi değildir.

Ana sayfadaki Eco Merkezi altı giriş içerir: Görevlerim, Eco-Market, Avatar Yolu, Atık Rehberi/Eko-Akademi, Liderlik ve Karbon Ayak İzi.

### 4. Tarama sonucu ve haritaya geçiş

Sonuçta malzeme, model skoru, doğada kalıcılık rehberi, olası geri kazanım yolu ve verilen uygulama puanı görünür. Kalıcılık metinleri genel eğitim bilgisidir; fotoğraftaki nesnenin ölçülmüş ömrü değildir.

DOA haritası düğmesi doğrudan görünür. Tanımlı PET, cam ve alüminyumda ilgili noktalar; diğer malzemelerde genel DOA haritası açılır. Ambalaj kontrol formu ve eylem kaydı bu ekrandan kaldırılmıştır. Barkod/DBYS doğrulaması yapılmaz; genel haritayı açmak o atığın kabul edileceği iddiası değildir.

### 5. DOA haritası

Harita `flutter_map`, OpenStreetMap karo katmanı ve `latlong2` kullanır; Google Maps API anahtarı gerekmez. Konum `geolocator` ile alınır. Yakındaki noktalar GPS konumuna göre aranır; haritayı sürüklemek arama merkezini değiştirmez. Yenile GPS'i yeniden alır. Konum yoksa açık uyarı gösterilir; son bilinen gerçek konum varsa korunur.

- Varsayılan tür DIM yani İade Makinesi'dir. MIN/KIM merkezleri ayrı filtreyle açılır; SDM tüketici makinesi gibi varsayılan önerilmez.
- PET, cam ve alüminyum seçimleri OR mantığındadır: seçilen malzemelerden herhangi birini destekleyen nokta eşleşir.
- Arama yarıçapı 1–50 km'dir; sınırsız seçeneği final mobil düzeltmesinde kaldırıldı. Harita yakınlaştırması 3–18, bellekteki nokta sayısı en fazla 300'dür. Noktalar 100'lük sayfalarla gelir; Sonraki/Önceki noktalar ile diğer sonuçlara erişilir. Kamera hareketinde API isteği veya mesafe hesabı yapılmaz. Kaynak kayıtlar silinmedi. [Güncel GPS ve geri dönüşüm notları](gps-recycling-update-tr.md).
- Açık noktalar filtresi yalnız programı bilinen açık noktaları getirir. Bilinmeyen saat, kapalı veya 24 saat açık olarak yorumlanmaz.
- Noktaya dokununca ad, tür, adres, desteklenen malzemeler, kaynak tarihi, program durumu ve ayrıntılar açılır.
- Uzaklık Haversine ile kuş uçuşudur. Yol Tarifi, Google Maps/Apple Maps/Yandex gibi desteklenen harici uygulamaya gerçek hedef koordinatını gönderir.
- Veriler 24 Ekim 2026 tarihli snapshot'tır; makinenin o an çalıştığına ilişkin canlı garanti verilmez.

### 6. Görevlerim

Görevler kategoriye göre listelenir; ilerleme, hedef ve sunucunun belirlediği Eko Puan görünür. Tarama ve uygulama olayına bağlı görevler olay tabanlı değerlendirilir. Alışkanlık görevlerinde Tamamladım/Beyan et eylemi kullanılır; bunlar fotoğrafla doğrulanmış sayılmaz.

Yeni 100 görev; atık önleme, yeniden kullanım, onarım, gıda, DOA ambalajları, doğru ayrıştırma, paylaşım ve ölçüm/öğrenme alanlarını kapsar. Aynı başlığın yalnız sayısı değiştirilmiş kopyaları kullanılmadı. Güvensiz pil sökme veya kırık cam toplama talimatları yoktur.

Tamamlanan görevin ödülü ayrıca talep edilir. Kullanıcı/ilerleme kilitleri ikinci ödülü engeller. Günlük görevler İstanbul gece yarısında arşivlenip aktif kullanıcılara atanır. Bazı eski görevlerin tetikleyicisi yalnız ilgili olay yayınlanırsa ilerler; bütün eski görevlerin sahada gözlenmiş olduğu iddia edilmez.

### 7. Eko-Akademi

İçerik `assets/data/academy_guide.json` dosyasından yüklenir. Bir modül seçilince ders ve üç soruluk quiz açılır. İstemci üç cevap indeksini ve sürümü gönderir; sunucu kendi sürümlü kataloğuyla en az iki doğruyu doğrulamadan ödül vermez. Kullanıcı kilidi/idempotent işlem modül puanını tek seferle sınırlar. Cevapsız eski istemci 426 güncelleme yanıtı alır. Statik istemci cevap anahtarı geri bildirim içindir; kötü niyetli istemciye karşı insanın gerçekten öğrendiğinin kanıtı değildir.

### 8. Karbon ve eylem kayıtları

Eco Merkezi 20 soruluk anketi açar. Her sorunun altında mesafe, sıklık, yüzde veya tüketim için isteğe bağlı bir sayı alanı vardır. Elektrik aylık kWh ve hane kişi sayısıyla girilir. Aralık seçeneğine dokunmak ilgili sayısal girdiyi temizler; aynı sorunun iki cevabı birlikte sayılmaz.

Elektrik için Türkiye ETKB 2023 dağıtım şebekesi katsayısı kullanılır. Araç km hesabı benzin için EPA yanma CO₂ katsayısı ve açıkça belirtilen 7 L/100 km varsayımına dayanır; araç türüne özel saha ölçümü değildir. Diğer sayısal alanlar eski anketin yaklaşık ağırlıklarından türetilen eğrilerdir. Elektrik ve araç verileri çakışan ilgili tahminleri değiştirir. Bu deterministik hesap eğitilmiş ML modeli, tam karbon envanteri veya karbon kredisi değildir. Eski kısa tüketim ekranı/API'si korunur, ana giriş onu açmaz.

Atık eylemleri ayrı tutulur. Kütle ve uygulanan yönetim yolu kullanıcı tarafından beyan edilir; EPA WARM v13 ABD senaryosu ile fark hesaplanır. PET, cam ve alüminyum kutu dışındaki malzemelerde sonuç hesaplanamayabilir. Bu bir Türkiye saha ölçümü veya karbon kredisi değildir. Eylemin gramajı düzeltilince fark yeniden hesaplanır; silinince toplam sorgudan güncellendiği için tutarlı kalır.

### 9. Eco-Market

Kullanıcı kazandığı uygulama puanını avatar/çerçeve gibi sanal ürünlerde ve seri dondurucuda harcar. Backend satın alma sırasında bakiyeyi ve sahipliği kontrol eder, kilit altında puan düşer ve sahip olunan ürünü saklar. Arayüzdeki ürünlerle backend kataloğu birlikte çalışır. Gerçek ağaç dikimi, kahve kuponu veya kurumsal ödeme entegrasyonu mevcutmuş gibi sunulmamalıdır.

### 10. Avatar yolu ve avatar seçimi

20 kademeli avatar ilerlemesi ömür boyu kazanılan puanla hesaplanır. Harcanabilir puanla seviye aynı şey değildir. Kullanıcı açtığı seviyeler arasından avatar seçebilir. Seçim backend'de saklanır. Kullanıcı özellikle avatar seçerse özel fotoğraf tercihi bırakılır; özel fotoğraf yüklerse bu tercih öne geçer.

### 11. Liderlik

Genel ve Arkadaşlarım listeleri backend'deki puan sırasına dayanır. Genel liste varsayılan olarak tüm şehirlerdeki kullanıcıları kapsar; 81 ilden biri seçilerek filtrelenebilir. Sonuçlar 50'lik sayfalarda gelir, Diğer kullanıcılar düğmesi sonraki sayfayı yükler. Arkadaş listesi yalnız kabul edilmiş ilişkileri ve kişinin kendisini içerir. Kendi satırı vurgulanır; profil açma yolu gizlilik kurallarını izler. Bu değişikliğin canlıya alınması ve APK doğrulaması [güncelleme notlarında](leaderboard-carbon-update-tr.md) ayrı tutulur.

### 12. Topluluk keşfi ve arkadaşlar

Topluluk 18 yaş ve üstüne açıktır. Gruplar ad ve konumla keşfedilir. Kullanıcı araması en az üç karakterlik kısmi eşleşmeleri destekler. Profilden arkadaşlık isteği gönderilebilir, kabul/reddetme, arkadaşlıktan çıkarma ve beğenme işlemleri yapılabilir. İki kişi arasında özel mesajlaşma yoktur.

Şifresiz gruba doğrudan katılınır. Şifreli grupta doğru şifre gerekir; uygulamadaki mevcut son akış onaysız katılımı esas alır. Davet koduyla ilgili gruba ulaşılır. Eski onay endpoint'leri geriye uyumluluk için bulunabilir; görünür akışla aynı şey olduğu varsayılmamalıdır.

### 13. Grup sohbeti ve grup bilgisi

Grup kartı etkileşimli sohbete açılır. STOMP/WebSocket metin, etkinlik, tepki, anket ve yazıyor bildirimlerini taşır. HTTP geçmiş sorguları sayfalıdır. Fotoğraflar sıkıştırılır; belgeler/PDF güvenli yükleme yoluyla gönderilir. Mesajı yanıtlama, sabitleme, emoji tepkisi, anket oyu ve medya listesi mevcut servislerle çalışır.

Avatarı seçmek kişinin profilini açar. Grup bilgisi; kapak fotoğrafı, açıklama, üyeler, paylaşılan medya ve etkinlikleri toplar. Kurucu ve yönetici yetkileri sunucuda kontrol edilir. Kurucu başka yönetici atayabilir; kurucu üyelikten çıkarılamaz. Normal üye diğer üyeleri görür ve profillerini açabilir.

### 14. Grup içi etkinlikler

Etkinlik bağımsız topluluk yerine bir grubun altında oluşturulur. Yetkili kişi başlık, açıklama, tarih/saat, konum, kontenjan ve kapak fotoğrafı ekler. Sohbette etkinlik kartı görünür; üyeler Katıl/Ayrıl seçer. Kontenjan ve katılımcı bilgisi backend'den gelir. Silme ve üye yönetimi izinleri sunucuda doğrulanır.

### 15. Profil ve gizlilik

Profil; avatar/uygun özel fotoğraf, kullanıcı adı, seviye, puan, şehir, rozetler, tarama serisi, giriş serisi ve tarama geçmişini gösterir. Özel fotoğraf yüklemek yalnız yetişkin kullanıcıya açıktır. Gizli profilde özel fotoğrafı yalnız sahibi ve kabul edilmiş arkadaşları görebilir; diğer ziyaretçilere avatar gösterilir.

Kimlik başlığı mobilde tek hizadadır: avatar ve düzenleme simgesi, isim/kullanıcı adı, konum, Eko Puan ve avatar seviyesi. Ayrı giriş serisi kartı kaldırılmıştır. Başlıktaki “N gün giriş serisi” alanına dokununca aylık takvim açılır; yalnız kişinin kendi hesabına ait kaydedilmiş günler işaretlenir. Önceki aylara geçilebilir, gelecek ay kapalıdır. Takvim sorgusu yeni giriş veya ödül oluşturmaz. Backend henüz güncellenmemişse yalnız mevcut son yedi gün gösterilir ve bu sınır açıkça belirtilir.

Uygulama puanı, geri dönüştürülmüş kilogram veya doğrulanmış karbon tasarrufu değildir. Günlük giriş serisi de fiziksel geri dönüşüm serisinden ayrıdır.

Profilde ayrıca **Toplam geri dönüşüm** kartı vardır: benzersiz ödüllendirilmiş ayrıştırma taramalarını ve ayrı bir CO₂e potansiyelini gösterir. PET/cam/alüminyum açıkça biliniyorsa tarama başına 25/200/15 g uygulama senaryosu ve mevcut EPA WARM katsayıları kullanılır; bunlar tartılmış gramajlar değildir. Genel plastik/metal veya katsayısı bilinmeyen malzemeler toplam tarama sayısında kalır, CO₂e'ye eklenmez. Eski görsel kimliği olmayan kayıtların tekrarları ayırt edilemez; bu sınır açıklanır. Ayrıntı düğmesi hesap varsayımlarını açar. Yıllık karbon anketi ve kullanıcı beyanı kayıtları bu potansiyelle birleştirilmez.

Fotoğraf gizliliği artık yalnız UI'da değil her medya GET'inde sunucuda
denetlenir. Flutter yetkili bytes yükler; çıkışta görsel önbelleği temizlenir.
Önceden indirilmiş/public-cache kopyalarını sunucu geri alamaz.

### 16. Ayarlar

Profildeki dişli; profil düzenleme, parola değişimi, gizlilik, özel fotoğraf, dil, tema ve çıkışı toplar. Forest/Ocean/Sunset/Dark Eco teması kullanıcıya göre yerelde ve backend'de saklanır. Çıkış tokenları temizleyip girişe yönlendirir. Dil seçimi şu an Türkçe; diğer diller çevirisi tamamlanmış özellikler değildir.

### 17. Bildirimler ve moderasyon

Zil simgesi okunmamış sayısını gösterir. Sosyal ve oyunlaştırma olayları uygulama içi bildirim oluşturabilir. Okunan kayıtlar backend'de işaretlenir. Cihaza işletim sistemi push servisi entegre edilmedikçe bu sistemin her bildirimi cihaz push'u sayılmaz.

SUPERUSER ayarlardan moderasyon paneline girer. Raporları inceleme, yetkili sohbet denetimi, uygulama içi genel duyuru, hesap askıya alma/yasaklama ve grup silme işlemleri bulunur. HTTP yetkisi yalnız arayüzde düğme gizlemeye bırakılmaz.

### 18. Kalıcılık ve altyapı

Flutter ekranları HTTP ApiService ve mevcut notifier/theme state akışıyla Spring Boot 3 modüler monolitine bağlanır. Controller → service → repository → PostgreSQL katmanları kullanılır. Gruplar, kullanıcılar, taramalar, medya, görevler, akademi, bildirimler ve yeni karbon kayıtları aynı ilişkisel veritabanındadır. Neon üretim PostgreSQL sağlayıcısıdır.

Docker/Render dağıtımı, Kubernetes manifestleri, GitHub Actions, Actuator/Micrometer, Prometheus, Grafana, Loki/Promtail, Alertmanager ve SonarQube konfigürasyonları depoda bulunur. Bunların her birinin canlıda etkin olması ayrı deployment ve erişim gerektirir; yalnız dosya bulunması canlı doğrulama değildir.

## Kapsamı açık kalan noktalar

- Canlı Gemini çağrısı için gerçek anahtar gerekir; `.env` içindeki örnek değer analiz yapamaz.
- Tam kişisel karbon envanteri için beslenme, ısınma ve diğer tüketimlerin kaynaklı katsayıları henüz eklenmelidir.
- DOA snapshot verisi canlı kabul/ödeme teyidi değildir.
- Mobilde yeni davranış için APK yeniden derlenmeli; backend değişiklikleri ayrıca dağıtılmalıdır.
- Yerel model gerçekten eğitildi: 395 ayrılmış test fotoğrafında macro-F1 0,788; 0,65 ret eşiğinde kabul edilen alt kümenin doğruluğu 0,914. Bu, Türkiye saha doğruluğu veya depozito uygunluğu başarısı değildir. Ayrıntı `ml/MODEL_CARD.md` ve `docs/verification.md` içinde.
