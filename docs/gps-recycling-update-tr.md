# GPS tabanlı DOA ve toplam geri dönüşüm özeti

25 Ekim 2026. Önceki mobil yakınlaştırma optimizasyonları korunarak uygulandı.
Yerel test sonucu, canlı Render dağıtımı ve yayımlanan APK ayrı durumlardır.

## Haritada ne düzeldi?

- Önceden kamera hareketinden 550 ms sonra harita merkeziyle yeni arama
  yapılıyordu. Ekranın ortası değişince yakındaki liste de değişiyordu.
- Artık yarıçap ve mesafeler telefonun GPS konumuna dayanıyor. Kamera
  sürükleme/yakınlaştırma HTTP isteği oluşturmaz veya sonuçları görünür alanla kesmez.
- Yenile GPS'i yeniden alır. Yeni konum alınamazsa son bilinen gerçek konum
  korunur ve açık uyarı gösterilir. Hiç konum alınmamışsa varsayılan bölge
  yalnız bu durum belirtilerek gösterilir.
- 1–50 km, 3–18 zoom, karo sınırları ve önbellekli marker gruplama korunur.
- Her HTTP sayfası 100 noktadır. Bellekte en fazla 300 nokta tutulur;
  Sonraki/Önceki noktalar ile kalan sonuçlara ulaşılır. Bu çizim penceresi
  veritabanındaki kayıtları azaltmaz veya silmez.
- Eski kamera dinleyicisi, debounce timer'ı, viewport state'i ve kullanılmayan
  özet parametresi kaldırıldı. İlgisiz kullanıcı dosyaları, kaynak dışa
  aktarımları ve Kubernetes dosyaları silinmedi.

## Veriler azaldı mı?

Hayır. Kaynak snapshot hâlâ **4.037 nokta: 2.162 DIM, 1.764 MIN ve 111 SDM**.
Varsayılan harita DIM gösterir; merkez/toplu nokta türleri ayrı filtrelerdedir.
Bu çalışmada seed, DOA kaynak JSON'ları ve makine tablosu değiştirilmedi.
Canlı Neon sayısı bu yerel envanterle aynıymış gibi sunulmuyor.

## Profilde iki ayrı karbon bilgisi

1. Mevcut yıllık karbon ayak izi ve hesaplamaya geçiş aynen korunur.
2. Ayrı **Toplam geri dönüşüm** kartı, ödüllendirilmiş benzersiz geri
   dönüştürülebilir malzeme taramalarını ve örnek CO₂e potansiyelini gösterir.

Hesap `tarama sayısı × senaryo kütlesi × malzeme katsayısı` şeklindedir.
PET/cam/alüminyum için tarama başına sırasıyla **25/200/15 g** uygulama
varsayımı kullanılır; bunlar ölçülmüş veya evrensel ortalama gramajlar değildir.
Malzeme katsayıları mevcut `CarbonMath.wasteDifference` EPA WARM v13 ABD
depolama → geri dönüşüm senaryosundan gelir. Ayrıntı düğmesi varsayımları açar.

- Genel plastik PET, genel metal alüminyum sayılmaz. Bilinmeyen malzeme veya
  katsayı sayıya dahil edilir fakat CO₂e alt toplamına dahil edilmez.
- Yeni taramalarda kesin malzeme anahtarı, genel görünen isimden ayrı saklanır.
  Eski genel kayıtlar tahminle geriye doldurulmaz; cam gibi açık sınıflar okunabilir.
- Aynı görsel hash'i kullanıcı başına bir kez sayılır. Eski hash'siz kayıtların
  tekrarlarını ayırt etme imkânı yoktur; arayüz bu sınırı açıklar.
- Sınıflandırma fiziksel iade/geri dönüşüm kanıtı değildir. Kart doğrulanmış
  karbon tasarrufu, gerçek tartım veya karbon kredisi iddiasında bulunmaz.
- Bu senaryo yıllık ayak izinden düşülmez, ek puan üretmez ve kullanıcı
  beyanı `WasteAction` kayıtlarıyla toplanmaz.

## Backend ve veri güvenliği

`GET /api/carbon/summary` yanıtına geriye uyumlu `recyclingPotential`
nesnesi eklenir. Mevcut alanlar korunur; kullanıcının kimliği mevcut
authentication akışından gelir. Tüm tarama geçmişi telefona/Java listesine
yüklenmez: PostgreSQL gruplama ve tekrarsızlaştırma yapar.

`V7__scan_recycling_potential_material.sql` yalnız nullable
`scan_history.impact_material varchar(20)` ekler. Kullanıcı, puan, tarama,
görev veya DOA kaydı silmez. Mevcut Flyway akışında çalışır; iki kez
uygulanabilirliği izole PostgreSQL testinde doğrulandı.

## Doğrulama

- Java 17, izole PostgreSQL 15: Maven `test`, **128 test / 44 sınıf**,
  0 hata, 0 başarısız, 0 atlanan. V7 gerçek PostgreSQL'de uygulandı.
- Flutter tüm paket: `flutter test --no-pub --concurrency=1`, **148 test geçti**.
- Son GPS izin kaybı düzeltmesinden sonra harita/profil/kart testleri ayrıca
  yeniden çalıştırıldı: **21/21 geçti**.
- `dart analyze lib test`: son değişikliklerle **sorun bulunmadı**.
- `python -m unittest discover -s scripts -p test_locations_and_doa.py -v`:
  **11/11 geçti**; 81 il, 973 ilçe ve snapshot bütünlüğü korundu.

Testlerde 200 kamera hareketinin ek API isteği üretmediği, sayfa merkezi
ve tüm mesafelerin GPS'e bağlı kaldığı, 300'den sonraki sonuçlara erişim,
zoom sınırı, küçük ekranda büyük yazı, eski backend yanıtı ve hata durumları
kontrol edilir. Yerel mikrobenchmark fiziksel telefonda FPS/ANR ölçümü değildir.

## Dağıtım

Yeni özet için backend'in yeni commit ile dağıtılması, Flutter istemcisinin
yeniden derlenmesi gerekir. Eski APK yeni ekranı içermez. Push işlemi tek
başına Render dağıtım başarısı olarak değerlendirilmez. Canlı Neon'a manuel
SQL, veri silme veya sıfırlama uygulanmadı.
