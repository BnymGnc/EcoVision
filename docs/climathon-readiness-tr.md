# EcoVision: Climathon final incelemesi

**Son durum:** Aşağıdaki P0/P1 maddeleri ilk tespitlerdir. Sonraki kullanıcı
onayıyla medya ACL'si, sunucu sınav doğrulaması ve tarama ödül koruması kodlandı.
Güncel uygulama/test/kalan riskler: [final-security-and-tests-tr.md](final-security-and-tests-tr.md).
Dağıtım yapılmış olduğu anlamına gelmez.

İnceleme: 24 Ekim 2026. Görev 1–3 metinleri ve yerel Görev 4 ekiyle mevcut Flutter,
Spring Boot, veri, model, test ve dağıtım dosyaları karşılaştırıldı. Bu bir
penetrasyon testi veya production sertifikası değildir. Ek, başvuru gereksinimi
olarak okundu; otomatik form gönderme ya da kişisel sonuç uydurma talimatı sayılmadı.

## 1. Jüri için en güçlü ürün hikayesi

**Sorun:** Kullanıcı bir atığı gördüğünde malzemesini, doğru ayırma yolunu ve
uygun teslim noktasını tek akışta belirleyemiyor. İlk hedef kullanıcı olarak
kampüs/yurt sakinleri seçilebilir; bunun doğrulanmış kullanıcı araştırması olduğu
iddia edilmemeli.

**Çalışan çekirdek:** Fotoğraf → görsel malzeme tahmini → belirsizliğin gösterilmesi
→ kaynaklı ayırma rehberi → ilgili DOA noktaları → yol tarifi.

**Destekleyici katman:** Akademi, görevler, avatarlar ve gruplar doğru davranışı
öğrenme/tekrarlamayı destekler. Bunlar tek başına geri dönüşüm veya karbon azaltımı
kanıtı değildir. Demo süresini sohbet ve marketin bütün ayrıntılarına harcamak ana
değeri gölgeler.

- Program hedefiyle en yakın eşleşme: **Cutting waste by half by 2035**.
  Bu bir program hedefidir; EcoVision'ın ölçtüğü sonuç değildir.
- Siemens etki alanı: **Resource Efficiency & Circularity**.
- Birincil SDG: **12**, özellikle **12.5**; iklim etkisi için SDG 13 ikincil.
- Finansman varsayımı: üniversite/belediye kampanyaları ve katılım analitiği.
  Henüz ücretli talep, sözleşme veya gelir doğrulanmış değil.

## 2. Formlarda hangi kanıtı kullanmalı?

| Teslim | Koddan çıkarılabilen | Halen gerekli |
|---|---|---|
| Problem Definition | Ayrıştırma/teslim kararının neden birden çok adım gerektirdiği | Kendi gözlemin, kişisel motivasyonun ve yerel baseline |
| PDR | Monolitik API, Flutter istemci, gerçek model, kaynaklı harita | Kullanıcı geri bildirimi ve finansal varsayım testi |
| Build & Show | Gerçek multipart fotoğraf → model → JSON → DB akışı | Yayındaki sürümde aynı akışın kanıtı |
| Final Project | Çalışan çekirdek + açıklanmış sınırlar + test kayıtları | Erişilebilir ürün linki, son PDF'ler, listedışı YouTube videosu |

Görev 4 eki **25 Ekim 2026 Pazar 23.59** teslimini istiyor. Yeni bir sosyal ağ
kurmak yerine mevcut çekirdeği sağlamlaştırmak daha iyi bir final yatırımıdır.
AI Studio zorunlu mimari diye sunulmamalı: bu proje Flutter/Spring Boot ile
geliştirildi; Gemini kullanılması AI Studio Build ile geliştirildiği anlamına gelmez.

## 3. AI gerçekten ne yapıyor?

- `WasteAnalysisService` provider seçer: Gemini veya sunucuda ONNX.
- `LocalWasteModel`, paketli MobileNetV2 omurgası ve TrashNet ile eğitilmiş
  başlık üzerinden gerçek fotoğraf tensörü çalıştırır. Kayıtlı cevap döndürmez.
- Sınıflar: karton, cam, metal, kağıt, plastik, diğer. Kağıt/karton uygulama
  yanıtında aynı gruba indirgenir.
- Model kartındaki 395 görsellik testte accuracy **0,8253**, macro-F1 **0,7881**.
  Bunlar saha doğruluğu değildir. Düşük skorlu örnekler çıkarılınca elde edilen
  **0,9140** alt-küme doğruluğunu tüm fotoğrafların doğruluğu diye sunma.
- Fotoğraf, PET/alüminyum türünü, DOA işaretini, barkodu, kütleyi, güvenli içeriği
  veya gerçekleşmiş iade işlemini kanıtlamaz.
- Yerel modelin elektronik, organik, yağ, tekstil veya tıbbi atık sınıfı yoktur.
  Gemini daha geniş sınıflar döndürebilse de aynı güvenlik/kanıt sınırları geçerlidir.
- Haversine mesafesi, puan tablosu, quiz sayımı ve karbon toplamı AI değildir.

Bu çalışmada AI özeti sonuç sayfasına eklendi: provider ve model sürümü
açılabilir, kapsam ve sınırlar okunabilir. Sonuçtan ilgili rehbere geçilebilir;
doğrudan DOA harita butonu korunur. Yeni AI çağrısı veya maliyeti eklenmedi.

### Sonraki AI geliştirmeleri

1. **Saha doğrulama seti:** Farklı telefon, ışık, arka plan, çoklu nesne ve
   kapsam dışı ürünler; aynı nesne train/test'e bölünmesin.
2. **Düzeltme akışı:** İsteğe bağlı, onaylı kullanıcı düzeltmesi; orijinal tahmin,
   sürüm ve düzeltme ayrı tutulsun. Kullanıcı etiketi otomatik doğru kabul edilmesin.
3. **Skor kalibrasyonu:** Eşik yalnız doğrulama setinde ayarlansın; saha
   confusion matrix, ret oranı ve yanlış yönlendirme oranı ayrı raporlansın.
4. **İkinci fotoğraf:** Düşük skorda daha iyi kadraj iste; her belirsizliği
   otomatik ücretli bulut çağrısına çevirmeden önce izin/maliyet kararı ver.
5. **Kaynaklı açıklama:** Tahmini küratörlü rehberle eşleştir. Serbest LLM
   tavsiyesinin tehlikeli atık kararlarını değiştirmesine izin verme.

## 4. Öncelikli mantık ve güvenlik bulguları

### P0 — Gizli medya URL'si gizlilik sınırını aşabiliyor

Kanıt: `security/SecurityConfig.java`, GET `/api/media/**` için `permitAll`;
`controller/MediaController.java` varlığı kimlik/üyelik kontrolü olmadan döndürür
ve bir yıl `public, immutable` cache uygular. `MediaAsset` içinde sahip veya
grup erişim alanı yoktur. UI'da özel fotoğrafı avatarla değiştirmek, bilinen URL'yi
iptal etmez. UUID tahmin etmenin zor olması yetkilendirme değildir.

Öneri: sahip/kapsam ilişkisi + grup üyeliği/arkadaşlık denetimi; özel görsellerde
özel cache politikası, gerekirse kısa ömürlü imzalı URL. Mevcut Image.network ve
dosya açma akışıyla birlikte migrate edilmeli; sırf permitAll kaldırmak görüntüleri
bozar. Bu oturumda habersiz bir API uyumsuzluğu yaratılmadı.

### P1 — Quiz ödülü sunucuda sınav sonucuna bağlı değil

Kanıt: `EducationController.complete` sadece categoryId alıyor;
`EducationProgressService.complete` cevapları veya başarıyı kontrol etmiyor.
Flutter'daki iki doğru koşulu atlanarak yetkili kullanıcı ödül isteyebilir.
Mevcut DB tek-seferlik mekanizması tekrar ödülü önler; fakat başarı kanıtlamaz.

Öneri: sunucunun sürümlü soru kataloğu, cevap indeksleri ve deneme kimliği;
sunucuda en az 2/3 koşulu, mevcut kullanıcı kilidi ve idempotent ödül korunmalı.
Yeni frontend ve eski APK uyumluluğu planlanmalı. Bu çalışma içerik/arayüzü
iyileştirir; bu açığı kapattığını iddia etmez.

### P1 — Eski etiket uç noktası ve tekrar fotoğraf XP suistimaline açık

Kanıt: `ScanController.saveScan` → `ScanService.saveScan` istemci
`materialType` değerinden doğrudan puan üretir. Görsel kanıt yoktur.
Ayrıca aynı görsel için Gemini cache sonucu alınsa bile `analyze` yeniden
scan/XP oluşturur. Görsel cache'i maliyet optimizasyonudur; ödül idempotency'si değildir.

Öneri: etiket yolunu kullanım analiziyle kaldır/kısıtla; analiz kimliği veya
kullanıcıya bağlı görsel hash'i için ayrı tekrar-ödül politikası belirle.
Benzer iki gerçek ambalajı aynı saymama gereksinimi de test edilmeli.
Puan hiçbir koşulda fiziksel iade kanıtı olarak sunulmamalı.

### P1 — Haritada destek ile aktif kabul aynı şey değil

Kanıt: `DoaMapService.toPoint` bin ve kaynak malzeme kodlarını
`acceptedMaterials` içine alıyor; `nearby` bu kümede OR ile süzüyor,
`binStates == true` şartını uygulamıyor. Flutter `MapPin.supports` ile
`accepts` ayrı olsa da kullanıcı “uygun” ifadesini anlık kabul sanabilir.
Telemetry bir snapshot olduğundan true bile bugünün garantisi değildir.

Öneri: ayrı “Bu malzemeyi destekler” ve “Kaynak tarihinde kabul bilgisi var”
görünümü; false/unknown açıkça ayrı. Aktif kabul filtresi istenirse bağımsız ve
açık etiketli olsun. Kaynak state alanının operasyonel anlamı sağlayıcıdan teyit
edilmeden kesin yorum yapılmasın. “Sınırsız” mesafe de sonuç limitini kaldırmaz;
mevcut API 500 varsayılan / 1000 üst sınır uygular ve harita viewport bazlı yükler.

### P2 — Bazı çevresel iddialar eldeki kanıttan daha güçlü

`WasteMaterial` sabit çözünme süreleri ürün/ortam bağımsız gösteriliyor.
Karbon anketi sabit ağırlıkları kapsamlı kişisel envanter sayılmaz.
Tarama adedi geri dönüştürülen adet değildir. XP harcamak gerçek ağaç/kupon
teslimatı yaratmaz. RVM kayıt sayısı da tamamı çalışır makine sayısı değildir.

Bu çalışmada rehberdeki sabit çarpıcı ama doğrulanmamış sayılar ve kesin AI
güvenliği iddiaları kaldırıldı. Backend puan kataloğu veya eski kayıtlar
değiştirilmedi. Çözünme süresi sunumu da sonraki bir uyumlu sürümde kaynak/kapsamla
değiştirilmeli; geçmiş kayıtlara sessizce yeni değer yazılmamalı.

## 5. Optimizasyon önerileri

| Alan / kod kanıtı | Öneri | Beklenen fayda / doğrulama |
|---|---|---|
| `GroupChatScreen`: STOMP açıkken de 8 saniyede polling; in-flight kilidi yok | Bağlantı yokken polling, tek in-flight istek, yaşam döngüsünde duraklatma; metadata'yı ayrı kontrollü yenileme | İstek sayısı ve p95 ölç; event kartı yenilemesini kaybetme |
| `MainTabNavigator`: IndexedStack ve 15 sn okunmamış sayacı | Sekmeleri ilk açılışta oluştur, sayaçları uygulama arka plandayken durdur, istekleri birleştir | Başlangıç istek sayısı ve pil tüketimini karşılaştır |
| `QuestEngineService`: her eşleşen görev için progress sorgusu | Kullanıcı + tetikleyici için toplu progress sorgusu ve uygun indeks | SQL sayısı; aynı olay için doğru ilerleme ve eşzamanlı claim regresyon testi |
| `QuestSchedulingService`: son 30 günün kullanıcılarını listeye alır | Sayfalı/stream işleme, çok replika için dağıtık kilit ve unique atama koruması | Büyük kullanıcı setinde bellek ve gece işi süresi |
| `ScanService.getScans`: tüm tarama geçmişi döner | Cursor/sayfalama ve profile ilk N kayıt | Büyük hesapta DB/yanıt/bellek kullanımı |
| `DoaMapService`: sınırsızda bütün projection'ları Java'da sıralar | Ölçek büyürse SQL/coğrafi indeks ile yakınlık + bounding box | 4 bin kayıttan önce ölç; gereksiz PostGIS migrasyonu yapma |
| Medya `bytea` ve doğrudan byte[] yanıt | Thumbnail, boyut/piksel kontrolü, uygun nesne deposu ve erişim katmanı | Fotoğraf yükünde heap/DB büyümesi, yetki regresyonu |
| Model + küçük Render örneği | Native+heap belleği birlikte izle, gerekirse ayrı inference servisi/uygun plan | Eski 137 için OOM kesin denmedi; önce platform logu ve RSS ölçümü |
| JAR içindeki türetilmiş DOA dışa aktarımları | **Uygulandı:** CSV/GeoJSON/türetilmiş JSON ve yardımcı betikleri runtime resources dışına al | Ham JSON/manifest/model/migration yerinde kalır; paket testi |
| Docker build context | **Uygulandı:** target, upload ve logları .dockerignore ile dışla | Eski JAR ve yükleme içeriklerini build'e taşımama |

## 6. Atık rehberinde ne değişti?

Eski: 10 uzun düz metin ve 30 soru; arama yok; yanlış kesinlikte AI/süre/tehlike
iddiaları bulunuyordu.

Yeni: Aynı 10 categoryId ve 30 soruluk yapı korunarak Türkçe içerik düzeltildi.
Malzeme araması Türkçe karakter/aksan farkını tolere eder. Tümü, tamamlanmayan ve
tamamlanan filtreleri vardır. Her modül:

- Kısa özet ve metin uzunluğundan tahmini okuma süresi.
- Nereye teslim edileceği ve yerel kabul kontrolü.
- Uygun örnekler ve o toplama akışına uygun olmayanlar.
- Hazırlık, sık hatalar, güvenlik notu ve yeniden kullanım.
- Gerçek modelin kapsamına uygun AI ipuçları/sınırları.
- Açılabilir HTTPS kaynakları ve içerik kontrol tarihi.
- Aynı üç soruluk sınav ve mevcut tek-seferlik ödül akışı.

Kaynaklar genel tavsiyedir; Türkiye'de her belediyenin aynı atığı aldığı anlamına
gelmez. ABD'ye özgü oran veya yasal kural Türkiye geneli diye kopyalanmadı.

## 7. Savunulabilir pilot ve etki hedefi

Öneri, henüz sonuç değil: 20 gönüllü kampüs kullanıcısı ile 2 hafta.
Başlangıçta 10 örnek için doğru ayırma oranı ve uygun nokta bulma süresi ölçülsün.
Aynı zorlukta farklı örneklerle sonunda tekrar ölçülsün.

- Hedef hipotezi: doğru ayırmada **15 yüzde puan** artış.
- Hedef hipotezi: uygun nokta bulma medyan süresinde **%30** azalma.
- Yan metrik: model ret/düzeltme oranı ve yanlış DOA yönlendirme oranı.
- Gerçek iade: yalnız kullanıcı beyanıysa öyle etiketle; resmi teyit olmadan
  doğrulanmış geri dönüşüm tonajı veya CO₂ azaltımı diye raporlama.

Bu hedefler ölçüm sonucu değil test edilecek varsayımdır. Kişisel baseline'ını
ankette yoksa “henüz ölçülmedi” diye belirt. Ulusal atık sayısı yerel kullanıcının
karar süresini ölçen baseline'ın yerine geçmez.

## 8. Teslimden önce kısa kontrol listesi

1. Yeni özellik eklemeyi durdur; tek gerçek fotoğrafla uçtan uca demo kaydet.
2. Provider'ın gerçekten açık olduğunu doğrula; .env içinde örnek anahtar bulut
   analizini çalıştırmaz. Yerel için AI_PROVIDER=local, ML_ENABLED=true gerekir.
3. Canlı API ile APK/web adresini eşleştir; yerel test başarısını Render kanıtı sayma.
4. Video 2 dakika, YouTube listedışı; kişisel veri ve sırlar ekranda olmasın.
5. Son PDR/Problem Definition aynı akışı anlatsın; kaldırılmış ambalaj formunu
   veya eylem kaydı ekranını demo adımı diye göstermesin.
6. P0/P1 bulgularını “sıfır açık” iddiasıyla örtme; jüriye prototip sınırlarını söyle.
7. Gerçek puanların, test sonuçlarının ve canlı linkin tarihini belirt.

## Kaynaklar

- [DOA, iade sistemi kapsamı](https://doa.gov.tr/)
- [US EPA, malzemeye göre toplama bilgileri](https://www.epa.gov/recycle/how-do-i-recycle-common-recyclables)
- [US EPA, evde kompost](https://www.epa.gov/recycle/composting-home)
- [US EPA, elektronik bağışı ve geri dönüşümü](https://www.epa.gov/recycle/electronics-donation-and-recycling)
- [US EPA, kullanılmış piller](https://www.epa.gov/recycle/used-household-batteries)
- [US EPA, evsel tehlikeli atıklar](https://www.epa.gov/hw/household-hazardous-waste-hhw)
- [T.C. Dışişleri Bakanlığı, Sıfır Atık tanıtımı](https://www.mfa.gov.tr/site_media/html/sifir-atik/ek-3.pdf)
- [Bartın İl Müdürlüğü, bitkisel atık yağlar](https://bartin.csb.gov.tr/haberler/bitkisel-atik-yaglar-221056)
- [Kadıköy Belediyesi, tekstil toplama](https://cevre.kadikoy.bel.tr/icerik/tekstil-atiklari)
