# EcoVision final teslim kontrolu - 25 Ekim 2026

**Sonraki duzeltme:** `0cf8160` ile Render manifestindeki zorunlu AI_PROVIDER /
ML_ENABLED / GEMINI_ON_UNCERTAIN_ENABLED degerleri kullanici istegiyle kaldirildi.
Onceki rapordaki acik manifest varsayilani bu son surum icin gecerli degildir;
mevcut dashboard tercihi koddan okunamaz. Calisma agacindaki ONNX constructor
degisikligi de geri alindi. Sonraki cron adimlari ve gercek kontrol ciktilari:
[cron-keepalive-tr.md](cron-keepalive-tr.md).

Bu rapor yerel testleri canli Render dogrulamasindan ayirir. Eski raporlardaki
test sayilari veya ekran goruntuleri bu dagitimin canli kaniti degildir.

## Canli servis ve 503

- Dogrulanmis Git deposu: `https://github.com/BnymGnc/EcoVision.git`, dal `main`.
- Calisma baslangicinda yerel/uzak commit `de4d1db` idi. Yeni harita `/search`
  ve `/locations` yollari canli OpenAPI'de yoktu; eski `/{id}` yolu `search`
  metnini sayiya ceviremeyince 400 uretiyordu. Istemci uyumluluk duzeltmesi
  ve yeni sunucu endpoint'leri ayni teslimde korunur.
- Bu oturumda `/api/health` gercek `EcoVision Backend is awake!` govdesiyle
  200, `/actuator/health` `status=UP` yanitiyla 200 dondu. Bu anlik gozlem,
  daha onceki 26 adet 503'u veya kesintinin tekrarlamayacagini aciklamaz.
- Render panel/API yetkisi yok: Deploys, Events, Metrics, OOM ve calisan commit
  gorulmedi. 503'un kesin kok nedeni **belirlenemedi**. Onceki yerel ONNX
  bellek baskisi, production'da 137 oldugunun kaniti degildir.
- Panelden son basarisiz cron isteginin 10 dakika oncesi/sonrasi ve son deploy
  baslangicini kapsayan loglar gerekir: `OOM`, `Killed`, `137`, `OutOfMemoryError`,
  `HikariPool`, `PSQLException`, `SSL`, `Flyway`, `OrtException`, `Started`,
  `Tomcat started`, `BindException` ve yeniden baslama zamanlari aranmalidir.
  Paylasmadan once kimlik bilgilerini temizleyin.

## Degisiklikler

- Mevcut `/api/health` korunur; `/api/health/live` ayni bagimliliksiz canlilik
  yanitidir. GET ve govdesiz HEAD kimlik dogrulamasi gerektirmez.
- Actuator liveness yalniz `livenessState`; readiness `readinessState,db`
  kontrol eder. Veritabani arizasi readiness'te gizlenmez. Render manifestinin
  saglik yolu readiness'e ayrildi. Cron AI, import veya Neon sorgusu baslatmaz.
- Ilk teslimde eklenen zorunlu bulut ayarlari `0cf8160` ile geri alindi.
  Render manifesti artik AI saglayicisini zorlamaz; dashboard tercihi korunur.
  ONNX kodu/modeli silinmedi, istek basina model yukleme yok, paralel inference
  siniri 1 ve decode siniri 4 milyon piksel korunur.
- Ayni fotograf aciklamasi hesap basina tek odulle eslesti. AI sonucundaki
  kaldirilmis ambalaj formu metni yerine kabulun dogrulanmadigi belirtilir.
- Entegrasyon testlerinde null olabilen ID/govde/baslik degerleri kullanilmadan
  once acikca kontrol edilir; null uyarilari topluca kapatilmadi.
- Unicode Windows cikti yolu shader hatasi icin `scripts/build_web.ps1`
  ASCII gecici cikti kullanir; Android JDK/Gradle secimi degismedi.
- Onceki yerel duzeltmeler bu teslimde korunur: STOMP Principal, tek fotograf
  odulu, idempotent eski grup aktarimi, toplu gorev sorgusu, 81/973 katalog,
  tarama overlay tasmasi, 200 gorev kaydirma, sayfali harita uyumlulugu ve
  20 soruda istege bagli sayisal karbon girdileri (egitilmis ML degildir).

## Render paneli

Paneldeki degerler bilinmiyor; asagidakiler kod/manifest gereksinimleridir.

| Ayar / degisken | Mevcut panel biliniyor mu? | Gerekli deger/islem | Gerekce |
|---|---|---|---|
| Repository / branch | Repo dogrulandi, panel hayir | EcoVision / main | Portfolio deposu degil |
| Root directory / Dockerfile | Hayir | backend / ./Dockerfile | Maven build context |
| Health check path | Hayir | /actuator/health/readiness | DB hazirligini da kontrol et |
| PORT / bind | Kod dogrulandi | Render PORT; 0.0.0.0 | 8080'a sabitleme yok |
| SPRING_PROFILES_ACTIVE | Hayir | Semasi dogrulanmis DB'de prod | Hibernate validate; bos DB'ye korlemesine uygulama |
| SPRING_DATASOURCE_URL | Hayir | Mevcut Neon JDBC URL'sini koru | jdbc:postgresql, SSL parametreleri korunur |
| SPRING_DATASOURCE_USERNAME / PASSWORD | Hayir | Mevcut gizli degerleri koru | Neon verisini sifirlama |
| JWT_SECRET | Hayir | Mevcut guclu sirri koru | Gereksiz oturum iptali yapma |
| DB_POOL_MAX_SIZE / MIN_IDLE | Hayir | 5 / 0 | Kodun sinirli havuz varsayilanlari |
| DB_CONNECTION_TIMEOUT_MS | Hayir | 10000 | Sinirsiz havuz beklemesi yok |
| JAVA_TOOL_OPTIONS | Hayir | Asagidaki mevcut sinirli JVM ayari | Heap siniri toplam RSS garantisi degildir |
| AI_PROVIDER / ML_ENABLED | Hayir; manifest zorlamasi kaldirildi | Mevcut calisan secimi koru; 512 MB icin gemini/false olculmus alternatif | ONNX kapasitesi onaylanmadi, tercih gizlice degistirilmez |
| GEMINI_ON_UNCERTAIN_ENABLED | Hayir | Mevcut dashboard degeri; izinsiz acma | Otomatik bulut/farkli model zinciri acma |
| GEMINI_API_KEY | Hayir; yerel anahtar ornek | Gecerli mevcut sir gerekli | Ornek anahtar analiz yapamaz |
| GEMINI_MODEL | Panel hayir; gercek API sonucu biliniyor | gemini-3.6-flash canli tek fotograf denemesinde calisti | Kisa erisim testi kota/uptime garantisi degildir |
| GEMINI_CONNECT_TIMEOUT_MS / READ_TIMEOUT_MS | Hayir | 10000 / 60000 | Sinirli dis istek beklemesi |
| ML_MODEL_PATH | Hayir | ml/waste-mobilenet-v1.onnx (yerel motor kullanilacaksa) | Paketli modelin native bellegi heap disindadir |
| RVM_IMPORT_DRY_RUN | Hayir | Once true ile rapor; dogrulaninca false | Hash/UUID temelli upsert, silme yok |
| PUBLIC_BASE_URL | Hayir | https://ecovision-backend-wdr0.onrender.com | Kalici medya adresleri |
| UPLOAD_DIR | Hayir | /tmp/uploads | Gecici alan; kalici medya DB'de |
| CORS_ALLOWED_ORIGIN_PATTERNS | Hayir | Yayinlanan frontend origin'i | Web adresiyle eslestir |
| Frontend API_BASE_URL | Derleme dogrulanir | https://ecovision-backend-wdr0.onrender.com | Dart define; sir degildir |

Mevcut JVM tarifi:

```text
-Xmx128m -XX:MaxMetaspaceSize=112m -XX:MaxDirectMemorySize=16m -XX:ReservedCodeCacheSize=48m -XX:+UseSerialGC -Xss512k
```

GEMINI_MODEL adi degistirilerek kota yaratilamaz. Yerel `.env` ornek anahtar
iceriyor; gercek Render anahtari gorulmedi. [Resmi model kataloğu](https://ai.google.dev/gemini-api/docs/models)
ve o anahtarin `models.list` yaniti kontrol edilmelidir; ucretli kaynak/fallback acilmadi.

## Guvenli yonetici erisimi

Normal e-posta/parola girisi kullanilir. Mevcut yonetici parolasi bilinmiyor,
BCrypt'ten geri cikarilamaz; canli hesabin parolasi bu calismada degistirilmez.
Operatorun gizli parola istemli `AdminPasswordReset` araci ve tam komutu
[Render teslim belgesindedir](render-neon-delivery.md#existing-admin-recovery).
Islem var olan ADMIN/SUPERUSER icin transaction ve oturum iptaliyle calisir.
Juriye normal kullanici hesabi verilmelidir, yonetici veya veritabani sirri degil.

## Test ve dagitim kaydi

| Kontrol | Gercek sonuc |
|---|---|
| Java17 Docker build asamasi, `mvn -B -q test`, yerel PostgreSQL 15 | 41 sinif, 115 test, 0 hata/basarisizlik/atlama |
| Flutter `test --no-pub --concurrency=1 --reporter=expanded` | 133 test basarili, 239 sn |
| Dart `analyze lib test` | No issues found |
| `python -m unittest discover -s scripts -p test_locations_and_doa.py -v` | 11 test basarili; 81 il, 973 ilce, 4037 nokta |
| `scripts/build_web.ps1` | Release JS web paketi basarili; derleme 158,7 sn |
| Eclipse JDT batch, Java17 hedef + Spring nullAnnot/null analizi | PostgresCatalogIntegrationTest icin 0 uyari/hata |
| `docker build -t ecovision-final:local backend` | Gercek Dockerfile ile basarili; runtime Temurin17 JRE |
| Compose / promtool / amtool | Soz dizimi dogrulamalari basarili; 2 alarm kurali |

Ilk dogrudan Windows web derlemesi Unicode shader cikti yolunda basarisizdi;
ASCII ciktiyla tekrar denendi ve gecti. Ilk MockMvc HEAD testi Spring'in otomatik
HEAD govde davranisiyla uyusmadi; acik govdesiz HEAD rotasi eklenip tum testler
yeniden gecti. Windows bind mount'lu ilk Java testi yavaslik nedeniyle durduruldu;
bu yarim kosu basarili sayilmadi. Broker arizasi regresyonu kasitli ERROR logu
uretir, test sonucu basarilidir. WebAssembly dry-run eklenti uyumsuzlugu bildirir;
uretilen ve dogrulanan paket JS release'tir, WASM degildir.

512 MiB/1 CPU, Java 17.0.20.1 JRE, prod/validate ve `PORT=19081` ile gercek
uretim imaji acildi. Tomcat 0.0.0.0:19081 uzerinde; baslangic 126,062 sn.
GET liveness/readiness 200; gercek HTTP HEAD 200 ve 0 govde byte'i. Alti
migration dogrulandi; `syntax error at or near default` gorulmedi.

`python scripts/check_final_capacity.py` gercek ONNX modeliyle ilk fotografi,
12 ardisik fotografi, 5 harita istegini ve 3 eszamanli fotografi denedi.
Ilk sonuc 4819 ms; ardisik analizler 404-2567 ms. Eszamanli 3 istegin biri
200, ikisi mevcut semaphore geri basinciyla 503: uc analizin birden basardigi
iddia edilmez. Peak **536.989.696 byte (~512,1 MiB)**; `memory.events max=75`,
`oom=0`, `oom_kill=0`. Surec sag kaldi ama guvenli bosluk yoktur. Sonuc:
**512 MB'de ONNX production kapasitesi onaylanmadi**. Bu, Render kesintisinin
kaniti degildir. Bulut modu ayrica denendi: baslangic/giris/10 harita istegi
tepe bellegi 396.128.256 byte (~377,8 MiB), `oom=0`. Bu yerel kosuda gercek
Gemini anahtari verilmedi; fotograf isteginin bulut bellek tepesi olculmedi.
Kayit: [bulut kapasite JSON](final-cloud-verification.json).
Makine ogrenmesi kapatilirsa bunun kullaniciya gizlenmesi onerilmez; saglayici
sonucta acikca gosterilir. Olcum: [JSON](final-capacity-verification.json).

Incelenen staged dosyalarda saglayici-token/private-key kaliplari bulunmadi;
`.env`, yerel `constants.dart`, anahtar/keystore ve APK'lar commit'e alinmaz.
Kullaniciya ait ek kaynak disa aktarimlari ve incelenmemis K8s dosyalari yerelde
korunur, bu degisiklige dahil edilmez. Canli Neon semasi/verisi sifirlanmadi.

Kod commit'i **1ea9781b9960261ecf5b51f22e98910a2794fc91** normal push ile
`BnymGnc/EcoVision` uzak `refs/heads/main` dalina gonderildi; bagimsiz GitHub
ref API'si ayni SHA'yi dogruladi. GitHub Actions [40183520645](https://github.com/BnymGnc/EcoVision/actions/runs/40183520645)
basarili: JDK17, backend testleri, Docker build ve Docker Hub push adimlarinin
tamami success. Bu Render deploy kaniti degildir. Push sonrasinda canli eski
`/api/health` 200 iken yeni `/api/health/live` 401 dondu; yeni guvenlik/endpoint
surumu henuz gozlenmedi. Render'in izledigi dal, deploy sonucu ve calisan SHA
panelden dogrulanmalidir; otomatik deploy'un acik oldugu varsayilmadi.

Gercek yerel DB arizasi denemesinde PostgreSQL durduruldu: `/api/health/live`
200, `/actuator/health/readiness` 503 dondu. DB yeniden baslatildi. Boylece
liveness'in arizayi ortbas eden bir readiness yerine kullanilmadigi dogrulandi.

## Cron ve juri teslimi

Mevcut canli yaniti dogrulanan cron adresi:
`https://ecovision-backend-wdr0.onrender.com/api/health/live`.
GET, 5 dakika aralik, kimlik dogrulama ve Authorization basligi yok.
cron-job.org hesabi yeniden etkinlestirilmedi; panel erisimi yoktur.
Cron bir uyandirma istegidir; DB/AI hazirliginin veya 503 kok nedeninin cozumu degildir.

Son kisa kontrolde ilk uc GET 30 saniyede zaman asimina ugradi, sonra HEAD
200 dondu. Isinmis serviste uc GET ve bir HEAD 200/gercek govdeyle dogrulandi.
Iki sonuc da saklandi; ilk basarisizliklar silinmedi. Cron e-postasi eski
`/api/health` icin 25 Ekim 08:10:21 UTC'de 503 ve 26 hata bildiriyor.
Render Events/Logs olmadan bunun OOM veya belirli bir commit kaynakli oldugu
soylenemez. [Gorev ayari ve log araligi](cron-keepalive-tr.md).

Canli kabul API denemesinde liveness/readiness, normal kayit/giris, ayni hesap
kimligi, sayfali harita ve gercek fotograf analizi 200 dondu. Saglayici GEMINI,
model `gemini-3.6-flash`, sonuc CAM, CLOUD modu. Envanterde 4037 siniflandirilmis
noktaya ek olarak silinmemis 138 UNKNOWN eski kayit var: toplam 4175. API
denemesi tam tarayici/GPS/yol tarifi testi degildir. [Kayit](final-live-verification.json).

Son JWT izolasyonu icin 7 odakli test 0 hata/basarisizlikla gecti (JBR21,
Java17 hedefi). Java17/PostgreSQL 115 testlik onceki kosudan ayri kayittir.
Android release derlemesinin gercek `Metaspace` hatasi, yalniz Gradle derleme
surecinin metaspace sinirini 384'ten 768 MiB'ye cikararak giderildi. Runtime
JVM, Gradle/JDK surumleri ve uygulama mantigi degismedi. Yeni ARM64 release
APK 27.563.298 byte, SHA256:
`42906765f1bde3c6614abc2a30379ef393e854860998a85330a7b28bd109b9b5`.
Projenin mevcut debug anahtariyla imzalidir; magazaya hazir imzali surum degildir.
GitHub Releases yayini kullanici tarafindan ayrica onaylandi; indirme dogrulamasi
sonrasinda baglanti asagidaki teslim notuna eklenecektir. Swagger uygulama
frontend'i degildir; yerel Brave adresi internetten acilabilen bir urun linki degildir.
