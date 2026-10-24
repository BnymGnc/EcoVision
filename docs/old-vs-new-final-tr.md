# Son sürüm: önce / sonra

Tarih: 24 Ekim 2026. Buradaki “sonra” yerel kaynak değişikliğidir; canlı deployment
iddiası değildir. Önceki kapsamlı envanter: [features-and-changes-tr.md](features-and-changes-tr.md).

| Modül | Önce | Sonra | Teknik uygulama | Kullanıcıdaki fark | Doğrulama |
|---|---|---|---|---|---|
| Özel profil fotoğrafı | Bilinen URL anonim alınabiliyordu | Güncel gizlilik/arkadaşlık/yaş kontrolü | MediaAccessService, sahip metadata'sı, domain referansı | Gizli fotoğraf yabancıya açılmaz | PostgreSQL HTTP matrisi |
| Grup/PDF medyası | UUID erişimi yeterliydi | Güncel üyelik veya moderasyon yetkisi | Aynı GET'te dinamik grup/etkinlik ACL | Gruptan çıkınca dosyayı yeniden alamaz | Üye çıkarma ve yabancı testi |
| Medya cache | Public immutable | Private no-store | Response header + istemci bellek temizliği | Hesap değişiminde önceki medya görünmez | Header, account-switch testleri |
| Görsel yükleme | Boyut ve imza ağırlıklı | Boyut/imza + piksel header sınırı | JPEG/PNG ImageIO, WebP header | Aşırı çözünürlük reddedilir | Bozuk/piksel testleri |
| Profil/kapak kalıcılığı | DB bytea | Korundu | Medya verisi taşınmadı/silinmedi | Yeniden girişte kayıt aynı kalır | Gerçek yükleme + sonraki GET |
| Belge indir | İzinsiz harici URL açma | Yetkili indirme ve platform kaydetme | ApiService + FilePicker | PDF erişimi üyeliğe bağlı | HTTP ACL; native kaydetme ayrıca saha testi ister |
| Oturum çıkışı | Refresh iptali; access süre sonuna kadar kalabilirdi | Gönderilen access token da iptal edilir | Hash denylist, yeni JWT jti | Eski özel medya isteği reddedilir | Logout replay testi |
| Paralel token yenileme | Birden fazla refresh olabilirdi | Single-flight + sıralı storage | ApiService oturum nesli | Çıkış gecikmiş refresh ile geri alınmaz | İstemci yarış testleri |
| Akademi notu | İstemci 2/3 kontrolü | Sunucu sürüm ve 2/3 kontrolü | Sürümlü JSON katalog, answers payload | Eksik/eski sınav ödül alamaz | 0/1/2/3 ve sürüm testleri |
| Akademi ödülü | Tek-sefer kilidi vardı, başarı kanıtı yoktu | Geçerli sınavdan sonra aynı tek-sefer kilidi | Transaction ve idempotent gamification | İki istek tek ödül | Eşzamanlı completion |
| Akademi içeriği | 10 modül / 30 soru | Aynen korundu | İstemci/sunucu katalog tutarlılık testi | Kaynaklı rehber ve arama devam eder | JSON/model/UI testleri |
| Eski label taraması | Fotoğrafsız XP verebiliyordu | Kayıt var, XP sıfır | Legacy wrapper güvenli yol | Eski istemci puan suistimal edemez | HTTP + servis testi |
| Görsel tarama | Aynı dosya tekrar ödül verebiliyordu | Kullanıcı/gün/hash tek ödül | Row lock, partial unique index, analysisId | Sonuç gösterilir, tekrar ödül verilmez | Paralel scan + UI durum alanı |
| DOA düğmesi | Doğrudan harita | Korundu | ResultScreen onFindBins | Ek form yok, konum reddinde gizlenmez | Result widget testleri |
| DOA verisi | 4.037 snapshot ve UUID import | Korundu | Aynı manifest/raw katalog | Veri kaybı veya sahte makine eklenmedi | Import/idempotency/Şanlıurfa testi |
| DOA durum dili | Destek bazen kabul sanılabiliyordu | Destek ve true/false/unknown ayrı | MapPin binStates + açıklayıcı metin | Canlı kabul sanılmaz | Model ve harita görüntüsü |
| Sınırsız mesafe | Sonuç limitini gizleyebiliyordu | 500/viewport sınırı açıklanır | Mevcut backend sınırı korunur | “Bütün ülke aynı ekranda” yanılgısı azalır | UI metni / API limit sözleşmesi |
| Grup sohbeti | Sağlıklı STOMP ile 8 sn HTTP tekrarları | 8 sn fallback; bağlıyken daha seyrek uzlaşma | Tek in-flight, 48 sn reconciliation, lifecycle | Daha az gereksiz veri ve arka plan trafiği | Yavaş API/lifecycle widget testi |
| Sekmeler | İlk açılışta hepsi mount oluyordu | İlk ziyaretinde mount | Lazy IndexedStack | Başlangıçta gereksiz harita/profil isteği yok | Unvisited tab testi |
| Bildirimler | Arka planda 15 sn sorgu | Arka planda durur, dönüşte yenilenir | Lifecycle + in-flight guard | Daha az ağ/pil tüketimi | Lifecycle kodu ve regresyon |
| Karbon | 20 soru + opsiyonel yakıt/elektrik | Korundu | Aynı hesap motoru | Yeni veri girişi zorunlu değil | Mevcut karbon testleri |
| Görevler/seriler | 200 görev, ayrı giriş/tarama | Korundu | Katalog/kodlar değiştirilmedi | İlerlemeler sıfırlanmaz | Catalog/claim/seri testleri |
| Market/avatar | Puan harcama ve 20 seviye | Korundu | Mevcut model/API | Fotoğraf-avatar tercihi aynı | Mevcut regresyon |
| Sosyal/moderasyon | Arkadaş, rol, grup, rapor, STOMP | Korundu | Modeller ve topic'ler değiştirilmedi | Yeni özel mesaj veya sosyal modül yok | Mevcut servis testleri |
| Tema/tanıtım | Hesap teması ve dört sayfa | Korundu | Mevcut notifier/preferences | Görsel tasarım yeniden yazılmadı | Tema/login testleri |
| Teslim | Testli yerel kaynak | Yeni güvenlik testleri ve raporlar | Additive V6, gerçek build kanıtı | Yayına alınması ayrıca gerekir | Test JSON ve deploy rehberi |

Quiz cevapları istemci asset'inde de bulunduğu için kötü niyetli kullanıcı doğru
cevapları okuyabilir. Hash politikası fiziksel ambalajı doğrulamaz. Bu sınırlamalar
“anti-cheat tamamen çözüldü” diye gizlenmez.
