# Arayüz, konum verisi ve performans incelemesi

Tarih: 24 Ekim 2026. Bu çalışma önceki güvenlik tesliminin üstüne uygulanmıştır.
Önceden bulunan CI/altyapı değişiklikleri korunur. Canlı Neon verisi değiştirilmez;
bu rapor yeni APK'nın telefonda çalıştırıldığı veya Render'ın dağıtıldığı iddiası değildir.

## 1. Topluluk: Yenile neden grup oluşturuyordu?

Boş grup durumundaki `_Empty` bileşeni düğmeye sabit `Yenile` etiketi koyuyordu,
ama o bileşene `_openCreateGroup` callback'i verilmişti. Gerçekten yanlış işleme
bağlanıyordu. Artık boş ve hatalı grup listesinin Yenile düğmesi yalnız grup
listesini sorgular. Grup Oluştur ayrı FAB olarak korunur; üst çubukta ayrıca
Topluluğu yenile simgesi vardır.

Pull-to-refresh artık HTTP yanıtını bekler. Kısa/boş listeler de aşağı çekilebilir.
Arkadaş ve arkadaşlık isteği sorguları hata alınca boş liste gibi sunulmaz;
yeniden denenebilir hata durumu vardır. Henüz açılmamış sekmelerin Future
hataları da gözlemlendiği için kontrolsüz exception olarak dışarı çıkmaz.

## 2. İl, ilçe ve mahalle

| Alan | Önce | Sonra |
|---|---|---|
| Kayıt / grup / etkinlik illeri | 81 il | Aynı 81 il; zorunlu varsayılan seçim yok |
| Ortak ilçeler | 359 seçilmiş ilçe | 973 ilçe |
| Şanlıurfa ilçeleri | 7 | 13 |
| İstanbul ilçeleri | 7 | 39 |
| Ankara ilçeleri | 5 | 25 |
| Kayseri ilçeleri | 16 | 16, korundu |
| Profil düzenleme | Ayrı 3 il / 6 ilçe listesi | Ortak 81 il / 973 ilçe kataloğu |
| Mahalle | Örnek ve sınırlı seçenekler; kayıtlı mahalle kaybolabiliyordu | Kayıtlı değer korunur, kullanıcı kendi mahallesini yazar |

Kaynak: [HGM il/ilçe Excel dosyası](https://www.harita.gov.tr/uploads/files-folder/il_ilce_alanlari.xlsx),
2026 çalışma sayfası. Bu dosyanın alan/geometri açıklaması resmî idari sınır
tespiti değildir; uygulama yalnız yer adlarını kullanır. Dosya SHA-256'sı ve
dönüşümler `frontend/assets/data/turkey_locations.json` içindedir.
`_MERKEZ` ekleri Merkez olarak gösterilir. Kaynakta kalan Eyüp/Kazan adları,
ilgili kaymakamlık kayıtlarıyla Eyüpsultan/Kahramankazan olarak güncellendi.
Marmaraereğlisi yazımı ve Excel'in sayıya çevirdiği Samsun/19 Mayıs adı da
kaymakamlık kaynaklarıyla doğrulandı. Dart ve JSON aynı 81/973 kataloğu
taşır; eşitlik, benzersizlik ve sayısal sahte ilçe olmaması test edilir.

Kaynaklar: [Eyüpsultan](https://eyupsultan.gov.tr/ilcemiz-isminin-eyupsultan-olarak-degismesi-hk),
[Kahramankazan](https://kahramankazan.gov.tr/ilcemizde-gorev-yapmis-kaymakamlirimiz),
[Marmaraereğlisi](https://marmaraereglisi.gov.tr/), [19 Mayıs](https://19mayis.gov.tr/).

Türkiye'nin bütün mahallelerinin doğrulandığı iddiası yoktur. Sınırlı örnek
mahalle listesi yerine metin alanı vardır. Kullanıcı il değiştirirse eski
ilçe/mahalle temizlenir; değiştirmezse kayıtlı mahalle saklanır. Profildeki
yaş kontrolü sunucunun minimum 13 yaş kuralıyla uyumludur.

## 3. DOA: Hangi şehirde kaç makine var?

Tam 81 il tablosu: [doa-city-counts-tr.md](doa-city-counts-tr.md).
İşlenebilir çıktılar: [CSV](doa-city-counts.csv), [JSON](doa-city-counts.json),
[UUID bazında şehir eşlemesi](doa-point-city-index.csv).

4.037 ham nokta: **2.162 DIM makine, 1.764 MIN merkez, 111 SDM, 0 KIM**.
Makine ile merkez sayıları karıştırılmaz. Aynı snapshot'ın UUID ve sayısal
koordinatları korunur; bu sayım için veri silinmedi veya rastgele nokta eklenmedi.
İl bilgisi olmayan 3 kayıt (2 DIM, 1 MIN) ayrıca listelenir; 4.034 kaydın ili
adresinden eşleşir. Konumdan tahmin veya harici reverse-geocode ile veri uydurulmaz.

Önemli düzeltme: eski `%urfa%` araması Diyarbakır/Bağlar'daki **Urfa Yolu
Bulvarı** adresini de Şanlıurfa gibi sayıyordu. Eski 28 sonucu bu geniş metin
eşleşmesiydi; gerçek adres-il eşlemesinde Şanlıurfa **27 DIM / 31 toplam nokta**.
Kayseri **29 DIM / 66 toplam nokta**. Bu fark bir noktanın silinmesi değildir.
Kaynakta çelişkili/bozuk ilçe bulunan kayıtlar `districtWarnings` alanında
ayrıca tutulur; yanlış ilçe kabul edilmez.

Sayılar **24 Ekim 2026 snapshot envanteridir**. Canlı çalışma/kabul durumu veya
bugünkü yeni kurulum sayısı değildir. Uygulamadaki destek/durum ayrımı, OR
malzeme filtresi, viewport sınırı ve nokta türleri korunur.

## 4. Düzeltilen diğer arayüz sorunları

| Bölüm | Bulgu | Uygulanan değişiklik |
|---|---|---|
| Açılış | Geçici 5xx/bağlantı hatası tokenları siliyordu | Oturum korunur; yeniden deneme ekranı açılır; yalnız kesin 401/403 reddi oturumu temizler |
| Genel HTTP / giriş | Bazı ortak isteklerde sonsuz bekleme mümkündü | Normal ortak JSON istekleri ve refresh için 30 sn sınır; mutasyonlar timeout'ta otomatik tekrar gönderilmez |
| AI yüklemesi | İstemci 40 sn'de kesilirken sunucu 60 sn'ye kadar analiz bekliyordu | Yalnız tarama isteği 80 sn üst sınırla backend connect/read bütçesini kapsar; yapay bekleme eklenmez |
| Topluluk araması | Eski arama yeni sonucu ezebiliyordu | Ayrı debounce'lar ve sorgu nesli kontrolü |
| Ayarlar / gizlilik | Hızlı aç/kapa ters sıra sunucu yanıtı yaratabiliyordu | Tek kayıt işlemi; anahtar beklerken kilitli, sunucunun döndürdüğü gizlilik esas |
| Market | Farklı ürünlere eşzamanlı satın alma mümkündü | İlk await öncesi ortak işlem kilidi; diğer satın alma düğmeleri de bekler |
| Market / yenileme | Future döndüren setState callback'i debug assertion yaratabiliyordu | Senkron void callback; aynı sorun avatar yolu/liderlik/görsel yenilemelerinde de düzeltildi |
| Profil | Başka sekmedeki işlem sonrası eski profil kalabiliyordu | Profil sekmesine yeniden girişte kontrollü yeniden yükleme |
| Sohbet | Gönderim yanıtı, bu sırada yazılan yeni taslağı siliyordu | Yalnız hâlâ gönderilen metin varsa temizlenir; yeni taslak korunur |
| Etkinlik sohbeti | Yeniden bağlanmada kopuklukta gelen mesajlar kaçabiliyordu | STOMP aboneliğinden sonra HTTP geçmiş uzlaştırması; üst üste geçmiş istekleri biriktirilmez |
| Görseller | Logout'ta Future hatası bir sonraki frame'den önce dışarı çıkabiliyordu | Future hemen gözlemlenir; yetkili görsel bileşeni kendi hata/fallback durumunu gösterir |
| Harita kümesi | Programatik yakınlaşma kümeleri hemen yenilemiyordu | Zoom çizim güncellemesi ağ/gesture debounce'undan ayrıldı |
| Harita filtresi | Sınırsız bütün ülkeyi aynı anda çizme izlenimi verebiliyordu | Mesafe, viewport ve sonuç limiti açıkça ayrıldı |
| Etkinlik GPS | Gerçek konum alınamayınca Şanlıurfa fallback'i adres sanılabiliyordu | Harita fallback'i kalır; etkinlikte gerçek GPS yoksa kullanıcıdan elle seçim istenir |
| Akademi sınavı | Kısa/yatay ekranda soru/geri bildirim taşabiliyordu | Soru, seçenek ve geri bildirim birlikte kaydırılabilir |
| Liderlik | Boş listede yenileme yoktu | Boş durum da pull-to-refresh içerir |

## 5. Hız iyileştirmeleri ve ölçümün sınırı

| İş | Önce | Sonra | Kanıt |
|---|---|---|---|
| Tek grup araması/filtre değişimi | Grup + arkadaş + istek + davet: 4 çağrı | Yalnız grup: 1 çağrı | Widget çağrı sayacı; o işlemde %75 daha az çağrı |
| Görev olayı | Tetiklenen N görev için N progress okuması | Tek toplu progress okuması; eşleşen görev yoksa 0 | Repository mock çağrı testleri ve gerçek PostgreSQL regresyonu |
| Aynı fotoğrafı eşzamanlı isteyen widget'lar | Her biri ayrı HTTP isteği | Aynı hesaptaki devam eden istek paylaşılır | İki çağrı/tek loader testi; tamamlandıktan sonra tekrar sorgulanır |
| Sohbet fotoğrafı | Decode/resize/JPEG döngüsü UI üzerinde | Android/iOS'ta compute/isolate; 1600 kenar / 2 MB sınırı aynı | Boyut/bozuk dosya testleri; Web'de worker olduğu iddia edilmez |
| Gizlilik ve satın alma | İstekler üst üste binebiliyordu | Kullanıcı işlemleri seri | Geciken API/haptic testleri |

Bu sonuçlar “uygulama yüzde X hızlandı” ölçümü değildir. Gerçek telefon FPS'i,
pil tüketimi, production p95 ve çok kullanıcılı yük testi ayrıca gerekir.
Future timeout arayüzün bekleyişini sınırlar; altta başlamış bir POST'un sunucuda
hiç çalışmadığını garanti etmez. Tek-sefer ödül/DB kilidi mevcut sunucuda korunur.
Medya için yeni kalıcı/public cache eklenmedi; üyelik/gizlilik değişimi yeni GET'te
tekrar kontrol edilir. 512 MiB'de ONNX bellek riski bu UI çalışmasıyla çözülmüş değildir.

## 6. İnceleme ve test kapsamı

33 ekranın kaynak yapısı, ortak servis/widget'lar ve navigasyon incelendi.
Kod incelemesi bütün sayfaların gerçek telefonda tek tek kullanıldığı anlamına gelmez.

| Alan | Kontrol |
|---|---|
| Splash, giriş, kayıt, onboarding | Oturum, ağ hatası, form ve il/ilçe bağımlılığı |
| Tarama, sonuç, harita ve konum haritası | Mevcut doğrudan DOA akışı, filtre/zoom, yanlış GPS fallback'i |
| Görev, market, avatar yolu/seçimi, liderlik | Ödül/bakiye akışı, tekrar işlem, yenileme ve responsive yerleşim |
| Rehber, ders ve quiz | Katalog korunması, kısa ekran, doğru/yanlış geri bildirim |
| Karbon ekranları | Mevcut 20 soru ve opsiyonel yakıt/elektrik regresyonları korunur |
| Topluluk, grup/etkinlik sohbeti ve grup bilgisi | Yanlış callback, istek yarışları, taslak, bağlantı dönüşü, üyelik |
| Profil, public profil, ayarlar, parola ve geçmiş | Profil güncelliği, görsel fallback, gizlilik ve tema regresyonları |
| Bildirim, superuser paneli | Mevcut rol/gösterim akışı; kapsamı belirsiz tercihler aşağıda belirtilir |

Güncel komut ve sonuçlar: `ui-audit-verification.json`. Önceki güvenlik turunun
88/88 sayıları bu tur için otomatik kullanılmaz. Python şehir sayımı testleri
yalnız dosya okur. PostgreSQL testleri yalnız izole yerel DB'yi hedefler.

Son sonuç: **107 backend / 116 Flutter / 7 Python testi geçti**. Web release
derlemesi 81,3 sn'de tamamlandı. Java 17 konteyneri `prod` ve Hibernate validate
ile açıldı; altı migration doğrulandı ve 4.037 snapshot kaydı değişmeden kaldı.
Bu revizyonda yeni migration yoktur.

Gerçek Chrome'da:

- Topluluk arama, boş durumdaki Yenile ve AppBar yenilemesi gerçek HTTP 200
  yanıtlarıyla geçti. Yenile grup oluşturma formunu açmadı. 320/390/430 px
  görüntülerinde taşma görülmedi (`community-browser-verification.json`).
- Yetkili profil görseli, gerçek galeri dosyası, analiz, cam rehberi, glass
  filtreli DIM haritası ve seçili koordinata yol tarifi isteği geçti
  (`security-core-browser-verification.json`).
- Akademi arama, ders, üç soruluk sınav, sunucuda artan bakiye, tekrar
  tamamlamada sıfır ek puan ve tamamlandı işareti geçti. Ders 320/390/768 px
  incelendi (`academy-browser-verification.json`).

Bu üç senaryoda JS veya gözlenen overflow hatası yoktu. Tarama sağlayıcısı
yerel `ONNX_CPU` idi; bu, canlı Gemini anahtarını doğrulamaz. Chrome klavye
odağını beklemeden yazan ve CanvasKit birleşik metnini birebir arayan ilk test
adımları düzeltildi; uygulama kodu bir testi yapay biçimde geçirecek şekilde
değiştirilmedi. STOMP yeniden bağlanması bu turda canlı çoklu istemciyle
sınanmadı. Bu revizyon için yeni APK/telefon testi ve tam analyzer çalışması
yapılmadı. `git diff --check` geçti; ham DOA JSON hash'i değişmedi.

## 7. Açık kalanlar ve sonraki öncelik

- Market çerçeveleri satın alınınca sahiplik veritabanına kaydediliyor; ancak
  profil bileşenlerinde bu çerçeveyi kuşanma/gösterme akışı henüz yok. Satın
  alınan sanal ürün ile görünür profil süslemesi aynı şey olarak sunulmamalı.
- Bildirim ayarlarındaki görev/topluluk anahtarları halen yalnız cihaz tercihi
  saklıyor; backend bildirim üretimini veya cihaz push servisini kapatmıyor.
  Tam bildirim tercihi akışı ayrı iş; bu anahtarların işlevi abartılmamalı.
- Çok replikada STOMP ortak broker, gerçek bağlantı kesme/üyelik iptali denetimi,
  scheduler sayfalama/kilit ve scan-history cursor aynı kalır. Bunlar ayrı,
  daha geniş entegrasyon testi gerektirir.
- Ulusal mahalle kataloğu yoktur; kullanıcı metni kullanılır. Üç DOA adresi il
  belirlemek için yetersizdir. Kaynak düzeltilmeden rastgele şehir atanmaz.
- Snapshot adres sayımı bir coğrafi sınır sorgusu değildir. Kaynakta yanlış
  koordinat varsa bu rapor onu otomatik düzelttiği iddiasında bulunmaz.
- Canlı Gemini kotası/anahtarı, Render kapasitesi ve fiziksel telefon saha testi
  bu yerel UI/performans çalışmasından ayrı doğrulanmalıdır.
