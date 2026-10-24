# Son güvenlik düzeltmeleri ve testler

Tarih: 24 Ekim 2026. Çalışma yalnız yerel depoda ve izole PostgreSQL ortamında.
Önceden var olan commitlenmemiş çalışmalar korunmuştur. Bu belge bir
penetrasyon testi veya sıfır güvenlik açığı garantisi değildir.

Kullanıcı son mesajında Git gönderimine ayrıca izin verdi. Bu, canlı veri
değiştirme veya Render panelinde elle dağıtım yetkisi olarak yorumlanmadı.
Repository'de otomatik deploy açıksa push sonrasında platform bunu tetikleyebilir;
canlı sağlık/uyumluluk ayrıca kontrol edilmelidir.

## P0: nesne düzeyinde medya erişimi

`MediaAccessService`, her GET'te güncel domain ilişkilerini kontrol eder.
`MediaAsset.category` kapsamı; profil sahibi, grup veya etkinlik/mesaj
referansları erişim bağlamını belirler. V6 ile eklenen nullable
`owner_user_id` yeni yükleyeni kaydeder. Eski satırların sahibi ve kapsamı
mevcut URL referanslarından okunur; bilinmeyen/ilişkisiz kayıtlar silinmez,
erişime kapatılır. Grup kapağı yetkili bir yönetici tarafından da yüklenebilir;
yükleyenin kurucuyla aynı olması gerekmez.

Metadata projection'ı yetkiden önce büyük bytea alanını yüklemez.
Yeni profil varlıklarında sahip PK'sı kullanılır; eski metadata'sız kayıtlarda
referans araması gerekir. Dosya boyut, MIME imzası ve görüntü boyut kontrolü vardır.
JPEG/PNG için ImageIO header, WebP için VP8/VP8L/VP8X boyut başlığı denetlenir;
piksel bütçesi 4 milyondur. Bu kötü amaçlı yazılım taraması değildir.

| İçerik | Anonim | Sahip | Arkadaş / üye | Yabancı |
|---|---|---|---|---|
| Yetişkin, PUBLIC, seçili özel profil fotoğrafı | 200 | 200 | 200 | 200 |
| FRIENDS_ONLY fotoğraf | 401 | 200 | Kabul edilmiş arkadaş 200 | 403 |
| 18 yaş altı veya artık seçili olmayan özel fotoğraf | 401 | 403 | 403 | 403 |
| Özel grup kapağı | 401 | Kurucu 200 | Grup üyesi 200 | 403 |
| Açık grup kapağı | 401 | 200 | Yetişkin 200 | Yetişkin keşif kullanıcısı 200 |
| Grup mesajı / etkinlik görseli veya PDF | 401 | Üye/kurucu 200 | İlgili üye 200 | 403 |
| Bağlantısı bulunmayan medya | 401 | 403 | 403 | 403 |

Engelleme profilde arkadaşlıktan önce değerlendirilir. Arkadaşlık/üyelik kaldırılınca
bir sonraki GET reddedilir. Grup/etkinlik medyası yetkili SUPERUSER moderasyonuna da
açıktır; özel profil fotoğrafında otomatik moderator bypass yoktur.
Bütün medya yanıtları, herkese açık fotoğraflar dahil,
`Cache-Control: private, no-store, max-age=0` kullanır: kamuya açık fotoğraf
sonradan gizliye alınabilir. PDF yanıtı attachment'tır.

SecurityConfig'te medya GET'i controller'a ulaşabilir; bu **koşulsuz kamu erişimi**
değildir. Dinamik ACL controller içinde zorunludur. Eski statik `/uploads/**`
erişimi denyAll'dur; aynı dosyalara ikinci bir izinsiz yol bırakılmaz.

Eski Event'ten gruba taşınmış içerikte `legacy_event_id` üzerinden güncel
GroupMember kontrol edilir. Eski EventMember satırının kalması, gruptan
çıkarılan kişiye medya izni bırakmaz; bu senaryo da PostgreSQL testindedir.

### Flutter uyumu

`AuthorizedImage` tüm avatar, grup kapağı, etkinlik ve sohbet görsellerini
mevcut ApiService üzerinden Bearer header ile alır ve Image.memory ile gösterir.
JWT query string'e eklenmez. Yalnız yapılandırılmış API origin'inin medya yolu
yetkili istek alabilir; üçüncü taraf adrese token gönderilmez.

`MediaSession` hesap değişiminde/çıkışta devam eden eski yanıtı reddeder.
Çıkış decoded image cache'ini de temizler. PDF, aynı yetkili byte isteğinden
sonra FilePicker'ın platform kaydetme ekranına gider; harici tarayıcıya gizli
URL/token taşınmaz. Mevcut tema/görsel fallback'ler korunur.

### Çıkış ve token yenileme

Güncel istemci logout sırasında access header da gönderir. İmzalı token'ın yalnız
SHA-256 özeti ve bitişi revocation tablosuna yazılır; JwtAuthenticationFilter
reddedilmiş/engellenmiş/iptal edilmiş access token'ı kabul etmez. Süresi geçmiş
iptaller saatlik temizlenir. Yeni JWT'lerde aynı saniyedeki oturumları ayıran
rastgele jti bulunur. Diğer token'lar topluca iptal edilmez.

Flutter yenilemeyi single-flight yapar. Gecikmiş refresh yanıtı çıkıştan sonra
oturum açamaz; secure-storage yazmaları sırayla ve oturum nesliyle korunur.
Yetkili profil okuma ve multipart yanıtları da oturum nesli değiştiyse
uygulanmaz; çıkıştan sonra eski profil veya fotoğraf yükleme yanıtı state'i
yeniden dolduramaz. Her iki yarış için istemci testi vardır.
Çevrimdışı logout sunucuya ulaşamazsa eski access token'ın sunucudaki süresi
dolmadan iptal edileceği garanti edilemez.

## P1: sunucuda sınav doğrulaması

Sunucunun `education/academy-quiz-v1.json` dosyası 10 modül/30 sorunun otoritesidir.
`GET /api/education/quiz/{categoryId}` yalnız soru/seçenek/sürüm döndürür,
doğru cevabı döndürmez. Completion isteği örneği:

```json
{"quizVersion":"2026-10-24-v1","answers":[1,0,2]}
```

Tam üç geçerli indeks ve doğru sürüm gerekir. Sunucu en az 2/3 koşulunu doğrular.
Eksik cevap/sürüm 426, eski sürüm 409, yetersiz doğru cevap 422 olur.
Başarıdan sonra mevcut kullanıcı kilidi, unique ilerleme ve idempotent
gamification ödülü korunur. Eşzamanlı iki geçerli completion toplam tek ödül verir.
Geçmiş ilerleme ve bakiyeler sıfırlanmaz. Eski, eksik ödül ancak geçerli sınav
gönderildikten sonra mevcut kurtarma mekanizmasıyla tamamlanabilir.

Flutter cevaplarını gönderir; mevcut yerel doğru cevaplar geri bildirim içindir.
Bir istemci bunları okuyabilir. Bu değişiklik, insanın gerçekten öğrendiğini
kanıtlayan veya cevap anahtarı paylaşımını engelleyen bir sınav sistemi değildir.
Yeni backend + eski APK doğrulamasız puan üretemez; güncelleme gerekir.

## P1: tarama ödül idempotency'si

Multipart analyze gerçek provider sonucu ve sunucunun hesapladığı SHA-256 ile
`saveVerifiedAnalysis` çağırır. İstemcinin ham puanını veya analiz kimliğini kabul
etmez. Yeni kayıtta analysisId UUID vardır. Aynı kullanıcı + aynı görsel byte
hash'i + İstanbul takvim günü için yalnız bir ödül verilir. Kullanıcı satır kilidi
yarışı önler; V6 partial unique index aynı ödüllü görüntüyü DB'de de kısıtlar.

Tekrar sonucunda sıfır puan ve `rewardStatus=DUPLICATE_IMAGE` döner.
Analiz/harita hâlâ açılır; görev, rozet veya tarama serisi tekrar ilerlemez.
Malzeme rozet sayımı da yalnız pozitif ödüllü taramaları sayar; sıfır XP'li
tekrarları biriktirip sonraki taramada rozet almak mümkün değildir. Hash akıştan
okunur; yalnız hash için ikinci bir tam görüntü byte dizisi oluşturulmaz.
İki farklı kullanıcı aynı görüntüyle kendi günlük politikaları kapsamında
ayrı değerlendirilir. Düşük skor/çoklu nesne ödül almaz.

Eski label-only servis/API yolu kayıt için korunur ama sıfır XP verir.
Önceki puanlar geri alınmaz. Görsel cache'i ödül mekanizması değildir.
Hash birebir dosya tekrarını yakalar; yeniden kodlama, metadata değişimi veya
yeni fotoğrafla suistimali eksiksiz tespit etmez. Fotoğraf fiziksel iade kanıtı değildir.

## P1: DOA durum dili

Malzeme desteği ve kaynak hazne durumu ayrı gösterilir. true/false/null için
olumlu/olumsuz/bilinmiyor metni vardır; hiçbiri canlı kabul garantisi değildir.
Snapshot tarihi korunur; yeniden import bugünün telemetrisi sayılmaz.
OR filtresi, 4.037 kaynak nokta, UUID upsert, viewport ve cluster değişmedi.

## Test kanıtı ve kalan sınırlar

Güncel komutlar/sonuçlar `final-security-verification.json` ve
`verification.md` içinde tutulur; eski test sayılarını yeni çalışmaya
otomatik taşımayın. PostgreSQL testleri yalnız izole yerel 25439 portunu kabul eder.

Test kapsamı: gerçek multipart profil yükleme; anonim/yabancı/sahip/arkadaş
yetkileri; arkadaş/üye çıkarma; legacy owner-null; yönetici kapak yüklemesi;
logout JWT replay; quiz 0/1/2/3 doğru ve eşzamanlı claim; hash tekrarı,
label-only ve eşzamanlı scan; migration tekrar çalıştırma; JPEG/PNG bozuk/piksel
sınırı; istemci origin/token güvenliği ve geç refresh; lifecycle polling.

Sonuç: 88 backend testi (8 gerçek PostgreSQL entegrasyon testi dahil), 88 Flutter
testi; web release ve Java 17/prod smoke başarılı. Gerçek Chrome'da özel fotoğraf,
görsel yükleme, AI, rehber, malzeme filtreli harita, gerçek hedefe yol tarifi isteği
ve tek-sefer akademi ödülü doğrulandı. ARM64 debug APK da geçici ASCII dizinde
derlendi; telefona kurulmadı. Bu bir gerçek cihaz saha testi değildir.

Sohbet HTTP yedeği bağlıyken 8 sn yerine yaklaşık 48 sn uzlaşma yapar; kopunca
8 sn yedeğe döner. Bu altı kat sunucu kapasitesi artışı ölçümü değildir. Yavaş
API testinde 24 sn boyunca ikinci in-flight çağrı birikmedi; arka planda yeni
sorgu yoktur. SQL N+1 sayısı/p95 ve çok kullanıcılı yük testi bu turda ölçülmedi.
Mevcut STOMP oturumlarının çıkış/üyelik değişiminde anında kesilmesi ve çoklu
instance broker davranışı bu HTTP medya güvenliği testinin garantisi değildir;
ayrı WebSocket oturum/abonelik yaşam döngüsü denetimi gerekir.

Geçmişte public/immutable cache'lenmiş veya indirilmiş bir dosyanın kopyasını
sunucu uzaktan silemez. Mevcut `/uploads` dosyaları otomatik DB'ye taşınmadı;
orijinal dosyalar yedeklenerek sahip referanslarıyla ayrı bir geçiş gerekir.
Eski istemci özel medya için auth header kullanmıyorsa artık erişemez.
Bunu aşmak için anonim izin veya token'ı URL'ye koyan workaround yoktur.
