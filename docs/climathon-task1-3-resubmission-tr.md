# EcoVision - Görev 1, 2 ve 3 yeniden sunum metinleri

Hazırlık tarihi: 25 Ekim 2026. Bunlar forma aktarılacak taslak yanıtlardır;
formlar gönderilmiş değildir. Yeniden teslimin kabulünü organizasyon belirler.
Ad, e-posta, kişisel gözlem ve paylaşım bağlantılarını gerçek bilgilerinle tamamla.
Pilot rakamları önerilen hedeflerdir, gerçekleşmiş sonuçlar değildir.

## Her görevde kullanılacak yeniden sunum notu

Bu çalışma, daha önce sunduğum EcoVision projesinin geliştirilmiş ve güncellenmiş
sürümüdür. İlk problem odağını koruyarak çözümü, çalışan prototipi ve etki ölçüm
planını netleştirdim; bu form aracılığıyla yeniden sunuyorum.

Ayrı açıklama alanı yoksa bu notu Görev 1'de problem tanımının, Görev 2'de çözüm
tanımının, Görev 3'te temel fonksiyon yanıtının başına ekle.

## Görev 1 - Problem Definition

**Ad Soyad:** [Adın Soyadın]

**E-posta:** [Kayıtta kullandığın e-posta]

### Çözmek istediğin problemi 1-2 cümleyle tanımla

Özellikle üniversite öğrencileri ve yurt sakinleri için çevreyi koruma niyetini
günlük atık azaltma, yeniden kullanım ve doğru ayrıştırma davranışına dönüştürmek
zorlaşabiliyor. Ele aldığım temel problem, karar anında anlaşılır bilgiye,
uygulanabilir bir sonraki adıma ve davranışın sürekliliğini destekleyen araçlara
birlikte erişilememesi.

### Kimler etkileniyor? En fazla etkilenen grup kim?

Yanlış ayrıştırma ve gereksiz tüketim; bireyleri, atık toplama çalışanlarını,
belediyeleri ve doğal çevreyi etkiliyor. İlk hedef grubum üniversite öğrencileri
ve yurt sakinleri. Bu grup bir başlangıç segmenti önerisidir; en fazla etkilenen
grup olduğuna ilişkin karşılaştırmalı saha araştırmam henüz bulunmuyor.

### En güçlü veri, gözlem veya kaynak nedir?

OECD'nin Global Plastics Outlook raporuna göre 2019'da dünya genelinde oluşan
353 milyon ton plastik atığın yalnızca yüzde 9'u geri dönüştürüldü. Bu veri
problemin küresel ölçeğini gösterir; öğrencilerin bilgi eksikliğinin tek neden
olduğunu veya Türkiye'deki geri dönüşüm oranını kanıtlamaz.

Yerel pilot öncesinde henüz bir kampüs hata oranı ölçmedim. Ölçülebilir başlangıç
noktasını 20 katılımcıya uygulayacağım 10 soruluk ayrıştırma ön testi ve bir
atık için doğru sonraki adımı bulma süresiyle belirlemeyi planlıyorum. Aynı
ölçümleri iki haftalık kullanım sonunda karşılaştıracağım.

Kaynak: https://www.oecd.org/en/publications/global-plastics-outlook_de747aef-en/full-report/component-6.html

### Neden şimdi ve neden teknoloji?

Kaynakların kullanımda tutulması için yalnızca toplama altyapısı değil, doğru
günlük kararlar ve atık önleme alışkanlıkları da gerekiyor. Akıllı telefon
kamerası ve görsel yapay zekâ malzeme hakkında ilk tahmini üretebilir; eğitim
içeriği bu tahmini anlaşılır bilgiye, görevler ve topluluk ise tekrar edilebilir
davranışa bağlayabilir. Teknoloji fiziksel toplama altyapısının yerine geçmez.

### Bu problem senin için neden önemli?

Teknik becerilerimi insanların günlük hayatında karşılığı olan bir çevre
problemine uygulamak istiyorum. Çevreyi koruma isteğinin yalnızca bilgi olarak
kalmaması, öğrenilebilir ve sürdürülebilir alışkanlıklara dönüşmesi benim için
önemli. EcoVision'ı bu nedenle geliştirmeye devam ediyorum.

Bu paragrafı yalnızca seni gerçekten yansıtıyorsa kullan. Varsa kendi yaşadığın
somut bir olayı, tarih veya sonuç uydurmadan bir cümleyle ekle.

### Eşleşmeler

- COP31 form seçeneği: **Cutting waste by half by 2035**.
- Siemens Impact Area: **Resource Efficiency & Circularity**.
- UN SDG: **12 - Responsible Consumption and Production**, özellikle **12.5**.
- SDG 13 ikincil ilişki olarak belirtilebilir; ölçülmüş emisyon azaltımı iddiası yok.

## Görev 2 - Project Design Review

**Ad Soyad / E-posta:** [Gerçek bilgilerin]

### Çözümünü 1-2 cümleyle anlat

EcoVision, bireylerin atıklarını tanımasına, doğru ayrıştırma ve yeniden kullanım
yollarını öğrenmesine ve sürdürülebilir alışkanlıklar geliştirmesine yardımcı olan
yapay zekâ destekli bir platformdur. Fotoğraf analizi, Eko-Akademi, görevler,
karbon farkındalığı ve topluluk araçlarını aynı deneyimde birleştirir.

### Problemin kök nedenine nasıl cevap veriyor?

Bilgi edinme ile harekete geçme arasındaki adımları birleştirir: kullanıcı
karşılaştığı atık üzerinden öğrenir, uygulanabilir yönlendirme alır ve davranışı
sürdürmesini destekleyen görev ve topluluk araçlarına ulaşır. Amaç yalnızca
atığı sınıflandırmak veya iade makinesi bulmak değil, bilinçli kararı kolaylaştırmaktır.

### Nasıl çalışıyor? Kullanıcı ve teknoloji ne yapıyor?

Kullanıcı bir atık fotoğrafı yükler; Spring Boot sunucusu görseli Gemini'ye
göndererek malzeme tahmini alır. Sonuç, ilgili atık rehberine ve uygun malzemeler
için DOA noktalarına bağlanır. Akademi sınavları öğrenmeyi, görevler ve avatarlar
devamlılığı destekler; yetişkin kullanıcılar gruplarda ortak etkinlikler düzenleyebilir.
Karbon anketi yaklaşık kişisel farkındalık sağlar; doğrulanmış karbon kredisi üretmez.

### En yakın alternatifler ve mevcut durum

Resmî DOA uygulaması, depozitolu ambalajların iadesi, iade noktaları ve dijital
cüzdan işlemleri için doğrudan alternatiftir. Genel çevre rehberleri ve ayrı
karbon hesaplayıcıları da ihtiyacın başka parçalarını karşılar. EcoVision resmî
DOA sistemi değildir, ödeme yapmaz ve resmî ambalaj kabulünü doğrulamaz.

Kaynak: https://doa.gov.tr/how-doa-works

### Nasıl ayrışıyor?

Görsel malzeme tahmini, kaynaklı ayrıştırma/yeniden kullanım rehberi, sınavla
öğrenme, oyunlaştırma ve topluluk katılımını tek akışa bağlar. DOA haritası bu
bütünün bir bileşenidir. Bu, bütün rakiplerden üstünlük veya ilk/tek ürün
iddiası değil, ürünün tasarım farkıdır.

### Program süresinde gerçekten prototiplenen bölüm

Flutter arayüzü ve Spring Boot/PostgreSQL backend'i geliştirildi. Temel gösterim
akışı gerçek fotoğraf yükleme, Gemini malzeme tahmini, rehbere geçiş ve DOA
haritasıdır. Akademi, görevler, profil/avatar ve topluluk modülleri kodda
uygulanmıştır; her birinin canlıda kusursuz çalıştığı, yalnızca kodda bulunmasına
dayanarak iddia edilmez. Sunum öncesi gösterilecek akış ayrıca denenmelidir.

### Mevcut duruma göre hedeflenen etki

İki haftalık 20 kişilik pilotta, 10 soruluk ayrıştırma testinin ortalama
başarısını başlangıca göre en az 20 yüzde puan artırmayı hedefliyorum.
Katılımcı başına beş doğru ayrıştırma/yeniden kullanım kararıyla toplam 100
eylem kaydı hedefleniyor. Bu kayıtlar kullanıcı beyanıdır; fiziksel geri
dönüşümün doğrulanmış kanıtı değildir. Başlangıç puanı ön testte ölçülecek;
bu hedefler henüz gerçekleşmiş etki olarak sunulmayacak.

### Dört kriter - önerilen öz değerlendirme

- **Greener: 3/5.** Çevresel zararı azaltabilecek kararları destekler; gerçek
  emisyon veya atık kütlesi etkisi henüz ölçülmedi.
- **Circular: 4/5.** Atık önleme, yeniden kullanım ve doğru ayrıştırma ürünün
  merkezindedir; fiilî geri kazanım toplama/işleme altyapısına da bağlıdır.
- **Financeable: 2/5.** Üniversite veya belediye kampanyalarına yönelik kurumsal
  kullanım bir hipotezdir; ödeme isteği, müşteri ve gelir doğrulanmadı.
- **Socially Impactful: 3/5.** Öğrenme ve topluluk katılımı potansiyeli vardır;
  kullanıcı araştırması ve pilot sonuçları henüz yoktur.

Puanları kendi değerlendirmenle onayla. PDR PDF'si için bu yanıtları problem,
çözüm, işleyiş, alternatif/fark, uygulanabilirlik ve ölçüm planı başlıklarıyla
tek sayfada özetle. Bu Markdown dosyası PDF yükleme alanına uygun bir PDF değildir.

## Görev 3 - Build & Show

**Ad Soyad / E-posta:** [Gerçek bilgilerin]

### Çalışan prototip bağlantısı

Ürün: [Dışarıdan erişilebilen frontend veya indirilebilir APK bağlantısı]

Ekran kaydı: [Gerçek kullanıcı etkileşimini gösteren liste dışı video bağlantısı]

localhost / 127.0.0.1 bağlantıları jüri bilgisayarında açılmaz. Backend sağlık,
Swagger ve GitHub kaynak kodu adresleri son kullanıcı arayüzünün yerine geçmez.
Ürün bağlantısı henüz yoksa formun izin verdiği ekran kaydı seçeneğini kullan.

### Gerçekten çalışan temel fonksiyon

EcoVision'ın geliştirilmiş prototipini yeniden sunuyorum. Kullanıcı gerçek bir
atık fotoğrafı yükleyebiliyor; görsel sunucu üzerinden Gemini ile analiz
edilerek malzeme tahmini döndürülüyor. Sonuç, ayrıştırma rehberine ve ilgili
DOA noktalarına yönlendirme sağlıyor. Öğrenme ve oyunlaştırma modülleri bu
çekirdek davranışın devamını destekliyor.

### Hangi araçlar ve neden?

- **Flutter/Dart:** Android ve web için ortak arayüz ve durum akışı.
- **Spring Boot 3 / Java 17:** Yetkilendirme, görsel yükleme, puanlama ve iş kuralları.
- **PostgreSQL / Neon:** Kullanıcı, görev, akademi ve topluluk ilerlemesinin kalıcılığı.
- **Gemini API:** Fotoğraftan gerçek görsel malzeme sınıflandırması; anahtar sunucuda.
- **flutter_map / OpenStreetMap ve tarihli DOA verisi:** Konum gösterimi ve nokta keşfi.
- **STOMP/WebSocket:** Grup sohbeti ve anlık etkileşimler.
- **Docker / Render / GitHub Actions:** Paketleme, dağıtım ve test otomasyonu.
- **Codex:** Kod geliştirme, hata inceleme ve test hazırlığında kullanılan yardımcı araç.

Google AI Studio Build mode kullanılmış bir proje olduğunu söyleme; depodaki
uygulama Flutter/Spring Boot'tur. AI Studio'yu gerçekten kullandıysan yalnızca
gerçek kullanımını ekle. Eğitimli yerel ONNX modelinin varlığı, telefonda
çevrimdışı çalıştığı veya production'da etkin olduğu anlamına gelmez.

### Gerçek çalışan ve örnek/eksik kısımlar

Gerçek fotoğraf yükleme, Gemini analizi, kullanıcı girişi ve harita API sorguları
canlı kabul denemesinde başarılı yanıt verdi. Bu test, kesintisiz çalışma veya
bütün cihaz/senaryolarda başarı garantisi değildir; son bildirilen aralıklı
analiz hatası nedeniyle kayıt öncesi yeni deneme yapılmalı.

Atık rehberi hazırlanmış eğitim içeriğidir; harita tarihli kayıtların
gösterimidir, canlı makine telemetrisi değildir. Karbon anketi yaklaşık
hesaptır. Uygulama puanları fiziksel iade veya doğrulanmış CO2 tasarrufu
değildir. Gerçek ödül/ödeme, saha etkisi ve kurumsal müşteri doğrulaması yoktur.
Sunumda denemediğin bir özelliğe 'tamamen test edildi' deme.

### AI kullanıcı için ne yapıyor?

Gemini kullanıcının yüklediği atık fotoğrafını inceleyerek malzeme türü tahmini
üretir. Bu tahmin, doğru rehbere ve ilgili teslim seçeneklerine ulaşmayı
kolaylaştırır; resmî depozito kapsamını, barkodu veya fiziksel geri dönüşümü
tek başına doğrulamaz. Karbon hesabı ve puan kuralları AI değil, ayrı
deterministik hesap ve sunucu iş kurallarıdır.

## Göndermeden önce

1. Yeniden sunum notu üç görevde de bulunsun; aynı proje odağı korunsun.
2. Ad/e-posta ve kişisel motivasyon gerçek bilgilerle tamamlansın.
3. Görev 1 tek sayfalık belge, Görev 2 tek sayfalık PDF gereksinimleri karşılansın.
4. Ürün/video bağlantısı başka cihazda veya gizli sekmede açılsın.
5. Pilot hedefleri 'gerçekleşti' diye yazılmasın; ön test henüz yapılmadı.
6. Yarışma eşleşmeleri form seçenekleridir; program ortaklığı/onayı iddiası değildir.
7. Yeniden teslim kabulü ve son tarih için organizasyonun açıklamasını esas al.
