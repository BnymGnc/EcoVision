# 26 Ekim 2026: cron 503 ve yeniden baslama incelemesi

## Kanitlar

Saat donusumleri Europe/Istanbul (UTC+3) uzerindendir.

| UTC | Turkiye | Gozlem |
|---|---|---|
| 25 Ekim 20:35:48 | 25 Ekim 23:35:48 | Eski logda uygulama 264,397 saniyede basladi; Neon baglantisi ve 7 migration basarili. |
| 26 Ekim 16:20:16 | 26 Ekim 19:20:16 | Shutdown hook, STOMP durusu, EntityManager ve Hikari'nin duzenli kapanisi. |
| 26 Ekim 18:15:25 | 26 Ekim 21:15:25 | Cron e-postasi: HTTP 503, 26 ardisik hata, gorev kapatildi. |
| 26 Ekim 18:22:23 | 26 Ekim 21:22:23 | Bu incelemedeki ilk sinirli dis liveness istegi. |
| 26 Ekim 18:22:56 | 26 Ekim 21:22:56 | Paylasilan yeni logda Java 17 uygulama baslangici. |
| 26 Ekim 18:24:27 | 26 Ekim 21:24:27 | Hibernate kurulumu halen devam ediyor; acilis henuz tamamlanmamis. |
| 26 Ekim 18:29:28 | 26 Ekim 21:29:28 | Canli GET 200, dogru uygulama govdesi, 2586 ms. |
| 26 Ekim 18:29:58 | 26 Ekim 21:29:58 | Canli GET 200, dogru govde, 961 ms. |
| 26 Ekim 18:30:29 | 26 Ekim 21:30:29 | Canli HEAD 200, bos govde, 369 ms. |

Ilk kontrollerde 30-35 saniye zaman asimi alindi. curl olcumunde TCP 69 ms,
TLS 147 ms'de kuruldu ama 35 saniyede ilk HTTP bayti gelmedi. Yalniz DNS
veya istemcinin JSON ayracina bagli bir hata degil.

## Kok neden konusunda bilinen ve bilinmeyen

- Servisin duzenli kapandigi ve cok daha sonra yeniden basladigi kanitli.
  Bu kesitte SIGKILL/137/OOM veya basarisiz Flyway kaniti yoktur.
- Yeni baslangicin dis kontrol isteginden hemen sonra gorulmesi, uyku/durdurma
  ve soguk baslangicla uyumludur; tek basina platformun kapatma nedenini kanitlamaz.
- Kesin ayirim icin Render Events'te 16:20 UTC kaydi gerekir: spin-down,
  manuel stop/restart, deploy, saglik hatasi veya askida/kota durumu.
- Bes WebSocket transport hatasi gecmisteki baglantilarin sayacidir; o andaki
  aktif oturum ve kuyruklar sifirdir. Bunlar tek basina sunucu crash kaniti degildir.
- Cronun 30 saniyelik butcesi, paylasilan 264 saniyelik baslangictan kisa.
  Ancak 26 ardisik hatayi yalniz bir soguk baslangica baglamak dogru degildir.
  Cronun gercek gecmisi/zamanlamasi ve Render Events birlikte incelenmelidir.

## Kod incelemesi

`/api/health/live` GET/HEAD, kucuk ve public liveness'tir. JWT filtresi bu
yolda atlanir; Neon, AI, seed, model yukleme veya dis HTTP istegi yoktur.
Readiness ayri olarak DB'yi kontrol etmeye devam eder. Saglik hatalari
gizlenmedi, sahte proxy 200 yaniti eklenmedi, uygulama icine self-ping timer'i konmadi.

Gemini onbellegi 64 kayit/10 dakika ile sinirli; analiz eszamanliligi 1.
Yerel model bir kez yuklenir; ONNX arena/memory-pattern kapali, inference
tensor/result kaynaklari kapatilir. Bu inceleme bir bellek sizintisi
tespit etmedi; Render Memory grafigi olmadan sizinti/OOM dislanmis da sayilmaz.

## Yapilan sinirli iyilestirmeler

- Docker runtime'ina daha once yalniz `render.yaml` icinde bulunan JVM bellek
  varsayilanlari eklendi. Manuel olusturulmus Render servislerinde de gecerli
  olurlar; panelde tanimli `JAVA_TOOL_OPTIONS` bunlari ezer.
- `-XX:TieredStopAtLevel=1`: baslangicta JIT maliyetini azaltmak icin C1 ile
  sinirlar. Uzun sureli Java CPU throughput'u etkilenebilir; bu, Render'in
  uyku politikasini degistirmez veya her baslangici 30 saniyeye indirme vaadi degildir.
- `-XX:+ExitOnOutOfMemoryError`: heap/metaspace OOM'da hatali JVM'nin yarim
  canli kalmasini engeller. OOM olusmasini onlemez veya native/cgroup SIGKILL'i cozmez.
- AI saglayicisi, model, Neon verisi, guvenlik kurallari ve API davranisi
  degistirilmedi. Yerel model sessizce kapatilmadi; ucretli fallback acilmadi.
- Kontrol betigi artik sinirli hata govdesi ve secilmis altyapi basliklarini
  kaydeder. Cookie/Authorization kaydetmez. `--output` ile eski raporlar korunabilir.
- HTML 200 acilis sayfasi, uygulamanin gercek liveness basarisi sayilmaz.

## Cron ve Render ayarlari

Cron URL'si ayni kalir: `https://ecovision-backend-wdr0.onrender.com/api/health/live`.
GET, 5 dakika (`*/5 * * * *`), Authorization/Cookie yok. Cron hesabinda
once Test calistirip gercek 200 gorun; sonra kapatilan gorevi etkinlestirin.
Bu calismada cron-job.org veya Render panel hesabi degistirilmedi.

Render platform health check: `/actuator/health/readiness`; uygulama
`PORT` degerini okur ve `0.0.0.0` uzerinde dinler. Eski logdaki port 10000
dogrudur. `Tomcat initialized` portun dis trafige hazir oldugu anlamina gelmez.

Render'da acik `JAVA_TOOL_OPTIONS` varsa yeni Docker varsayilani uygulanmaz:

```text
-Xmx128m -XX:MaxMetaspaceSize=112m -XX:MaxDirectMemorySize=16m -XX:ReservedCodeCacheSize=48m -XX:+UseSerialGC -Xss512k -XX:TieredStopAtLevel=1 -XX:+ExitOnOutOfMemoryError
```

Free instance 15 dakika trafik gelmeyince uyuyabilir; platform yeniden
baslatabilir veya kota nedeniyle askiya alabilir. Ping bunlari garantiyle
engellemez. Uyku kaynakli kesintilerin ortadan kalkmasi gerekiyorsa uyumayan
bir compute plani veya surekli acik bir sunucu gerekir. Ucretli plan degisikligi yapilmadi.

Kaynaklar:
- https://render.com/docs/free
- https://render.com/docs/health-checks
- https://cron-job.org/en/faq/

## Dogrulama

`python -m unittest discover -s scripts -p test_keepalive.py -v`: 5/5 basarili.
Canli kisa gozlem: [keepalive-2026-10-26.json](keepalive-2026-10-26.json).
Bu, uzun sureli uptime veya cron gorevinin etkinlestirildigi kaniti degildir.
Uretim baslangic karsilastirmasi yerel izole PostgreSQL ile ayrica kaydedilir.

### Tamamlanan yerel runtime karsilastirmasi

Guncel kaynakli JAR Java 17 Maven `package -DskipTests` ile paketlendi.
Ayni JAR mevcut Temurin 17 runtime imaji uzerinde, 512 MiB cgroup ve 1 CPU
ile calistirildi; PostgreSQL 15 yalniz izole yerel test veritabaniydi.
Iki asamali Dockerfile'in sifirdan ag uzerinden yeniden indirilmesi yerine
onbellekli Maven/runtime katmanlari kullanildi. Render CPU/Neon ag kosullari
taklit edilmedi; bunlar Render olcumu degildir.

| Mod | Readiness UP (sn), 2 tekrar | Ortalama (sn) | Ortalama tepe bellek |
|---|---|---|---|
| Onceki JVM ayarlari | 149,292 / 179,019 | 164,156 | 384,55 MiB |
| C1 + fail-fast OOM | 75,942 / 74,039 | 74,991 | 312,63 MiB |

Bu kucuk yerel orneklemde ortalama hazir olma suresi yaklasik %54 azaldi.
Sirasiyla calisan JVM'ler dosya onbellegini paylasir; uzun sureli throughput
veya istatistiksel SLA sonucu degildir. Soguk baslangic halen cronun 30 saniye
butcesini asabilir.

Yerel model acik ayri deneme: readiness 107,717 sn; uc gercek ONNX cagrisi
HTTP 200 / provider `ONNX_CPU`; tepe 406,61 MiB / 512 MiB.
Bes runtime denemesinde GET/HEAD ve readiness kontrolleri gecti;
`memory.events` icinde `oom=0`, `oom_kill=0`, `max=0` goruldu.
Bu kisa denemeler uzun sureli bellek sizintisi veya Render OOM riskini dislamaz.
Gemini veya ucretli AI cagrisi yapilmadi.

Ayrintilar: [runtime olcumleri](startup-reliability-2026-10-26.json).
Sonraki canli readiness kontrolu 26 Ekim 18:42:32 UTC / 21:42:32 Turkiye:
HTTP 200, `{"status":"UP"}`. Bu, JVM degisikliginin henuz canliya gectigini
kanitlamaz; o anki servisin DB dahil hazir oldugunu gosterir.

`python -m unittest discover -s scripts -p 'test_*.py' -q`: **16/16 basarili**
(5 probe teshis testi + 11 konum/DOA veri testi). Docker/Render YAML JVM
degerlerinin eslesmesi, readiness yolunun ve Free planin degismedigi de
dogrulandi. Uygulama Java kaynaklari degismediginden onceki 128 JUnit sonucu
bu adimda yeniden kosulmus gibi sunulmuyor; runtime HTTP/AI testleri yukaridadir.

Gonderim oncesi son kontrol, 26 Ekim 18:50 UTC / 21:50 Turkiye:
GET 200 / 916 ms ve HEAD 200 / 339 ms; dogru uygulama govdesi.
[Son kontrol](keepalive-2026-10-26-final.json). Cron hesabi yeniden
etkinlestirilmedi; hesap/panel erisimi yoktur. Yeni JVM ayarinin Render'da
etkin olmasi deploy ve varsa mevcut `JAVA_TOOL_OPTIONS` override'ina baglidir.
