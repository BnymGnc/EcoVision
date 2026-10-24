# Dağıtım hazırlığı ve geri dönüş

Tarih: 24 Ekim 2026. Git push, Render deploy, canlı Neon migration, kullanıcı
verisi temizliği veya APK kurulumu bu çalışma kapsamında otomatik yapılmaz.
Son kullanıcı mesajı Git commit/push için ayrıca izin verdi; bu gönderim
Render'da auto-deploy açıksa platform dağıtımını tetikleyebilir. Bu belge
canlı endpoint'lerin doğrulandığı anlamına gelmez.

## Kod ve paket

Backend Java 17 / Spring Boot 3; Render root `backend`, Dockerfile `./Dockerfile`,
health `/api/health`. Port `PORT` ortamından, bind adresi `0.0.0.0`.
Yeni V6 migration ve `education/academy-quiz-v1.json` JAR'a girmelidir.
ONNX, model metadata/lisansları ve ham DOA/manifest korunmalıdır.

```powershell
cd backend
$env:ECOVISION_TEST_JDBC_URL='jdbc:postgresql://127.0.0.1:25439/ecovision_test'
.\mvnw.cmd clean verify
```

Bu URL yalnız yerel, ayrı test DB'sidir. Üretim URL'sini test değişkenine yazmayın.

## V6 ve mevcut Neon

Migration yalnız additive'dir: medya yükleyeni için nullable owner ID;
scan analysisId/hash/rewardDate/rewardStatus; yeni revocation tablosu;
analiz UUID ve günlük ödüllü hash için unique index. Eski tarama değerleri,
medya bytes, kullanıcı bakiyeleri ve akademi ilerlemeleri değiştirilmez.

Büyük scan_history tablosunda index inşası yazmaları bekletebilir; önce staging
ve tablo boyutunu değerlendirin, veritabanı yedeği alın. Migration'ı production
HTTP isteğinden veya test scriptinden başlatmayın. Deploy sırasında Flyway
mevcut migrasyonları doğrular ve V6'yı uygular; eski V1–V5 dosyalarını değiştirmeyin.

Mevcut şema tamamlandıysa `SPRING_PROFILES_ACTIVE=prod` validate kullanır.
Sıfırdan DB'de eski migration'lar tam entity baseline'ı kurmaz; otomatik
“prod ile boş DB çalışır” iddiası yoktur. Boş staging'i kontrollü default
bootstrap ile oluşturup gerekli index/migration durumunu doğrulamadan prod'a geçmeyin.

## Ortam değişkenleri

| Ad | Gereklilik | Gizli | İşlem |
|---|---|---|---|
| SPRING_DATASOURCE_URL | Zorunlu | Hassas | Mevcut SSL'li Neon JDBC değerini koru |
| SPRING_DATASOURCE_USERNAME / PASSWORD | Zorunlu | Evet | Paneldeki mevcut değerler |
| JWT_SECRET | Zorunlu | Evet | Mevcut yeterince uzun anahtarı koru |
| SPRING_PROFILES_ACTIVE | Mevcut prod için | Hayır | Şema hazırsa prod |
| PORT | Render sağlar | Hayır | Elle sabitleme |
| DB_POOL_MAX_SIZE / DB_POOL_MIN_IDLE | İsteğe bağlı | Hayır | 5 / 0 |
| DB_CONNECTION_TIMEOUT_MS | İsteğe bağlı | Hayır | 10000 |
| AI_PROVIDER | Motor seçimi | Hayır | Varsayılan gemini |
| GEMINI_API_KEY | Bulut için | Evet | Gerçek anahtarı yalnız panelden doldur |
| GEMINI_MODEL | Bulut için | Hayır | Hesabın erişebildiği modeli doğrula |
| ML_ENABLED | Yerel model için | Hayır | Varsayılan false; bellek testi olmadan true yapma |
| ML_MODEL_PATH | İsteğe bağlı | Hayır | ml/waste-mobilenet-v1.onnx |
| GEMINI_ON_UNCERTAIN_ENABLED | İsteğe bağlı | Hayır | false; ücretli otomatik geçiş eklenmedi |
| GEMINI_CONNECT_TIMEOUT_MS / READ_TIMEOUT_MS | İsteğe bağlı | Hayır | 10000 / 60000 |
| JAVA_TOOL_OPTIONS | Örnek bellek sınırı | Hayır | Mevcut 128m heap / 112m metaspace reçetesi; gerçek RSS ölç |
| JWT_EXPIRATION_MS / JWT_REFRESH_EXPIRATION_MS | İsteğe bağlı | Hayır | 900000 / 2592000000 |
| CORS_ALLOWED_ORIGIN_PATTERNS | Web için | Hayır | Yayındaki istemci origin'leriyle daralt |
| RVM_IMPORT_DRY_RUN | Preview için | Hayır | Önce true ile logu incele; uygulamak için false |
| PUBLIC_BASE_URL | Dağıtım için | Hayır | Kendi gerçek HTTPS adresin |
| UPLOAD_DIR | Eski/temp ayarı | Hayır | /tmp/uploads; kalıcı medya artık DB'de |

İlgili ayrıntılı tablo: [render-neon-delivery.md](render-neon-delivery.md).
Yeni güvenlik özellikleri için yeni gizli anahtar gerekmiyor.

## APK / web uyumu

Yeni backend, cevap göndermeyen eski sınav istemcisine 426 verir; legacy label
tarama sıfır XP döndürür. Özel medya auth header gerektirir. Güncel Flutter'ı
aynı sürüm penceresinde dağıtın; güvenlik kontrolünü kaldırarak eski APK'yı
“uyumlu” hale getirmeyin.

```powershell
cd frontend
flutter pub get
flutter test --no-pub
flutter build web --dart-define=API_BASE_URL=https://<backend-host>
flutter build apk --debug --dart-define=API_BASE_URL=https://<backend-host>
```

constants.dart yoksa örnek dosyadan oluşturun; API anahtarı koymayın.
Android release yapılandırması halen debug signing kullanıyor. Bu değişiklik
App Store/Play Store imzalı yayın hazırlığı değildir; applicationId ve release
keystore ayrı, kontrollü iş olmalıdır. APK üretmek kurmak/yayınlamak anlamına gelmez.

24 Ekim son doğrulaması: ARM64 debug APK, 201,7 sn Gradle derlemesiyle başarıyla
üretildi; çıktı `frontend/build/app/outputs/flutter-apk/app-debug.apk` (97.252.091
byte, Git dışında). Türkçe karakterli Windows çıktı yolundaki shader aracı
sınırlaması için ASCII geçici kopya kullanıldı. Bu kopya anahtarsız
constants.example.dart ile derlendi, API mevcut Render URL'sine gider. Kaynak
proje ve SDK taşınmadı; global build-dir değiştirilmedi. Native gerçek cihaz
medya kaydetme/GPS/oturum testi ayrıca yapılmalıdır.

## Sıra ve smoke

1. Yedek + staging'de aynı V6.
2. Backend health, startup migration, gerçek login ve protected media matrisi.
3. Yeni web/APK: gerçek fotoğraf, provider/sınır, rehber, doğrudan harita ve yol tarifi.
4. Quiz notu, tek ödül, çıkış sonrası JWT replay, arkadaş/üye çıkarma.
5. Render heap + native RSS, p95, 429/503/timeout oranlarını izle.

Yeni Java 17 smoke testinde cgroup peak 537.321.472 byte, bellek sınırına temas
sayacı 146, OOM/kill 0 idi. Bu yalnız kısa, ardışık yerel testtir; 512 MiB ONNX
kapasitesi güvenli kabul edilmedi. Daha fazla bellek veya ölçülmüş bulut modu
değerlendirin. Eski 476 MiB ölçümü yeni sürümün garantisi değildir. Varsayılan
`AI_PROVIDER=gemini`, `ML_ENABLED=false` değiştirilmedi. Status 137'nin kesin
sebebi ayrıca platform OOM/restart kayıtlarından doğrulanmalıdır.

## Geri dönüş ve açık riskler

V6 alanlarını veya medya/puan kayıtlarını silmeyin; eski binary bu additive
alanları görmezden gelebilir. Ancak eski backend'e dönüş P0/P1 açıklarını yeniden
açar. Bu yüzden acil durumda eski APK'yı güvensiz endpoint'e açmak yerine
ilgili işlemi geçici kapatıp ileri düzeltme tercih edilir. Flyway history'yi
elle silmek veya applied migration içeriğini düzenlemek rollback değildir.

Eski public cache/download kopyaları geri alınamaz. Eski /uploads dosyalarının
güvenli DB geçişi ayrı iş ister. Çok replikalı STOMP simple broker gerçek bir
ortak broker değildir; yeni Kafka/RabbitMQ kurulmadı. Tek Render instance'ı ile
test edilen akış iki replika için aynı gerçek-zaman garantisi vermez.

Görev N+1 sorguları, bütün aktif kullanıcıları tek listede alan scheduler,
distributed scheduler kilidi ve scan-history cursor pagination bu son turda
uygulanmadı. UI/API sözleşmesi ve çok-instance yarış testleriyle ayrı ele alınmalı.
