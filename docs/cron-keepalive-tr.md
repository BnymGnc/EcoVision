# EcoVision - cron-job.org canlilik kontrolu

## 26 Ekim guncellemesi

Yeni olay, kapanis/baslangic zamanlari ve gercek toparlanma olcumleri:
[26 Ekim olay incelemesi](incident-2026-10-26-tr.md).
26 Ekim 21:29-21:30 Turkiye saatinde iki GET ve bir HEAD dogru govdeyle
200 dondu; bu, 7/24 uptime garantisi veya cron gorevinin tekrar acildigi anlamina gelmez.
Asagidaki 25 Ekim olcumleri tarihsel kayit olarak korunmustur.

## Gorev ayari

| Alan | Deger |
|---|---|
| URL | https://ecovision-backend-wdr0.onrender.com/api/health/live |
| Method | GET |
| Zamanlama | Her 5 dakika (`*/5 * * * *`) |
| Saat dilimi | Europe/Istanbul |
| Authentication | Kapali |
| Authorization / Cookie | Gonderilmemeli |
| Istek govdesi | Bos |
| Beklenen sonuc | HTTP 200 ve `EcoVision Backend is awake!` |
| Hata / toparlanma bildirimi | Acik |

Mevcut gorevi duzenleyin; ikinci bir ayni gorev acmayin. URL'yi kaydettikten
sonra test calistirmasi yapin. Basarili uygulama yanitini gordukten sonra daha
once otomatik kapatilan gorevi **yeniden etkinlestirin**. Bu depodaki kodun
push edilmesi cron-job.org hesabindaki devre disi gorevi yeniden acmaz.
Bu calismada cron-job.org hesap erisimi veya gorev degisikligi yapilmadi.

## 26 hata neden gorevi kapatti?

cron-job.org, 25'ten fazla ardisik basarisizlikta gorevi otomatik kapatabildigini
belirtiyor. 26 adet hata bu davranisla tutarlidir; hatalarin asil sebebini
aciklamaz. Basarisizlik ve devre disi kalma e-posta bildirimlerini acin.

Kullanicinin paylastigi e-postadaki son deneme **25 Ekim 2026 08:10:21 UTC
(11:10:21 Turkiye)**, eski `/api/health` adresi, HTTP 503 ve 26 ardisik
basarisizliktir. Render loglari icin 08:00-08:20 UTC araligini isteyin.

Kaynak: https://cron-job.org/en/faq/

## Liveness ve readiness ayni degil

- `/api/health/live` ve eski `/api/health`: kucuk, GET/HEAD destekli liveness.
  AI, harita, import veya Neon sorgusu baslatmaz.
- JWT filtresi yalniz bu public GET/HEAD yollarinda atlanir. Hatali/eskimis
  bir Authorization basligi bile probe'u veritabani islemine donusturmez.
  Diger API yollarinda kimlik denetimi ve uyelik kurallari korunur.
- `/actuator/health/readiness`: uygulama hazirligi ve DB baglantisi; DB arizasi
  burada 503 olarak kalir. Cron adresi olarak kullanilmaz.
- Render health check path: `/actuator/health/readiness`. Bu platform ayaridir,
  cron-job.org URL'sinden farklidir. Calismayan DB'yi saklamak icin degistirilmedi.

## Ping neyi yapamaz?

Render Free, 15 dakika giren trafik yoksa uyuyabilir; sonraki istek servisi
baslatir. Fakat servis yeniden baslayabilir veya kotadan askiya alinabilir.
Duzenli istek; OOM, yanlis ortam degiskeni, basarisiz deploy veya kota sorununu
cozmez. Cronun varsayilan yaklasik 30 saniyelik istegi, daha uzun cold start
tamamlanmadan zaman asimina ugrayabilir. Basarisiz cold start'i 200 gibi
gosteren sahte bir endpoint eklenmedi; sifir hata veya 7/24 SLA vaat edilmiyor.

Kaynaklar:
- https://render.com/docs/free
- https://blog.cron-job.org/service/2021/12/01/errors-explained-timeout.html

## Tekrarlanabilir kontrol

```powershell
python scripts/check_keepalive.py --samples 3
```

Onceki raporu degistirmeden ve sorgular arasinda bekleyerek kontrol:

```powershell
python scripts/check_keepalive.py --samples 2 --interval 30 --output docs/keepalive-new-check.json
```

Betik hata yanitinin en fazla 256 baytini ve sinirli altyapi basliklarini
kaydeder; 503 veya zaman asimini basariya cevirmez. Cookie/Authorization
gondermez veya kaydetmez. `--timeout` yalniz yerel teshis betiginin butcesidir;
cron-job.org sunucularinin 30 saniyelik butcesini degistirmez.

Varsayilan 3 GET ve 1 HEAD istegi, her biri 30 saniye sinirli. Sir gondermez.
Sonuc `docs/keepalive-verification.json` dosyasina yazilir. Basarisiz olursa
exit code 1 doner; hata gizlenmez. Kisa kontrol, uzun sureli uptime kaniti degildir.

## Sunucu yine yanit vermiyorsa

Render panelinde ayni saatin Events/Logs/Memory grafigini kontrol edin.
`137`, `OOM`, `Killed`, `OutOfMemoryError`, `PSQLException`, `HikariPool`,
`Flyway`, `OrtException`, `Tomcat started` ve `Started EcoVision` satirlarini
inceleyin. Baglanti sirlarini gizleyin. Panel erisimi olmadan hangi commit'in
calistigi, bellek/kota veya deploy arizasinin kesin nedeni tespit edilemez.

Juri denemesi oncesi yalniz cron testi degil, normal giris ve bir gercek atik
analizi de deneyin. Ayni anda cok sayida AI denemesi yapmayin: mevcut guvenli
inference eszamanlilik siniri 1'dir ve diger istekler kontrollu 503 alabilir.

## Bu turdaki gercek kontroller

Ilk olcumde uc GET zaman asimina ugradi; sonraki HEAD 10,6 saniyede 200 dondu.
Bu kayit `keepalive-initial-verification.json` dosyasinda korunur. Ardindan
tekrarlanan uc GET (401/319/642 ms) ve HEAD (607 ms) gercek uygulama yanitiyla
200 dondu. Son kontrol (25 Ekim 16:54:51 UTC) GET 331 ms / HEAD 387 ms,
200 ve beklenen govde: `keepalive-verification.json`. Bu gozlem cold
start/toparlanmayla uyumludur; Render loglari gorulmediginden kesin kok neden
sayilmaz.

`HealthControllerTest, JwtLivenessIsolationTest, JwtCredentialRevocationTest,
JwtSessionIdentityTest` odakli kosusu: 7 test, 0 hata/basarisizlik. Bu kosu
JBR21 uzerinde Java17 derleme hedefiyle yapildi; onceki Java17/PostgreSQL 115
testlik kosunun yerine production runtime testi diye sunulmaz.
