# EcoVision: mimari, ekranlar, butonlar ve API veri akışları

**25 Ekim güncellemesi:** Bu incelemenin harita il/ilçe düğmesi ve açılır karbon
girdisi anlatımı tarihsel kaldı. Güncel arayüz değişiklikleri ve doğrulama:
[25 Ekim düzeltmeleri](ui-fixes-2026-10-25-tr.md).

İnceleme tarihi: 24 Ekim 2026. Bu belge mevcut yerel kaynak kodu açıklar;
özelliklerin tamamının canlı Render'da veya eski telefon APK'sında dağıtılmış
olduğunu iddia etmez. Gerçek test kanıtı: [son denetim](ecovision-final-audit-tr.md),
[sonuç JSON'u](final-audit-verification.json).

Bu belgeyi hazırlarken uygulama davranışı veya veritabanı değiştirilmedi.
Örnek JSON'lar yalnız alan yapısını anlatır; gerçek hesap/token/API anahtarı içermez.

## İçindekiler

1. [Ürün ve mimari](#1-ürün-ve-mimari)
2. [Klasörler ve teknoloji](#2-klasörler-ve-teknoloji)
3. [İstek nasıl çalışır?](#3-bir-isteğin-uçtan-uca-yolculuğu)
4. [Açılış ve oturum](#4-açılış-splash-ve-oturum-kontrolü)
5. [Giriş, kayıt ve tanıtım](#5-giriş-kayıt-ve-tanıtım)
6. [Ana sayfa ve Eco Merkezi](#6-ana-sayfa-ve-eco-merkezi)
7. [AI tarama ve sonuç](#7-fotoğraf-tarama-ve-sonuç)
8. [DOA haritası](#8-doa-haritası)
9. [Görevler](#9-görevlerim)
10. [Akademi](#10-atık-rehberi-ve-eko-akademi)
11. [Karbon](#11-karbon-ayak-izi)
12. [Market ve avatar](#12-eco-market-ve-avatarlar)
13. [Liderlik](#13-liderlik-tablosu)
14. [Topluluk ve arkadaşlar](#14-topluluk-keşif-arkadaşlar-ve-davetler)
15. [Sohbet](#15-grup-sohbeti)
16. [Grup bilgisi ve etkinlik](#16-grup-bilgisi-yönetim-ve-etkinlikler)
17. [Profil ve ayarlar](#17-profil-ve-ayarlar)
18. [Public profil](#18-başka-kullanıcının-profili)
19. [Bildirim ve moderasyon](#19-bildirimler-ve-moderasyon)
20. [Veritabanı](#20-veritabanı-ve-kalıcılık)
21. [Eski yollar](#21-eski-ve-uyumluluk-akışları)
22. [Altyapı](#22-dağıtım-izleme-ve-geliştirme-altyapısı)
23. [API sözleşmesi ve hata örnekleri](#23-api-sözleşmeleri-ve-hata-çıktıları)
24. [Senaryolar](#24-örnek-uçtan-uca-kullanım-senaryoları)
25. [Sınırlar ve doğrulama](#25-ne-var-ne-yok-ve-neyi-doğruladık)

Tam endpoint ve DTO sözlüğü: [api-route-inventory-tr.md](api-route-inventory-tr.md).
Bu ekte 21 controller, 138 HTTP handler tanımı / 133 farklı yöntem-yol çifti ve
4 STOMP uygulama handler'ı kaynak imzalarıyla listelenir. Farklı content-type
handler'ları ayrı tanımdır; framework Actuator/Swagger yolları bu sayıya dahil değildir.

## 1. Ürün ve mimari

EcoVision, bir atığı fotoğraftan tanımaya, ilgili ayırma bilgisini okumaya ve
uygun malzemeler için DOA iade noktası bulmaya yardımcı olan Türkçe bir uygulamadır.
Görev/puan/akademi/avatar, bu öğrenme ve tekrar davranışını destekler. Topluluk,
18 yaş ve üstü kullanıcıların grup kurmasını, konuşmasını ve etkinlik düzenlemesini sağlar.

Temel yol:

```text
Fotoğraf Çek / Galeriden Seç
  -> telefondan/backend'e multipart görsel
  -> Gemini veya sunucuda ONNX görsel sınıflandırma
  -> sunucuda tarama kaydı + uygunsa uygulama puanı
  -> Tarama Sonucu
      -> ilgili Atık Rehberi
      -> DOA Makinelerini Haritada Göster
          -> nokta ayrıntısı -> harici uygulamada Yol Tarifi
```

Mimari **modüler monolit**tir; mikroservis/Django uygulaması değildir.
Flutter arayüzü, Spring Boot 3 API'si ve PostgreSQL veri katmanı vardır.

```text
Flutter ekranı / modal / form
  -> ApiService + JSON/Dart modelleri
  -> HTTPS REST veya STOMP/WebSocket
  -> JWT filtre / method ve nesne yetkisi
  -> Controller -> Service -> Repository -> PostgreSQL
  <- DTO / dosya bytes / STOMP olay / standart hata
  <- FutureBuilder / ValueNotifier / setState
  <- kullanıcıya liste, kart, diyalog, toast/SnackBar veya hata/tekrar dene
```

Her buton sunucu çağrısı yapmaz. Göz simgesi, sekme değişimi, anket seçeneği,
rehber araması ve davet kodu kopyalama çoğunlukla yerel işlemdir.
Kaydet, satın al, puan talep et, mesaj gönder ve katıl ise sunucuda doğrulanır.

## 2. Klasörler ve teknoloji

| Yol | Sorumluluk |
|---|---|
| `frontend/lib/main.dart` | Türkçe locale, global tema, Splash ve başlangıç rotası |
| `frontend/lib/screens/` | 33 ekran dosyası; bazıları içinde ek form/modal/widget bulunur |
| `frontend/lib/widgets/` | Yetkili görsel, avatar, kimlik başlığı, shimmer, Lottie, takvim, cam modal |
| `frontend/lib/models/` | JSON'u tipli Dart nesnesine çeviren modeller; karbon hesap mantığı |
| `frontend/lib/services/api_service.dart` | HTTP, token/refresh, oturum, JSON dönüşümü, puan bildirimi |
| `frontend/lib/services/` | Konum, paylaşım, akademi asset okuma, medya indirme, görsel sıkıştırma |
| `frontend/lib/theme/` | Orman/Okyanus/Gün Batımı/Karanlık Eko; hesap-bağlı yerel + DB tercih |
| `frontend/lib/core/` | Ortak konum kataloğu, form doğrulama, medya URL güvenliği; örnek public ayarlar |
| `frontend/assets/` | Akademi/konum JSON'ları, 20 avatar, animasyonlar, uygulama ikonu, Nunito fontu |
| `frontend/android`, `ios`, `web` | Platform izinleri, native derleme ve web kabuğu |
| `frontend/test/` | Widget, model, güvenlik istemcisi, UI ve hesaplama regresyonları |
| `backend/.../controller/` | HTTP/STOMP girişleri ve DTO yanıtları; uygulama kuralının tamamı burada değildir |
| `backend/.../service/` | Kimlik, tarama, AI, görev, topluluk, medya ACL, karbon, bildirim iş kuralları |
| `backend/.../repository/` | JPA sorguları, projection'lar, kullanıcı/ilerleme kilitleri |
| `backend/.../model/` | Kalıcı entity, rol/durum ve puan/avatara ilişkin enum'lar |
| `backend/.../dto/` | API giriş/çıkış alan sözleşmeleri |
| `backend/.../security/` | BCrypt, JWT, access-token iptali, HTTP güvenliği |
| `backend/.../config/` | Seed, WebSocket, şema uyumluluğu, uygulama yapılandırması |
| `backend/src/main/resources/db/migration/` | Flyway V1–V6; uygulanmış migration geçmişi korunur |
| `backend/src/main/resources/data/data/` | DOA ham snapshot ve manifest; runtime import kaynağı |
| `backend/src/main/resources/education/` | Sunucunun güvenilen quiz sürümü/cevapları |
| `backend/src/main/resources/ml/` | ONNX model, metadata ve lisanslar |
| `ml/` | Python eğitim/ölçüm betikleri, split/metrics/model kartı; runtime Python servisi değil |
| `scripts/` | Veri denetimi, yerel Chrome/HTTP testleri, APK derlemesi, bu API sözlüğü üretimi |
| `docs/` | Mimari/ürün, test, veri, kaynak, dağıtım ve yarışma taslakları |
| `.github/workflows/`, `k8s/`, Compose dosyaları | CI/CD, container/orchestration ve gözlemlenebilirlik tanımları |

Frontend: Flutter 3.35.7 / Dart 3.9.2, Material 3. Başlıca bağımlılıklar:
`http`, `flutter_secure_storage`, `shared_preferences`, `image_picker`, `image`,
`flutter_map`, `latlong2`, `geolocator`, `geocoding`, `stomp_dart_client`,
`file_picker`, `url_launcher`, `share_plus`, `lottie`, `animated_text_kit`, `shimmer`.
Nunito fontu paketlidir; `google_fonts` bağımlılığı pubspec'te hâlâ bulunur.

Backend: Java 17, Spring Boot 3.3.5, Spring Web/MVC, Security, Validation,
Data JPA/Hibernate, PostgreSQL, Flyway, WebSocket/STOMP, JJWT, Actuator/Micrometer,
springdoc OpenAPI ve ONNX Runtime. Veritabanı SQL ilişkileriyle çalışır; her istek
için yeni veritabanı kurulmaz.

### 2.1 Ekran dosyalarının tam dizini

Bu sayı 33 dosyadır; 33 bağımsız ana sekme değildir. Aynı dosyada alt panel,
anket formu veya üye yönetimi gibi ek widget'lar bulunabilir.

| Dosya | Nasıl açılır / görevi | Ayrıntı bölümü |
|---|---|---|
| `splash_screen.dart` | Başlangıç oturum kontrolü sırasında otomatik | 4 |
| `login_screen.dart` | Oturum yok veya çıkış yapılmış | 5 |
| `register_screen.dart` | Girişte yeni hesap | 5 |
| `onboarding_screen.dart` | Hesap tanıtımı görmemişse başarılı auth sonrası | 5 |
| `main_tab_navigator.dart` | Başarılı oturum; ana sekme kabuğu | 6, 19 |
| `home_screen.dart` | Tarayıcı sekmesi; fotoğraf ve Eco Merkezi | 6–7 |
| `result_screen.dart` | Başarılı analiz; tarama verisi parametreyle gelir | 7 |
| `map_screen.dart` | Harita sekmesi veya sonuçtan DOA düğmesi | 8 |
| `missions_screen.dart` | Eco Merkezi -> Görevlerim | 9 |
| `education_guide_screen.dart` | Eco Merkezi -> Atık Rehberi; güncel rehber wrapper'ı | 10 |
| `education_detail_screen.dart` | Rehber modülü / sonuçtan ilgili rehber | 10 |
| `academy_quiz_screen.dart` | Dersin sınav düğmesi | 10 |
| `carbon_footprint_screen.dart` | Eco Merkezi -> Karbon Ayak İzi | 11 |
| `detailed_carbon_screen.dart` | Korunan kısa tüketim hesabı; ana kartın hedefi değil | 11, 21 |
| `eco_market_screen.dart` | Eco Merkezi -> Eco-Market | 12 |
| `avatar_evolution_screen.dart` | Eco Merkezi -> Avatar Yolu | 12 |
| `avatar_selection_screen.dart` | Profil avatar düzenleme | 12, 17 |
| `leaderboard_screen.dart` | Eco Merkezi -> Liderlik | 13 |
| `community_screen.dart` | 18+ Topluluk sekmesi | 14 |
| `create_community_group_sheet.dart` | Topluluk oluşturma düğmesi; modal form | 14 |
| `group_chat_screen.dart` | Katılınan yeni grup kartı | 15 |
| `group_details_screen.dart` | Sohbet bilgi paneli -> grup ayrıntıları; etkinlik/üye formları da burada | 16 |
| `public_profile_screen.dart` | Üye/mesaj/leaderboard/arkadaş avatarı | 18 |
| `profile_screen.dart` | Kendi Profil sekmesi | 17 |
| `settings_screen.dart` | Profil dişli simgesi; güncel akışta alt panele gömülür | 17 |
| `edit_profile_screen.dart` | Ayarlar -> Profili Düzenle | 17 |
| `change_password_screen.dart` | Ayarlar -> Parolayı Değiştir | 17 |
| `scan_history_screen.dart` | Profil -> Tümünü Gör | 17 |
| `notifications_screen.dart` | Ana AppBar zil | 19 |
| `superuser_dashboard_screen.dart` | Yetkili hesap ayarlar menüsü | 19 |
| `event_chat_screen.dart` | Eski Event modelinin sohbet rotası | 21 |
| `group_info_screen.dart` | Eski EventChat grup bilgisi | 21 |
| `event_location_map_screen.dart` | Eski etkinliğin konumunu gösterme | 21 |

`WasteGuideScreen` ayrı isimli bir ekran dosyasında değil,
`education_guide_screen.dart` içindedir. Benzer biçimde yeni `_GroupInfoSheet`
`group_chat_screen.dart`, üye yönetimi ve `CreateGroupEventSheet`
`group_details_screen.dart` içinde bulunur.

## 3. Bir isteğin uçtan uca yolculuğu

Örnek: `Eco-Market -> Satın Al`.

1. Buton `_purchase(item)` fonksiyonunu çağırır; aynı anda ikinci satın alma engellenir.
2. `ApiService.purchaseMarketItem(item.id)` bir POST hazırlar.
3. Başlıkta `Authorization: Bearer <access-token>` bulunur. API adresi build-time
   `API_BASE_URL` üzerinden alınır; yoksa kodda tanımlı Render backend adresi kullanılır.
4. Spring JWT filtresi kullanıcıyı doğrular. Service, token'daki kullanıcı adına
   gelen isteğin hesabını bulur; istemcinin başka userId göndermesiyle hesap seçilmez.
5. `MarketController -> MarketService.purchase` kullanıcı satırını kilitler,
   sunucu kataloğundan fiyatı bulur, sahiplik/bakiyeyi denetler.
6. PostgreSQL'de puan düşer ve ürün kaydolur. Yanıt `UserResponse` olur.
7. Dart JSON'u `UserProfile` yapar, `currentUser` ve puan `ValueNotifier` güncellenir.
8. Ekran yeni bakiye ve sahipliği gösterir; başarı diyaloğundaki Paylaş, cihazın
   paylaşım menüsünü açar. Sunucuda gerçek kahve/ağaç siparişi oluşmaz.

### State management

Redux/Bloc/Riverpod ana mimarisi kullanılmıyor. Mevcut yapı:

- `StatefulWidget/setState`: form, seçim, yükleme ve görünür liste.
- `FutureBuilder`: ilk API/asset okuma; bekleme, hata, boş ve başarı dalları.
- `ValueNotifier<int>`: bakiye değişimini ana ekrana anlık yansıtır.
- `ThemeController + ChangeNotifier + ThemeScope`: bütün uygulamanın teması.
- `Navigator.push/pop/pushAndRemoveUntil`: alt ekranlar ve oturum rotası.
- `IndexedStack + visited set`: ana sekmeler ilk açıldığında kurulur; ziyaret
  edilenler state'ini korur. Bu, her sekmede yeni login yapılması demek değildir.
- İstek nesli/cancel/debounce: geç gelen eski arama/harita yanıtı yeniyi ezmez.

### Kimlik ve yetki aynı şey değildir

- Kimlik doğrulama: BCrypt parola kontrolü -> kısa ömürlü access JWT ve refresh
  oturumu. Refresh veritabanında düz token yerine `tokenHash` ile tutulur.
- HTTP katmanı: SecurityConfig public yolları, authenticated yolları ve
  ADMIN/SUPERUSER sınırlarını ayırır; JWT filtresi her yetkili çağrıda çalışır.
- Nesne katmanı: oturum açmış olmak başka grubun sohbetini, başka kişinin özel
  medyasını veya başkasının quest ödülünü açmaz. Service sahiplik/üyelik/yaş kontrolü yapar.
- `/ws` handshake public olabilir; STOMP CONNECT/SUBSCRIBE/SEND token ve
  destination üyeliği ayrıca kontrol edilir. Public handshake, public sohbet değildir.
- Mobilde token `flutter_secure_storage`; tema/tanıtım gibi sır olmayan tercihler
  `shared_preferences` kullanır. Web'de platformun saklama ve origin güvenliği
  ayrıca değerlendirilmelidir; mobil secure storage garantisi tarayıcıya aynen taşınmaz.
- CORS izinleri sunucunun origin ayarındadır. CORS, parola/rol kontrolünün
  yerine geçmez ve tek başına SQL injection/XSS güvenlik garantisi değildir.

İşlem başarısının kalıcı tarafı PostgreSQL transaction'ıdır. Diyaloğu kapatmak
puan üretmez; yalnız sunucu yanıtına göre görünen state değişir. Flutter'daki
`mounted` kontrolleri kapanmış ekrana yazmayı, busy flag'leri hızlı çift dokunmayı
sınırlar; gerçek çift harcama/ödül koruması yine backend'dedir.

| Rol alanı | Değerler | Kapsam |
|---|---|---|
| `AppUser.role` | USER, GROUP_ADMIN, ADMIN, SUPERUSER | Uygulama hesabının platform rolü; GROUP_ADMIN eski akışlarla da ilişkilidir |
| `GroupMember.role` | FOUNDER, ADMIN, MEMBER | Yalnız ilgili CommunityGroup içindeki üyelik yetkisi |

Herhangi bir grupta ADMIN olmak `/api/admin/users` listesini açmaz.
SUPERUSER paneli platform rolünü, grup silme/üye yönetimi normal grup üyeliği
kurallarını kullanır; moderasyonun ayrı SUPERUSER endpoint'i vardır.

## 4. Açılış, Splash ve oturum kontrolü

Kaynak: `frontend/lib/main.dart`, `screens/splash_screen.dart`, `ApiService`.

```text
runApp -> ThemeController.load
       -> ApiService.loadStoredSession
          -> saklı token yok: LoginScreen
          -> token var: /api/auth/me; gerekirse /api/auth/refresh
       -> hesaba ait tema bağlanır
       -> hasSeenOnboarding_<userId>
          -> görülmüşse MainTabNavigator
          -> görülmemişse OnboardingScreen
```

Splash animasyonu bu karar bitene kadar görünür. Geçerli oturum varken Login'in
önce çizilip sonra kaybolması amaçlanmaz. Kesin 401/403 ile geçici ağ/5xx
hatası ayrılır: geçici hata otomatik olarak bütün tokenları silmez.

| Görünen kontrol | Tetiklenen işlem | Sonuç |
|---|---|---|
| Splash | Otomatik başlangıç kontrolü; kullanıcı butonuna bağlı değil | Giriş, tanıtım veya ana ekran |
| `Yeniden Dene` | `_initialize()` yeniden çalışır | Korunan oturumla sunucu tekrar denenir |
| `Başka hesapla giriş yap` | `ApiService.logout()` + auth rotası | Tokenlar temizlenir; Login görünür |

## 5. Giriş, kayıt ve tanıtım

### 5.1 LoginScreen

| Kontrol | Fonksiyon / çağrı | Çıktı / davranış |
|---|---|---|
| E-posta ve parola | Yerel form doğrulama | Eksik/geçersiz veri gönderilmez |
| Göz simgesi | `_obscurePassword` değiştirilir | Yalnız metnin görünürlüğü; API yok |
| `Beni hatırla` | `ApiService.setRememberMe` | Tokenların sonraki açılışa güvenli saklanma tercihi |
| `Giriş Yap` | `_login -> api.login -> POST /api/auth/login` | `AuthResponse`; tema bağlanır, tanıtım kontrolü ve ana rota |
| `Parolamı Unuttum` | E-posta diyaloğu | `Bağlantı Gönder` seçilince POST `/api/auth/forgot-password` |
| `Vazgeç` | Diyalog kapanır | İstek yok |
| `Yeni hesap oluştur` | `Navigator.push(RegisterScreen)` | Kayıt formu |

Başarılı giriş gövdesi `accessToken`, `refreshToken`,
`accessTokenExpiresInSeconds`, `user` içerir. Tokenların değeri UI'da yazdırılmaz.
Backend BCrypt doğrular; beş başarısız denemeden sonra geçici hesap kilidi vardır.
Beklerken auth overlay; hatada okunabilir SnackBar gösterilir.

**Sınır:** Parola kurtarma endpoint'i genel kabul mesajı döndürür; gerçek e-posta
teslimi ve yeni parola bağlantısı tamamlanmış bir sistem değildir.
Google giriş butonu yoktur; eski Google endpoint'i yalnız backend'de kalmıştır.

### 5.2 RegisterScreen

Toplanan veri: ad, soyad, kullanıcı adı, e-posta, parola/tekrar, doğum tarihi,
il, ilçe ve zorunlu iki sözleşme kabulü. Parola tekrarı sunucuya yeni bir parola
alanı olarak kaydedilmez; istemcide eşleşme kontrolüdür.

| Kontrol | Yerel işlem | Sunucu / sonuç |
|---|---|---|
| Parola yazma | Canlı güç göstergesi | En az 8 karakter, büyük/küçük harf, sayı, özel karakter |
| İki parola göz simgesi | İlgili alanı göster/gizle | API yok |
| Doğum tarihi | DatePicker; gelecek/13 yaş altı seçimi engeli | Backend de 13 yaş altını reddeder |
| İl dropdown | 81 il ortak katalogdan | İl değişince ilçe temizlenir |
| İlçe dropdown | Sadece seçilen ilin ilçeleri | Eski ilin ilçesi yeni ile taşınmaz |
| Sözleşme `Görüntüle` | Bilgi metni diyaloğu; `Anladım` kapatır | Kabul ayrı checkbox'tır |
| `Güvenli Hesap Oluştur` | `_register -> POST /api/auth/register` | Kullanıcı/token yanıtı; hesaba bağlı tanıtım veya ana ekran |
| Geri | Önceki giriş ekranı | Kayıt isteği başlatmaz |

`adult` sunucu verisidir; 13–17 yaş kullanıcı kayıt olabilir fakat topluluk
ve özel fotoğraf yükleme yetkisi kazanmaz.

### 5.3 OnboardingScreen

Dört sayfalık Dünya rehberi; tarama, puan/market ve topluluk hikâyesini anlatır.
PageView kaydırma, göstergeler ve typewriter metni yereldir.

- `Devam Et`: sonraki sayfa; API yok.
- `Atla`: `_finish`; o hesap için `hasSeenOnboarding_<id>=true` yazılır.
- Son sayfada `Hemen Başla`: aynı flag, `pushAndRemoveUntil(MainTabNavigator)`.
- Flag cihazdaki SharedPreferences'tadır; uygulama verisi silinince tekrar çıkabilir.

## 6. Ana sayfa ve Eco Merkezi

Ana sekmeler: **Tarayıcı, Harita, Topluluk (18+), Profil**. 18 yaş altında
Topluluk tabı listeden çıkar; Profil üçüncü sekme olur.

Ana AppBar'da zil Bildirimler'i, harita simgesi doğrudan Harita sekmesini açar.
`Fotoğraf Çek` kamera, `Galeriden Seç` galeriyi `image_picker` ile açar.
Kullanıcı seçimden vazgeçerse analiz veya ödül oluşmaz.

Eco Merkezi kartları yalnız ekran açar; sunucu işi hedef ekran kurulunca başlar:

| Kart | Açılan ekran | İlk veri |
|---|---|---|
| Görevlerim | MissionsScreen | GET `/api/quests` |
| Eco-Market | EcoMarketScreen | GET `/api/auth/me`; ürünler istemci + sunucu katalogları |
| Avatar Yolu | AvatarEvolutionScreen | GET `/api/gamification/avatar-tiers` |
| Atık Rehberi | EducationGuideScreen -> WasteGuideScreen | `academy_guide.json` + GET `/api/education/progress` |
| Liderlik | LeaderboardScreen | `/api/leaderboard/city` veya `/friends` |
| Karbon Ayak İzi | CarbonFootprintScreen | Yerel 20 soru; bitince gamification API |

Puan rozeti `pointsListenable` dinler. Tarama/claim/market yanıtı geldikten sonra
ana sayfaya dönmeden bakiye notifier'ı güncellenebilir.

## 7. Fotoğraf tarama ve sonuç

### 7.1 Fotoğrafın sunucuya gidişi

```text
HomeScreen._scan(ImageSource.camera/gallery)
  -> dosya baytları
  -> ApiService.analyzeWasteImage
  -> POST /api/scans/analyze, multipart alan adı: image
  -> ScanController SHA256 hesaplar
  -> WasteAnalysisService provider seçer
      gemini -> GeminiWasteAnalysisService -> dış Gemini REST
      local  -> LocalWasteModel -> ONNX CPU
  -> ScanService.saveVerifiedAnalysis
  -> kullanıcı kilidi, hash/puan/seri, ScanHistory
  -> DTO -> ScanResult -> Navigator.push(ResultScreen)
```

Frontend'de Gemini anahtarı veya TFLite inference yoktur. `local`, sunucunun
yerel ONNX motorudur; telefonda çevrimdışı AI anlamına gelmez.

Gemini yapılandırılan model ve environment anahtarıyla çalışır; model değiştiren
otomatik çoklu fallback zinciri yoktur. Yerel ONNX, gerçek eğitilmiş
MobileNetV2 özellikleri + sınıflandırıcı başlığı kullanır; model checksum'ı kontrol edilir.
ONNX'in altı sınıfı karton/cam/metal/kağıt/plastik/diğer; depozito barkodu veya
DOA işareti doğrulamaz. Bulut daha geniş sınıflar döndürebilir.

### 7.2 Dönüş verisi

`GeminiScanResponse` adı geçmişten kalmıştır; provider ONNX olsa da aynı sözleşme kullanılır:

```json
{
  "detections": [
    {"type": "CAM", "material": "Cam Atık", "confidence": 0.88,
     "machine_eligible": true, "eligibility_label": "örnek yönlendirme metni"}
  ],
  "scan": {
    "id": 101, "material": "Cam Atık", "is_recyclable": true,
    "decay_years": "genel eğitim bilgisi", "recycled_into": "cam ürünler",
    "scannedAt": "örnek ISO-8601 zaman", "points_awarded": 12,
    "updated_user_points": 112, "analysisId": "örnek UUID", "rewardStatus": "AWARDED"
  },
  "updated_user_points": 112,
  "provider": "ONNX_CPU",
  "modelVersion": "model sürümü",
  "inferenceMode": "LOCAL",
  "needsConfirmation": false
}
```

`DetectedWasteResponse` alanlarının tam adları API ekinde bulunur; örnek değerler
gerçek ölçüm değildir. `machine_eligible` alanı resmî depozito kabul belgesi sayılmaz.
Skor, kalibre edilmiş kesin doğruluk olasılığı değildir. Birden çok nesne veya
0,65 altı skor `needsConfirmation` üretir; belirsizlik saklanmaz.

### 7.3 Puan nereden gelir?

İstemci `+10` gibi bir puan miktarı göndermez. `WasteMaterial` sunucu tablosu:

| Sınıf | Uygun bir yeni doğrulanmış tahmin için uygulama puanı |
|---|---:|
| Plastik | 10 |
| Cam | 12 |
| Kağıt/karton | 8 |
| Metal | 15 |
| Elektronik | 20 |
| Organik | 5 |
| Yağ | 12 |
| Tıbbi | 0 |
| Karışık | 5 |
| Bilinmeyen | 0 |

Ödül; tek nesne/yeterli model skoru, sunucu sınıfı ve tekrar kontrolüne bağlıdır.
Aynı kullanıcı ve aynı dosya SHA256'sı geçmişte ödül aldıysa yeni kayıt sıfır
puanla `DUPLICATE_IMAGE` olur. Tarih değişmesi tekrar ödül hakkı vermez.
Yeniden kodlanan dosyayı veya tekrar çekilen aynı nesneyi kusursuz tanıyan bir
fiziksel anti-fraud sistemi değildir. Eski etiket-only kayıt yolları sıfır XP verir.

Ödüllü tarama ayrıca tarama serisi/rozet/görev olaylarını tetikleyebilir. Bir
fotoğrafın görülmesi fiziksel geri dönüşüm gerçekleşti demek değildir.

### 7.4 ResultScreen butonları

| Buton / alan | Ne yapar? | API veya çıktı |
|---|---|---|
| AI özeti açılır alanı | Provider/model/skor sınırını gösterir | Zaten gelen DTO; yeni AI çağrısı yok |
| Başarı diyaloğu `Devam Et` | Puan kutlamasını kapatır | API yok; puan önceden sunucuda verilmiştir |
| `DOA Makinelerini Haritada Göster` | `_openBins -> onFindBins -> Harita sekmesi` | PET/cam/alüminyum tanınıyorsa o malzeme; genel plastik/metal ise filtresiz |
| Rehber düğmesi | `_openGuide`, sınıf -> categoryId eşlemesi | Yerel ders + ilerleme GET; module göre EducationDetail |
| `Eko İlerlememi Paylaş` | EcoShareService | OS paylaşım menüsü; sunucu bildirimi değil |
| `Başka Bir Atık Tara` | Sonuçtan geri döner | Yeni fotoğraf kullanıcı seçmedikçe analiz yok |

Rehber eşlemesi: plastik/PET -> modul-1, cam -> 2, kağıt/karton -> 3,
metal/alüminyum -> 4, elektronik -> 5, kompozit -> 6, yağ -> 7, tekstil -> 8,
organik -> 9, tıbbi -> 10. Bulunamazsa rehber listesi açılır.

Eski ambalaj kontrol formu ve “Gerçekleştirdiğim Eylemi Kaydet” sonuç ekranında yoktur.
Mevcut küçük metin tutarsızlığı: tekrar fotoğraf uyarısında hâlâ “bugün/bir günde”
ifadesi bulunur; sunucu kuralı gün bağımsızdır.

## 8. DOA haritası

### 8.1 İlk yükleme ve veri kaynağı

`flutter_map` haritayı, OpenStreetMap karo servisi görsel zemini,
`MapController` kamera hareketini sağlar. Nokta konumları OSM karo katmanından
değil EcoVision API/PostgreSQL DOA kataloğundan gelir. Google Maps SDK anahtarı yoktur.

`LocationService` GPS izni ister. GPS yoksa açıkça bildirilen Şanlıurfa fallback'i
harita merkezidir; kullanıcının gerçekten orada olduğu iddiası değildir.

```text
MapScreen açılır -> GPS/fallback
  -> GET /api/map-pins/search
  -> DoaMapService projection + filtre + mesafe + sıralama
  <- items / total / limit / offset / hasMore
  -> MapPin.fromJson (double, finite, koordinat sınırı)
  -> setState -> marker/küme ve alt sonuç listesi
```

Kaynak snapshot: 4037 nokta; 2162 DIM, 1764 MIN, 111 SDM. DIM varsayılan tüketici
iade makinesidir; MIN/KIM merkez ve SDM toplu iade türleri ayrıca seçilir.
İli kesin çözülemeyen 3 adres tahminle bir şehre yazılmaz.

### 8.2 Kontroller

| Kontrol | Tetiklenen işlem | Sonuç |
|---|---|---|
| `İl / ilçe seç` | `_chooseArea -> GET /api/map-pins/locations` | 81 ilin tür bazlı sayısı, 973 ilçe ve veri bounds'ları |
| İl dropdown | Seçilen il; eski ilçe temizlenir | Henüz nokta mutation'ı yok |
| İlçe dropdown | O ilin ilçeleri | İsteğe bağlı daraltma |
| `Haritada göster` | Seçimi uygula, yarıçapı sınırsız yap, `/search?city=...&district=...` | Seçili yerin bounds'una kamera; ilk 100 nokta |
| `İl / ilçe filtresini kaldır` | Konum filtresini temizle | Genel/viewport araması |
| Filtre simgesi | Malzeme/tür/saat/yarıçap modalı | Taslak seçimler anında DB değiştirmez |
| PET/Cam/Alüminyum checkbox | OR kümesi | Herhangi birini destekleyen nokta eşleşir |
| `Yalnız programa göre açık noktalar` | `openOnly=true` | Saat bilgisi bilinmeyen nokta açıkmış gibi geçirilmez |
| Merkezleri / SDM göster | `pointTypes` kümesi | Makineyle merkez ayrı kalır |
| Sınırsız anahtarı / 1–50 km slider | Radius null veya sayı | Sınırsız sonuç limiti değil, mesafe sınırı yok demektir |
| `Sıfırla` | Filtre taslağını varsayılana al | `Sonuçları Göster` ile sorgulanır |
| `Sonuçları Göster` | `/search` yeni parametreler | Yeni sonuç listesi; eski yanıt nesli geçersiz |
| `Bu alanda ara` | Kamera center + visible bounds | Görülen alanı sorgular; eski GPS etrafına takılı kalmaz |
| Haritayı sürükle | 450 ms debounce | Yeni viewport; önceki HTTP iptali/eski yanıt koruması |
| `100 nokta daha yükle` | Aynı sorgu, offset += mevcut kayıt | Tekil ID'lerle listeye ekleme; `total/hasMore` korunur |
| Kalabalık küme | Kamera yakınlaşır | Tekil noktalara doğru açılım; puan/API mutation yok |
| Tek marker / alt listedeki nokta | `_showMachine -> GET /api/map-pins/{id}` | Nokta detay sheet'i |
| `Yol Tarifi` | url_launcher ile hedef enlem/boylam | Harici Google/Apple/Yandex vb. desteklenen rota uygulaması |
| Yenile simgesi | Aktif filtrelerle yükleme | Makine oluşturmaz |
| Admin uzun basma | `_addOfficialPin -> POST /api/admin/map-pins` | Manuel yönetici noktası; resmî DOA sertifikası değildir |

### 8.3 Arama sözleşmesi

`lat`, `lng` zorunludur. İsteğe bağlı: `radiusKm`, `limit`, `offset`, `materials`,
`pointTypes`, `openOnly`, `city`, `district`, `south/north/west/east`.
Varsayılan yeni arama sayfası 100; sunucu üst sınırı 1000. UI 1000 çizilmiş
sonuca ulaşıp daha fazlası varsa yakınlaştırma/ilçe seçimi ister.

```json
{
  "items": [{"id": 10, "title": "Kaynak nokta adı", "latitude": 38.72,
    "longitude": 35.48, "address": "Kaynak adres", "pointType": "DIM",
    "acceptedMaterials": ["pet", "glass"], "binStates": {"pet": true},
    "distanceKm": 1.2, "scheduleStatus": "UNKNOWN", "snapshotAt": "ISO-8601"}],
  "total": 29, "limit": 100, "offset": 0, "hasMore": false
}
```

`acceptedMaterials`: teknik destek; `binStates`: kaynak hazne bildirimi;
`scheduleStatus`: saat programına göre OPEN/CLOSED/UNKNOWN; `snapshotAt`: veri
tarihi. Bunların hiçbiri kullanıcının uzaklığına göre değiştirilmez veya canlı
makine kabul garantisi sayılmaz. Ham `binList` ayrıntıda korunur.

`/locations` yalnız küçük idari envanter projection'ını 60 saniye önbellekler.
Şehir/ilçe eşlemesi adresin idari kısmına dayanır: Diyarbakır'daki Urfa Yolu,
Şanlıurfa sayılmaz. 81 il/ilçe dağılımı [envanterde](doa-city-counts-tr.md).

Eski `/nearby` liste yanıtı ve `/nearest` uyumluluk yolları korunmuştur. Yeni
istemci genel aramada eski sunucudan 404 alırsa `/nearby` deneyebilir; yeni
şehir seçicisi güncel backend'i gerektirir. Harita HTTP isteği seed çalıştırmaz.

## 9. Görevlerim

Amaç: tarama, eğitim, sosyal katılım ve sürdürülebilir alışkanlıkları takip
edip uygulama ödülü vermek. Görev sayısı fiziksel çevresel etki sayısı değildir.

| Kontrol / durum | Fonksiyon / API | Çıktı |
|---|---|---|
| Ekrana giriş | `_fetchQuests -> GET /api/quests` | QuestProgress listesi; geçersiz eski satırlar tüm listeyi devirmeden ayıklanır |
| Kategori chip'i | `_selectedDomain` | Yüklenmiş listede yerel filtre |
| Yenile / tekrar dene | `_refresh/_retry -> GET` | Liste veya yeniden denenebilir hata |
| `Tamamladım` / beyan işlemi | `_checkIn -> POST /api/quests/{questId}/check-in` | Artan currentAmount ve completed; bu aşama doğrudan claim değildir |
| Otomatik tarama görevi | UI butonu değil; ScanService olay yayını | QuestEngine trigger/criteria değerlendirir |
| `Puanı Al` | `_claim -> POST /api/quests/progress/{progressId}/claim` | quest, pointsAwarded, totalPoints, message |
| Başarı kutusu `Harika` | Dialog kapanır, `_refresh` | Görünür liste korunur; beyaz ekran için transient sıfırlama yapılmaz |

Katalog 100 temel + 100 alışkanlık görevi içerir. Her biri `Quest` tanımı;
kullanıcı ilerlemesi `UserQuestProgress` satırıdır. Yanıtta görev kimliği,
ilerleme kimliği, kod, başlık, açıklama, hedef, ödül, kategori/domain,
currentAmount, completed, claimed, expiry/checkInAvailable gibi alanlar vardır.

**İki farklı yol:**

- Otomatik: tarama/market/sosyal olay -> `QuestEventPublisher` ->
  `QuestEngineService` trigger değerlendirmesi -> progress. Sadece ilgili olay
  gerçekten yayımlanıyorsa ilerler; katalogda olmak bütün trigger'ların sahada
  doğrulandığı anlamına gelmez.
- Beyan: criteria `selfReport=true` olan görevde kullanıcı check-in yapar.
  `oncePerDay` ise İstanbul gününde ikinci check-in engellenir. Fotoğrafla
  kanıtlanmış eylem değildir.

Claim, doğru kullanıcıya ait ve tamamlanmış ilerlemeyi kilit altında kontrol
eder; iki eşzamanlı talep iki ödül üretmez. Zaten claimed ise awarded=0 dönebilir.
Gece 00:00 İstanbul scheduler'ı süresi geçen tamamlanmamış günlükleri arşivler
ve son 30 gün aktif kullanıcılara uygun günlük katalogdan en fazla 3 atama tamamlar.

### Görev kategorisi, konusu ve tetikleyici aynı alan değildir

- `QuestCategory`: DAILY, WEEKLY, MILESTONE, SOCIAL, ECO_IMPACT, HIDDEN, FACTION.
  Süre/ilerleme grubunu anlatır; yalnız adı DAILY diye her soru kullanıcıya her gün atanmaz.
- `QuestDomain`: RECYCLING, TRANSPORTATION, ENERGY_SAVING, WATER_SAVING,
  COMMUNITY, STREAK, SOCIAL, EDUCATION, ECO_MARKET, ECO_IMPACT. Ekrandaki konu
  filtresi bu sınıflamaya dayanır.
- `QuestTriggerType`: SCAN_SPECIFIC_WASTE, REACH_SCORE, BUY_MARKET_ITEM,
  INVITE_FRIEND, AI_CONFIDENCE_HIGH, TIME_BASED, LOCATION_BASED, STREAK_DAYS.
  Engine switch/evaluator'ı olayı kriterleriyle eşler.
- `criteria` içindeki malzeme, saat, yer, selfReport veya oncePerDay gibi
  değerler aynı trigger'ın farklı görevlerde farklı çalışmasını sağlar.

Örneğin plastik tarama olayı bir SCAN_SPECIFIC_WASTE görevini ilerletebilir;
toplu taşıma alışkanlığı ise fotoğraftan otomatik kanıtlanmış sayılmayıp beyan
akışı kullanır. Bir quest başlığında çevresel sayı geçmesi gerçek sensör ölçümü
elde edildiği anlamına gelmez.

## 10. Atık rehberi ve Eko-Akademi

Ana kart `EducationGuideScreen` wrapper'ını, o da güncel `WasteGuideScreen`'i
açar. Ders metni ve yerel soru sunumu `assets/data/academy_guide.json` içindedir;
tamamlanan modüller/ödül PostgreSQL'dedir.

10 konu: plastik, cam, kağıt/karton, metal, elektronik, kompozit, bitkisel yağ,
tekstil, organik, tehlikeli/tıbbi. Toplam 30 soru; her modülde 3 soru.

| Kontrol | İşlem | Çıktı |
|---|---|---|
| Listeye giriş | AcademyRepository.loadModules + GET `/api/education/progress` | Ders kartları ve tamamlanan categoryId işaretleri |
| Arama | Türkçe karakter toleranslı yerel filtre | Eşleşen malzeme/başlıklar; AI isteği değildir |
| Tümü / tamamlanan / tamamlanmayan | Yerel filtre | Sunucu ilerlemesine göre kartlar |
| Modül kartı | EducationDetailScreen | Ders metni; teslim, örnekler, hazırlık, güvenlik, sık hata ve yeniden kullanım |
| Kaynak bağlantısı | url_launcher | Resmî/eğitim kaynağını tarayıcıda açar |
| `Sınavı Başlat` | AcademyQuizScreen | İlk soru; henüz ödül yok |
| Seçenek | `_selectedOption` | Tactile seçili durum; tek başına submit değil |
| `Cevabı Onayla` | `_confirmAnswer` | Yerel doğru/yanlış geri bildirim, cevap dizisine ekleme |
| `Sonraki Soru` | `_next` | Sonraki 3 sorudan biri |
| `Sonucu Gör` | 2/3 ise `_claimCompletion` | POST `/api/education/complete/{categoryId}` |
| Yeniden dene | `_restart` veya gönderimi yeniden deneme | Sorular sıfırlanır veya aynı güvenli submit tekrar denenir |
| `Akademiye Dön` | Navigator.pop(categoryId) | Ana listede yeşil tamamlandı işareti |

Submit gövdesi:

```json
{"quizVersion":"2026-10-24-v1","answers":[0,2,1]}
```

İndeksler örnektir; geçerli cevap oldukları iddia edilmez. Backend
`EducationQuizCatalog.requirePassing` ile sürüm/kategori/üç cevap/en az iki
doğru koşulunu kendi güvenilen kataloğundan kontrol eder. İstemcinin
`correctCount=3` iddiası ödül için yeterli değildir.

Başarılı ilk modül **30 puan** verir. `UserEducationProgress` ve
`GamificationAction(education_<categoryId>)` tekrar ödülü engeller. Yanıt:
`categoryId`, `newlyCompleted`, `pointsAwarded`, `totalPoints`, `message`.
Tekrar çözmek eğitim için mümkündür; tekrar para/puan basılmaz. Eski quiz sürümü
veya cevap göndermeyen istemci güncelleme gerektiren hata alabilir.

`GET /api/education/quiz/{categoryId}` sunucu quiz sözleşmesini dışarı sunar;
mevcut Flutter soruları esas olarak paketli asset'ten çizer.

## 11. Karbon ayak izi

### 11.1 Ana 20 soruluk yol

Eco Merkezi -> Karbon Ayak İzi -> `CarbonFootprintScreen`. Hesap motoru
`frontend/lib/models/carbon_footprint.dart` içindedir.

| Kontrol | İşlem | Çıktı |
|---|---|---|
| Yanıt kartı | `_select` | O soru için option index saklanır; API yok |
| `Devam Et` | `_next` | Seçim/form geçerliyse sonraki soru |
| Geri | `_previous` | Önceki soru; ilk soruda önceki ekran |
| Soru 2 altındaki isteğe bağlı alan | Benzin/dizel, litre, aylık/yıllık | Özel araç tahminlerinin yerine tüketim hesabı |
| Soru 11 altındaki isteğe bağlı alan | Elektrik kWh, dönem, hane kişi sayısı | İlgili elektrik tahminlerinin yerine ölçülebilir tüketim |
| `Karbonumu Hesapla` | `_calculate` | Yerel toplam; en az 3 sn radar animasyonu |
| Sonuç | POST `/api/gamification/carbon-footprint` ile `{score: annualKg}` | Bir defalık görev/rozet ödülü; sonuç kg ve ton |
| `Karbonunu Sıfırlamaya Başla!` | Sonuç ekranındaki navigasyon | Uygulamaya dönüş/eylem motivasyonu; karbon satın alma/offset işlemi yok |

20 soru: ana ulaşım, haftalık araç km, uçuş, şehirlerarası seyahat, beslenme,
gıda kaynağı, paket servis, gıda israfı, ısınma, yalıtım, beyaz eşya, klima,
giyim, tek kullanımlık plastik, kağıt tüketimi, önceki ayrıştırma, video izleme,
bulut depolama, cihaz yenileme, e-posta alışkanlığı.

```text
Anket kg/yıl = seçili seçeneklerin ağırlık toplamı
Ton/yıl = kg/yıl / 1000
<4 ton: Doğa Koruyucusu
4–7 ton (7 dahil): Gelişime Açık
>7 ton: Karbon Canavarı
```

Ek tüketim girilmezse mevcut seçenek ağırlıkları aynen kullanılır. Girilirse
ilgili tahminler yerine geçer; aynı kullanım iki kez toplanmaz:

- Elektrik: aylık kWh × 12 × 0,469 / hane kişi sayısı; beyaz eşya/klima ve
  elektrikli ısıtıcı senaryosunda ilgili ısınma tahminleri çakışma için temizlenir.
- Benzin: aylık litre × 12 × (8,887 / 3,785411784).
- Dizel: aylık litre × 12 × (10,180 / 3,785411784).
- Yıllık girilen miktar önce 12'ye bölünüp aylığa çevrilir.

Katsayı kapsamı `impact-methodology.md` içinde açıklanır. Anket bilimsel olarak
tam kişisel envanter veya denetlenmiş karbon azaltımı değildir. Skor CO₂
sonucudur, istenen ödül miktarı değildir; ilk tamamlama ödülünü backend **75**
olarak belirler. Aynı görev anahtarı tekrarında ödül sıfırdır. Sunucu bu eski
yolda 20 cevabı yeniden hesaplamaz; istemcinin özet skorunu alır, buna göre
değişken XP vermez. API erişilemezse yerel sonuç ve ödül senkronizasyon hatası ayrıdır.

### 11.2 Ayrıntılı karbon ve beyan API'leri

`DetailedCarbonScreen` eski/alternatif tüketim ekranıdır; ana kart şu an onu açmaz.
`POST /api/carbon/assessments` tüketim girdilerini sunucuda hesaplar ve geçmişe
bağlar; GET aynı kayıtları getirir. Sonuç kaynak/kapsam/eksik bileşenleriyle sunulur.

`/api/carbon/actions` ayrı atık eylem kayıtlarıdır: malzeme, kütle, önceki/yeni
yönetim yolu ve istemci kayıt anahtarı. GET liste, POST beyan, PUT kütle düzeltme,
DELETE silme yapar. EPA WARM senaryo farkı hesaplanabilir; aynı kayıt anahtarı
ikinci eylem oluşturmaz. `/summary` sayım/toplam tahmini farkı getirir.
Bu akış tarama sonrası görünür bir zorunlu form değildir; fiziksel iade veya
Türkiye saha CO₂ ölçümü diye sunulmaz. Profil varsa bu kayıtları “Kullanıcı beyanı” olarak gösterir.

## 12. Eco-Market ve avatarlar

### 12.1 Market

Amaç: uygulama puanıyla sanal koleksiyon ve seri koruması. Fiyatı UI değil
`MarketService.CATALOG` belirler.

| Kod | Fiyat | Sunucuda değişen |
|---|---:|---|
| `leaf_frame` | 100 | ownedMarketItems'e eklenir |
| `ocean_frame` | 200 | ownedMarketItems'e eklenir |
| `earth_frame` | 300 | ownedMarketItems'e eklenir |
| `streak_freeze` | 250 | streakFreezeCount +1; tüketilebilir |

| Kontrol | Fonksiyon / API | Çıktı |
|---|---|---|
| Ekrana giriş | GET `/api/auth/me` | Bakiye ve sahip olunanlar |
| Satın alma | `_purchase -> POST /api/market/purchase/{itemId}` | Güncel UserResponse |
| Başarı `Tamam` | Diyaloğu kapatır | Yeni bakiye/koleksiyon görünür |
| Başarı `Paylaş` | EcoShareService | Yerel paylaşım menüsü |
| Yetersiz puan | Hata yanıtı | Bakiye düşmez; uyarı diyaloğu |
| Sahip olunan ürün | UI sahiplik; backend idempotent kontrol | Yeniden ücret alınmaz |
| Seri dondurucu | Yeniden satın alınabilir | Bir adet koruma ekler |
| Yenile | GET me | Hesap sunucuyla eşleşir |

Puan düşerken **lifetimePoints düşmez**. Market ürün sahipliği DB'dedir; bütün
çerçevelerin ayrı kuşanma/görsel uygulanma özelliği tamamlanmış sayılmaz.
Gerçek ağaç dikimi, kahve kuponu veya ödeme entegrasyonu yoktur.

### 12.2 Avatar yolu

`AvatarEvolutionScreen` -> GET `/api/gamification/avatar-tiers`.
20 basamak, gerekli lifetime XP, açık/kilitli/kuşanılmış durumunu gösterir.
Seviye eşikleri 0, 150, 300, ... 2850'dir; bu sürümde 20. seviye 2850 lifetime XP.

| Kontrol | İşlem | Çıktı |
|---|---|---|
| Yol düğümü | Açık/kilitli kademe ayrıntısı | Şartlar/kuşanma durumu |
| Açık avatarı kuşanma | `equipAvatar(level)` | PUT `/api/gamification/avatar/{level}/equip` |
| Kilitli avatar | Sunucu da XP eşiğini denetler | Yetersizse işlem reddi; görseli değiştirmek yetmez |
| Yenile | Kademe GET | Yeni kazanılan XP'yle açık seviyeler |

### 12.3 AvatarSelectionScreen

Profildeki avatar düzenleme simgesiyle açılır. 20 PNG asset GridView'da gösterilir.
Kilitliler grayscale/lock; kullanıcı açılmış bir görsele dokununca onay diyaloğu
açılır. Onay, aynı equip API'sini çağırır; `UserResponse` önce ApiService state'ini,
sonra `Navigator.pop(updatedUser)` ile profil başlığını günceller.

Avatar seçilince `selectedAvatarPath`, `equippedAvatarLevel`,
`profileImagePreference=AVATAR` yazılır ve özel fotoğraf tercihi/URL bırakılır.
Özel fotoğraf yüklemek ise PHOTO tercihini öne geçirir. Açılabilecek en yüksek
seviye, seçili avatar ve harcanabilir bakiye üç ayrı bilgidir.

### 12.4 Rozet ve iki seri kavramı

- Tarama serisi: ödüllü tarama günüyle ilerler. Önceki gün devam; bir gün
  kaçırılıp seri dondurucu varsa bir koruma tüketilip devam edebilir.
- Giriş serisi: login günleri ayrı tutulur; profil takviminde görüntülenir.
  Giriş yapmak fiziksel tarama yapmış sayılmaz.
- `BadgeService`: 7/30 tarama günü, 50 plastik, 50 cam ve 50 beğeni eşikleri.
- Yeni rozet DB'ye bir defa eklenir; bildirim ve gruplarda sistem etkinliği oluşabilir.
- Gamification state içinde karbon/akademi gibi action tabanlı başka başarılar da
  bulunur; bütün rozetler tek enum'dan geliyormuş gibi yorumlanmamalıdır.

## 13. Liderlik tablosu

Eco Merkezi -> Liderlik -> iki tab.

| Kontrol | API | Mantık / çıktı |
|---|---|---|
| `Şehrim` | GET `/api/leaderboard/city` | Kullanıcının DB'deki şehriyle aynı kullanıcılar; totalPoints azalan |
| `Arkadaşlarım` | GET `/api/leaderboard/friends` | Kabul edilmiş arkadaşlar + kişinin kendisi |
| Aşağı çek / yeniden dene | Aynı tabın loader'ı | Güncel puan sırası |
| Avatar / satır | PublicProfileScreen(userId) | GET `/api/social/users/{id}` |

Satırda rank, isim/avatar ve izin verilen puan bilgisi vardır; kendi satırı
vurgulanır. Bu sıralama harcanabilir `totalPoints` tabanlıdır, lifetime XP
veya doğrulanmış çevresel etki sırası değildir. Markette harcama sıralamayı
etkileyebilir; avatar seviyesi sırf harcama yüzünden düşmez.

## 14. Topluluk: keşif, arkadaşlar ve davetler

Kaynak: `community_screen.dart`, `CreateCommunityGroupSheet`,
`CommunityGroupController`, `SocialController`. Ana sekme yalnız 18 yaş ve üstü
kullanıcıda vardır; backend de topluluk işlemlerinde yaş kontrolü yapar.

### 14.1 Sayfanın bölümleri ve sorgular

| Kontrol | Tetiklediği işlem | Kullanıcının gördüğü sonuç |
|---|---|---|
| `Gruplar` sekmesi | GET `/api/groups` | Ad, kapak, konum, üye sayısı ve katılım durumu olan grup kartları |
| Grup adı araması | 350 ms debounce sonrası aynı GET; arama query'si değişir | Eşleşen grup listesi; her harfte grup oluşturulmaz |
| İl/ilçe filtresi | Çoklu il seçimi; GET sorgusuna `cities` ve uygun durumda `district` | Seçilen bölgelerdeki gruplar |
| `Tüm Şehirler` | İl kümesini boş bırakır | İl filtresi uygulanmaz; sahte bir şehir gönderilmez |
| `Yenile` AppBar simgesi | `_reload()` | Gruplar, arkadaşlar, istekler ve davetler yeniden okunur |
| Boş grup listesindeki `Yenile` | `_reloadGroups()` | Yalnız grup sorgusu; oluşturma formu açılmaz |
| `Arkadaşlar` sekmesi | GET `/api/social/friends`, GET `/api/social/friends/requests` | Kabul edilmiş arkadaşlar ve bekleyen istekler |
| Kullanıcı arama | En az 3 karakter + 350 ms debounce; GET `/api/social/users/search` | Kullanıcı adı/ad/soyad için kısmi eşleşmeler |
| Kullanıcı arama sonucu / arkadaş avatarı | `PublicProfileScreen(userId)` | Ayrıntılı profil ve izin verilen sosyal işlemler |
| Arkadaşlık isteği `Kabul Et` | POST `/api/social/friends/requests/{id}/accept` | ACCEPTED ilişki; liste yenilenir |
| Arkadaşlık isteği `Reddet` | POST `/api/social/friends/requests/{id}/reject` | İstek reddedilir; arkadaşlık kurulmaz |
| `Davetler` sekmesi | GET `/api/social/group-invites` | Gelen eski grup/etkinlik davetleri; aşağıdaki mimari sınır geçerlidir |
| Davette `Kabul Et` | POST `/api/social/group-invites/{id}/accept` | Sunucu davet durumunu ve ilgili eski üyeliği günceller |
| AppBar davet kodu simgesi | Kod giriş penceresi | Ana gövdede ikinci bir “Davet kodun var mı?” satırı yoktur |
| Kod penceresinde `Gruba Git` | POST `/api/groups/invite/{inviteCode}/join` | Kodun işaret ettiği yeni gruba katılım / şifre hatası |
| Grup oluşturma FAB'ı | `CreateCommunityGroupSheet` | Yeni grup formu; yalnız bu kontrol oluşturmayı başlatır |

Tek il seçildiğinde ilçe filtresi o ilin ilçelerini gösterir. Çoklu il veya
başka il seçilince eski ilçe geçersiz bırakılır. Eski arama yanıtının yeni
arama sonucunu ezmesini önleyen sorgu kimliği kontrolü vardır.

### 14.2 Grup oluşturma ve gruba girme

Form; kapak görseli, grup adı, açıklama, il/ilçe/mahalle, üye limiti ve isteğe
bağlı şifre toplar. Konum alanları merkezi `TurkishLocations` kataloğunu kullanır;
mahalle alanı tüm Türkiye'nin resmî mahalle envanteri değildir.

`Oluştur` -> `ApiService.createCommunityGroup` -> POST `/api/groups`:

- Fotoğraf yoksa JSON gövde `CommunityGroupRequest` olur.
- Fotoğraf varsa multipart: `group` JSON parçası ve `coverImage` dosyası.
- Backend kullanıcıyı FOUNDER olarak `GroupMember` kaydına ekler.
- Şifre açık metin saklanmaz; şifre doğrulaması sunucudadır.
- `CommunityGroupResponse` döner; form kapanır ve liste güncellenir.

Bir grup kartına basınca kişi zaten üyeyse `GroupChatScreen` açılır. Değilse
katılım akışı çalışır: POST `/api/groups/{groupId}/join`. Şifresiz grupta doğrudan
katılır; şifreli grupta doğru `joinCode` gerekir. Davet kodu, grup şifresi ve
eski arkadaş daveti aynı kavram değildir. Kapasite doluluğu sunucuda kontrol edilir.

**Önemli mevcut mimari sınırı:** `SocialService.inviteFriend/acceptInvite`
metotları hâlâ eski `Event`, `EventMember`, `GroupInvite` modellerini kullanır.
Yeni `/api/groups` üyeliği `CommunityGroup/GroupMember` üzerinden işler.
Bu nedenle sosyal “Davetler” listesini yeni grubun davet koduyla tamamen aynı
çalışan sistem olarak anlatmak doğru değildir. Bu belge bu uyumsuzluğu gizlemez;
dokümantasyon sırasında API davranışı değiştirilmedi.

## 15. Grup sohbeti

Kaynak: `group_chat_screen.dart`, `ChatController`, `RealtimeChatController`,
`ChatService`, `WebSocketConfig`.

### 15.1 İlk açılış, geçmiş ve canlı bağlantı

```text
Grup kartı
 -> grup ayrıntısı + üyeler + son 50 mesaj
 -> GET /api/chat/groups/{groupId}?limit=50&offset=0
 -> /ws WebSocket bağlantısı + STOMP CONNECT Bearer token
 -> /topic/groups/{groupId} aboneliği
 -> /topic/groups/{groupId}/typing aboneliği
 -> mesaj geldiğinde kimliğiyle birleştir -> sohbet listesi
```

HTTPS backend için WebSocket adresi WSS olur. Mesajdaki kullanıcı adı/id'si
istemciden güvenilir kimlik diye alınmaz; oturum ve grup üyeliği sunucuda doğrulanır.
Önceki audit'te düzeltilen STOMP accessor kullanımı bağlantının gerçek
Principal bilgisini korur.

Geçmiş yukarı kaydırıldığında `offset` artar ve önceki 50 kayıt alınır.
HTTP yanıtıyla canlı yayında aynı mesaj gelirse ID ile birleştirilir; iki balon
oluşturulmamalıdır. Eski konuma gitmeden her seferinde bütün geçmiş indirilmez.

Ekranda 8 saniyelik bir timer hâlâ vardır: bağlantı durumuna göre geçmiş
fallback'i ve grup/etkinlik metadatası yenilemesi içindir. “Bütün polling tamamen
kaldırıldı” demek doğru değildir. Aynı anda birden fazla yenilemeyi engelleyen
koruma ve görünür/aktif ekran kontrolleri vardır. STOMP yeniden bağlantı süresi
5 saniye, heartbeat aralığı 10 saniye; yazıyor durumu yaklaşık 4 saniyede düşer.

### 15.2 Sohbet kontrolleri

| Kontrol / hareket | İstek veya yerel işlem | Çıktı |
|---|---|---|
| Metin alanına yazmak | Yerel metin; STOMP `/app/groups/{id}/typing` | Diğer üyelerde kısa ömürlü “Yazıyor...” |
| `Gönder` | POST `/api/chat/groups/{id}`; `message` ve isteğe bağlı `replyToMessageId` | Kaydedilmiş `ChatMessageResponse`; metin temizlenir, balon görünür |
| Ataç / ek | Alt panel | Kamera, galeri, PDF seçenekleri |
| Kamera / galeri | ImagePicker -> sıkıştırma -> multipart POST `/api/chat/groups/{id}/attachments` | Yetkili medya URL'si olan mesaj |
| PDF | FilePicker -> dosya boyutu/türü kontrolü -> aynı attachments API | Dosya adı/boyutu ve indirme düğmeli belge balonu |
| Belgedeki indir / aç | `downloadAuthorizedMedia` | JWT'li bytes alınır; FilePicker.saveFile ile cihaza kaydetme akışı |
| Fotoğrafa basmak | Yetkili görsel görüntüleyici | Büyük resim; özel medyaya anonim erişim verilmez |
| Mesajı sağa kaydırmak / `Yanıtla` | Yerel yanıt seçimi | Composer üzerinde alıntı önizlemesi |
| Alıntı önizlemesinde çarpı | Yerel state temizleme | Sonraki mesaj bağımsız gönderilir |
| Uzun bas -> emoji tepkisi | POST `/api/chat/groups/{g}/messages/{m}/reactions` | Güncel tepkiler ve sayıları; canlı güncelleme |
| Uzun bas -> `Sabitle` | PUT `/api/groups/{g}/pin` | Üstte sabit mesaj/etkinlik alanı; rol kontrolü |
| Uzun bas -> `Sil` | DELETE `/api/chat/groups/{g}/messages/{m}` | Silinmiş mesaj durumu; diğer üyelerde güncellenir |
| Avatar / gönderen adına basmak | Kullanıcı ID'siyle profil önizlemesi | Gizlilik-aware profil alt paneli; `Profili Aç` tam sayfaya geçer |
| AppBar grup adı / bilgi | `_GroupInfoSheet` | Bilgi, üyeler ve medya sekmeleri |
| AppBar anket | Yetkiliyse anket formu | Soru ve en fazla 4 seçenek |
| AppBar etkinlik | Yetkiliyse `CreateGroupEventSheet` | Grup içi etkinlik formu |
| En yeni mesaja dönme | Scroll controller | Liste sonuna kaydırma; yeni kayıt yaratmaz |

**Taşıma ayrıntısı:** Görünür Flutter gönderme butonu HTTP POST kullanır.
Sunucu veritabanına yazdıktan sonra STOMP ile gruba yayınlar. Ayrıca backend'de
`/app/groups/{id}/messages` STOMP gönderim handler'ı vardır; bunun varlığı görünür
butonun mutlaka o kanaldan gönderdiği anlamına gelmez. Kalıcılık HTTP, canlı
dağıtım STOMP şeklindeki mevcut davranışı ayırmak hata ayıklamada önemlidir.

Fotoğraflar `chat_image_compressor.dart` ile en fazla 1600x1600 boyuta getirilir;
JPEG kalitesi kademeli düşürülerek 2 MB altı hedeflenir. Desteklenen platformda
CPU işi `compute` ile ayrılır. Sığmayan/çözülemeyen görsel anlaşılır hatayla
reddedilir. PDF seçimi ayrı akıştır; telefon klavyesinin doğal emoji girişi
kullanılır, özel emoji picker zorunluluğu yoktur.

`@` yazıldığında üyelerden yerel öneri açılır. Seçilen ad mesajın metninde
görünür; yalnız bu arayüz davranışından işletim sistemi push bildirimi üretildiği
sonucu çıkarılamaz.

### 15.3 Mesaj türleri ve anket

`ChatMessageResponse` gönderen kimliği/avatar bilgisi, tarih, metin, dosya/görsel,
alıntı, tepki ve anket alanlarını taşır. Görünüm mesaj türüne göre ayrılır:

- Normal metin: gönderende primary ton, alıcıda surface ton; isim ve saat.
- Görsel: yetkili resim; yükleme/hata/fallback.
- Belge/PDF: dosya simgesi, adı, boyutu, indirme.
- SYSTEM: katılım/rol/başarı gibi ortalanmış etkinlik satırı.
- POLL: soru, seçenekler, oy yüzdeleri.
- GROUP_EVENT: etkinlik kartı; tarih, konum, kontenjan, katılımcılar.
- Silinmiş mesaj: normal içerik yerine silinme durumu.

Anket formundaki `Oluştur` -> POST `/api/chat/groups/{g}/polls`:
`question` ve `options` sunucuda doğrulanır. Seçeneğe dokunmak -> POST
`/api/chat/groups/{g}/messages/{m}/vote`, gövde `optionIndex`.
Güncellenmiş mesaj toplam oyları/yüzdeleri getirir. Uzun bas -> `Anketi Sil`
DELETE `/api/chat/groups/{g}/polls/{m}`; oluşturan kişi veya yetkili yönetici
sunucuda kontrol edilir. Salt UI'da butonu gizlemek güvenlik kuralı değildir.

## 16. Grup bilgisi, yönetim ve etkinlikler

### 16.1 Grup bilgi alt paneli

Sohbet AppBar'ından açılan `_GroupInfoSheet`, eski `GroupInfoScreen` ile aynı
widget değildir. Yeni panelin üç bölümü vardır:

| Bölüm / kontrol | Veri / işlem | Sonuç |
|---|---|---|
| Bilgi | Kapak, grup adı, açıklama, konum, üye sayısı | Grup özeti |
| Davet kodunu kopyala | Clipboard | Pano; API çağrısı yok |
| Grup ayrıntıları | Navigator -> GroupDetailsScreen | Etkinlikler ve yönetim alanı |
| Üyeler | GET `/api/groups/{id}/members` ile alınan kayıtlar | Rol etiketi ve profil açma |
| Üye avatarı | PublicProfileScreen(userId) | Seçilen kişinin doğru profili |
| Kurucuda üye çıkar | DELETE `/api/groups/{g}/members/{u}` | Üyelik silinir; liste yenilenir |
| Medya | GET `/api/chat/groups/{g}/media` | Sohbette paylaşılan görsellerin ızgarası |
| Gruptan Ayrıl | DELETE `/api/groups/{id}/membership` | Üyelik sonlanır; sohbetten çıkılır |

Kurucu kendi grubundan sıradan ayrılma yapamaz; kurucu koruması vardır.
Medya galerisinin varlığı bütün geçmiş metinlerin tek seferde indirildiği
anlamına gelmez; medya için ayrı sorgu bulunur.

### 16.2 GroupDetailsScreen ve gerçek yetki sınırları

Bu ekran grup özeti, üyeler ve grup etkinliklerini toplar. `Yenile`, grup ve
etkinlik sorgularını tekrar çalıştırır. Etkinlikler
GET `/api/groups/{id}/events` ile gelir; tarih/katılımcı bilgisi DTO'dan okunur.

Mevcut görünür yönetim menüsü `_group.isFounder` şartıyla açılır:

| Yönetim işlemi | API | Sunucu kuralı |
|---|---|---|
| Grup adı/açıklama/kapak düzenle | PUT `/api/groups/{id}`; JSON veya multipart `group` + `coverImage` | Admin/Founder bilgi güncelleyebilir; görünür menü daha dardır |
| Üye ekle | POST `/api/groups/{id}/members` | Mevcut service kurucu yetkisi ister |
| Yönetici yap | POST `/api/groups/{g}/members/{u}/admin` | Yalnız kurucu |
| Yöneticiliği kaldır | DELETE aynı yol | Yalnız kurucu |
| Üye çıkar | DELETE `/api/groups/{g}/members/{u}` | Mevcut service kurucu yetkisi ister; kurucu çıkarılamaz |
| Grubu sil | DELETE `/api/groups/{id}` | Yalnız kurucu |

Yeni kapak seçilmediyse düzenleme eski kapağı silmek anlamına gelmez. Medya
DB'deki kalıcı kayda bağlıdır. Grup silme, o gruba bağlı içeriklerin kontrollü
temizlenmesidir; bütün kullanıcıların veya veritabanının silinmesi değildir.

Uygulama hesabının `AppUser.role` değeriyle grup üyeliğinin `GroupRole` değeri
ayrıdır. Bir gruptaki ADMIN, platformun SUPERUSER'ı olmaz. FOUNDER/ADMIN/MEMBER
izinlerini yalnız tasarım metninden değil `CommunityGroupService` kontrollerinden
okumak gerekir. Eski join-request endpoint'leri bulunsa da mevcut normal katılım
akışı şifresiz/doğru şifreyle doğrudan katılımdır.

### 16.3 Etkinlik oluşturma

Kurucu/yönetici -> `Etkinlik Oluştur` -> `CreateGroupEventSheet`:

1. İsteğe bağlı kapak fotoğrafı seçilir.
2. Başlık ve açıklama yazılır.
3. Native tarih ve saat seçilir; geçmiş zaman/geçersiz form engellenir.
4. İl -> ilçe seçilir; açık adres eklenir.
5. Kontenjan girilir.
6. Konum simgesi, izin verilirse gerçek GPS'i alır; reverse geocoding mümkünse
   alanları doldurur. Erişilemeyen konum gerçek adresmiş gibi uydurulmaz.
7. `Oluştur` POST `/api/groups/{g}/events` çağırır. Fotoğrafla multipart `event`
   JSON parçası + `coverImage`; fotoğrafsız JSON handler kullanılır.
8. `GroupEvent`, katılım ilişkileri ve sohbet etkinlik mesajı üzerinden kart
   gösterilir; `GroupEventResponse` döner.

### 16.4 Etkinlik kartındaki kontroller

| Buton | API | Ekrandaki değişiklik |
|---|---|---|
| `Katıl` | POST `/api/groups/{g}/events/{e}/rsvp`, `status: ATTENDING` | Katılımcı sayısı ve kendi katılımı güncellenir |
| `Katılmıyorum` | Aynı POST, `status: NOT_ATTENDING` | Olumsuz RSVP; yer doldurmaz |
| `Ayrıl` | DELETE `/api/groups/{g}/events/{e}/rsvp` | Kişinin olumlu katılımı kaldırılır |
| Katılımcılar / avatarlar | GET `/api/groups/{g}/events/{e}/attendees` | İsim/avatar listesi; profil açma |
| Sabitle | PUT `/api/groups/{g}/pin` | Üst sabit alan ilgili etkinliği gösterir |
| Etkinliği sil | DELETE `/api/groups/{g}/events/{e}` | Kart/liste güncellenir; yetkisi olmayan silemez |

Kontenjan ve aynı kişinin iki kez sayılmaması backend sorumluluğudur.
Etkinlik silmede mevcut yeni servis admin yetkisi ister. Yalnız geçmişte
oluşturan kişi olmak, sonradan yönetici yetkisini kaybetmiş kullanıcıya sonsuz
silme yetkisi veriyor diye varsayılmamalıdır.

## 17. Profil ve ayarlar

### 17.1 Profil verisi nereden gelir?

`ProfileScreen` açılışında güncel kullanıcı okunur; tarama geçmişi ve kendi
sosyal profili ayrı sorgularla yüklenir. Giriş serisi ve karbon özeti bağımsız
yüklenebilir. Tek bir profil metni yerel mock listeden oluşturulmuyor.

| Kontrol / alan | İşlem | Sonuç |
|---|---|---|
| Profil başlığı | GET `/api/auth/me` | Ad/kullanıcı adı, konum, seviye, bakiye, seçili görünüm |
| Avatar düzenleme simgesi | AvatarSelectionScreen -> equip API | Onaylanan avatar kendinde de anında görünür |
| `N gün giriş serisi` | LoginActivitySheet; GET `/api/users/login-history?month=YYYY-MM` | Giriş yapılmış günlerin aylık takvimi |
| Takvim önceki ay oku | Aynı GET farklı ay | Geçmiş ay; gelecek ay kapalı |
| Eco-Etki alanı | Gerçek kayıt türüne göre tarama/rozet/karbon özeti | Puanı sahte ölçülmüş CO2'ye çevirmeden uygulama aktivitesi |
| Rozet yatay listesi | Kendi sosyal/gamification cevabı | Açılan rozetler; yeni ödülde maskot kutlaması |
| Tarama geçmişi `Tümünü Gör` | ScanHistoryScreen'e mevcut kayıtları aktarır | Kronolojik malzeme, tarih ve uygulama puanı |
| Aşağı çek / tekrar dene | Profil loader'ını yeniler | Güncel kullanıcı ve ilgili kayıtlar |
| Sağ üst dişli | SettingsScreen gömülü cam alt panel | Hesap/görünüm/oturum ayarları |

`ScanHistoryScreen` elindeki tarama listesini kullanır; her açıldığında ayrıca
bir HTTP isteği yaptığını varsaymamak gerekir. GET `/api/scans` eski liste
sözleşmesi korunmuştur; mesaj geçmişi gibi sayfalı değildir.

Avatar seçiminden dönen `UserProfile`, API state'ine ve profilin kendi Future
verisine uygulanır. Sekmeye geri dönme/ayar panelinin kapanması da yenileme
tetikleyebilir. Böylece “başkası yeni avatarı görüyor ama kendisi eskiyi
görüyor” sorunu yalnız backend verisinin doğru olmasıyla geçiştirilmez.

**Seri ayrımı:** GET `/api/users/login-history` yalnız takvim okur, yeni ödül
vermez. GET `/api/users/login-streak` ise mevcut `LoginActivityService.record`
yoluyla o günün giriş kaydını oluşturabilir; salt okunur endpoint diye
anlatılmamalıdır. Aynı gün tekrar çağrı tekrar giriş ödülü üretmez.

### 17.2 SettingsScreen: her ayarın etkisi

| Menü / kontrol | API veya yerel işlem | Ne değişir? |
|---|---|---|
| `Profili Düzenle` | EditProfileScreen -> PUT `/api/users/profile` | İsim/konum ve izin verilen profil alanları |
| `Parolayı Değiştir` | ChangePasswordScreen -> PUT `/api/users/password` | Mevcut parola doğrulanır, yeni parola BCrypt ile saklanır |
| `Profil Fotoğrafı` | ImagePicker -> multipart POST `/api/users/profile-picture`, dosya alanı `image` | DB medya URL'si ve PHOTO tercihi |
| Profil gizliliği | PUT `/api/users/privacy` | PUBLIC veya FRIENDS_ONLY; özel fotoğraf/ayrıntı erişimi değişir |
| Tema seçimi | Yerel hesap tercihi + PUT `/api/users/theme` | Orman/Okyanus/Gün Batımı/Karanlık Eko anında uygulanır ve DB'ye kaydolur |
| Dil | Alt panel | Şimdilik Türkçe; diğer diller çalışan çeviri olarak sunulmaz |
| Görev hatırlatıcı anahtarı | `settings.mission_reminders` yerel tercihi | Bu cihazdaki tercih; backend push aboneliği oluşturmaz |
| Topluluk güncellemeleri anahtarı | `settings.community_updates` yerel tercihi | Tek başına OS push veya sunucu bildirim filtresi değildir |
| Superuser Dashboard | Yetkili kullanıcıda moderasyon sayfası | `/api/superuser` işlemleri; yalnız görsel gizleme değil backend yetkisi de gerekir |
| `Çıkış Yap` | POST `/api/auth/logout`, ardından token/state temizliği | Login'e pushAndRemoveUntil; önceki hesap içeriği tutulmaz |

13–17 yaş kullanıcıda özel fotoğraf kontrolü devre dışıdır; lock simgesi ve
açıklama görünür. Avatar kullanılabilir. Profil resmi yalnız dosya cache'inde
değil backend `MediaAsset` kaydına bağlı tutulur. Alternatif upload yolu
`/api/auth/me/profile-picture` da uyumluluk için vardır.

Tema başlangıçta yerel tercih ile yüklenir; oturum tanınınca hesap bağlamında
sunucu tercihiyle eşitlenir. Yazılar sıraya alınır ve hesap revizyonu kontrol
edilir: A hesabından geç gelen sonuç B hesabının temasını ezmemelidir.

`Çıkış Yap`, refresh/access oturum iptalini ve güvenli saklama temizliğini
başlatır. Kullanıcı/puan/gamification ve yetkili medya oturumu da temizlenir;
ThemeController hesap bağını bırakır. Yereldeki herkese ait onboarding/theme
tercihlerini körlemesine silmek yerine hesap anahtarları korunur.

### 17.3 Düzenleme ve parola formları

EditProfileScreen mevcut alanları doldurur; ad/soyad, doğum tarihi ve
il/ilçe/mahalle gibi düzenlenebilir alanları validasyondan geçirir. Doğum tarihi
yaş kuralını aşamaz. İl değişince eski ilçe/mahalle temizlenir. İl/ilçe aynı
81/973 merkezi katalogdan gelir; mahalle seçimi bütün Türkiye'nin resmî mahalle
listesinin tamamlandığı iddiası değildir.

`Kaydet` bekleme durumunda ikinci gönderim yapmaz. Başarı UserResponse'u
ApiService'e uygular, SnackBar gösterir ve geri dönüşte profil yenilenir.
ChangePasswordScreen mevcut/yeni/onay parola alanlarını ve göz simgelerini
kullanır; yeni/onay eşleşmeden API gönderilmez. Göz simgesi sunucu çağrısı yapmaz.

## 18. Başka kullanıcının profili

Kaynak: `public_profile_screen.dart`. Liderlik satırı, arkadaş arama sonucu,
grup üyesi veya mesaj avatarı -> `PublicProfileScreen(userId)` ->
GET `/api/social/users/{id}`.

Yanıtta görülebilir alanlar, `detailsVisible`, arkadaşlık durumu, beğeni durumu,
likeCount, avatar/fotoğraf tercihi ve izin verilen puan/rozet/geçmiş yer alır.

| Kontrol | API | Mantık |
|---|---|---|
| `Beğen` | POST `/api/social/users/{id}/like` | Aynı kişi için tek like ilişkisi |
| Beğeniyi geri al | DELETE aynı yol | Like ilişkisi ve sayaç güncellenir |
| `Arkadaş Ekle` | POST `/api/social/friends/{id}/request` | PENDING; henüz gizli profil erişimi vermez |
| Bekleyen istek | Mevcut state | Tekrar tekrar istek üretmez |
| `Arkadaşlıktan Çıkar` | DELETE `/api/social/friends/{id}` | ACCEPTED ilişki biter; gizli alan erişimi yeniden değerlendirilir |
| Kullanıcıyı bildir | Sebep formu -> POST `/api/social/reports/users/{id}` | Moderasyon kuyruğuna rapor |
| Engelle | POST `/api/social/blocks/{id}` | Kullanıcı etkileşimi için blok kaydı |
| Yeniden dene / aşağı çek | Aynı profil GET'i | Güncel gizlilik ve sayaçlar |

Engel kaldırma DELETE `/api/social/blocks/{id}` API'si de bulunur; API'nin
varlığı her ekranda ayrı bir buton olduğu anlamına gelmez.

Gizli profil ve arkadaş olmayan izleyicide ayrıntılar kilit/blur ile
sınırlanır. Yetişkin + PHOTO tercihi + izin verilen görünürlük varsa özel resim
gösterilir; aksi durumda avatar seçilir. Kullanıcının kendi profili ve kabul
edilmiş arkadaşı farklı erişim bağlamıdır. Yaş/gizlilik yalnız Flutter'da
resmi gizlemekle korunmaz; `MediaAccessService` dosya bytes erişimini de denetler.

İki kişi arasında DM endpoint'i/ekranı yoktur; arkadaşlık özel sohbet anlamına gelmez.

## 19. Bildirimler ve moderasyon

### 19.1 Zil, sayaç ve bildirim listesi

`MainTabNavigator` ön plandayken yaklaşık 15 saniyelik timer ile bildirim ve
topluluk okunmamış sayaçlarını yeniler. Her tür için çakışan istek koruması
vardır. Arka plana geçiş ve topluluk sekmesinin seçilmesi okunma davranışını etkiler.

| Kontrol | API | Çıktı |
|---|---|---|
| Ana AppBar zil | NotificationsScreen; GET `/api/notifications?limit=50` | Başlık, mesaj, tip ve tarih listesi |
| Kırmızı sayaç | GET `/api/notifications/unread-count` | Okunmamış bildirim sayısı |
| Sayfayı görüntüleme | Okunmamış varsa POST `/api/notifications/read-all`, sonra liste yenileme | DB isRead güncellenir |
| Tümünü okundu işaretle simgesi | POST `/api/notifications/read-all` | Okunmamış sayaç düşer |
| Aşağı çek / tekrar dene | GET liste | Yeni kayıtlar |
| Community sekme rozeti | GET `/api/chat/unread-count` | Okunmamış sohbet sayacı |
| Community okundu işareti | POST `/api/chat/read` | Kullanıcının okunma sınırı güncellenir |

Bildirim satırları bilgilendiricidir; her tipe dokunmanın otomatik ilgili
etkinliğe deep-link yaptığı varsayılmamalıdır. Badge, sosyal etkileşim, davet,
streak ve konum olayları uygulama içi bildirim üretebilir. FCM/APNs entegrasyonu
olmadan bunlar telefonun işletim sistemi push bildirimi değildir.

### 19.2 Superuser kontrol merkezi

Ayarlar -> yetkili hesap -> `SuperuserDashboardScreen`.
Sunucu `/api/superuser` üzerinde `hasRole('SUPERUSER')` uygular.

| Kontrol | Endpoint | Sonuç / yetki |
|---|---|---|
| Raporları yükle / yenile | GET `/api/superuser/reports` | Açık/ilgili moderasyon raporları |
| Kullanıcı listesi | GET `/api/admin/users` | Hesaplar ve moderasyon durumu; Superuser |
| Grup sohbet denetimi | GET `/api/superuser/audit/chat/{groupId}` | Yetkili moderasyon için mesaj listesi |
| Kullanıcı denetimi | GET `/api/superuser/audit/user/{userId}` | Raporlanan kullanıcının ilgili mesajları |
| Genel duyuru gönder | POST `/api/superuser/broadcast` | Başlık/mesaj tüm kullanıcılara in-app kayıt; alıcı sayısı |
| Yasakla | POST `/api/superuser/users/{id}/ban` | Hesap banned; güncel yetki kontrolleri uygular |
| Yasağı kaldır | POST `/api/superuser/users/{id}/unban` | banned kaldırılır |
| Askıya al | POST `/api/superuser/users/{id}/suspend` | Süreli suspendedUntil; UI'daki süre seçimi/gövdesi kullanılır |
| Grubu sil | DELETE `/api/superuser/groups/{id}` | Moderasyon kapsamında grup silinir |
| E-posta ile Admin yap | POST `/api/admin/assign-admin` | Platform ADMIN rolü; grup kuruculuğu değil |

Denetim API'si bütün kullanıcılara açık bir sohbet dışa aktarımı değildir.
Rapor ekranındaki eylemler başarısız olursa hata gösterilir; arayüzde raporun
görünmesi bir hesabı otomatik suçlu/banlı yapmaz.

## 20. Veritabanı ve kalıcılık

PostgreSQL tek ilişkisel veri kaynağıdır. Önemli modeller:

| Model / ilişki | Ne saklar / neden var? |
|---|---|
| `AppUser` | Kimlik, BCrypt parola, doğum/konum, rol/gizlilik, tema, bakiye/lifetime XP, avatar tercihi, seri/hesap durumu |
| `RefreshToken` | Refresh oturumu, süre/iptal; erişim token'ıyla aynı şey değildir |
| `LoginDay` | Kullanıcı + giriş günü; aylık profil takvimi ve giriş serisi |
| `ScanHistory` | Kullanıcı, malzeme, zaman, uygulama puanı, analiz/fotoğraf kimliği; fiziksel iade belgesi değil |
| `MapPin`, `MapPinBin` | DOA kaynağı, UUID, nokta tipi, koordinatlar, adres/şehir, ham program/durum, pet/cam/alüminyum hazneleri |
| `Quest`, `UserQuestProgress` | Görev tanımı ile kişiye ait miktar/tamamlandı/claim/süre ayrı tutulur |
| `UserEducationProgress` | Kullanıcı + categoryId tamamlanma; tek seferlik akademi ödülü |
| `GamificationAction` | Karbon gibi action tabanlı bir defalık tamamlanmalar / tekrar koruması |
| `UserBadge` | Kullanıcı + kazanılmış badge; bildirim ve profil |
| `CommunityGroup`, `GroupMember` | Grup tanımı ve FOUNDER/ADMIN/MEMBER üyeliği |
| `GroupEvent`, `GroupEventAttendance` | Grubun etkinliği, tarih/konum/kontenjan ve RSVP |
| `ChatMessage` | Grup veya eski etkinlik bağlamı, gönderen, tip, metin/dosya, reply ilişkisi ve silinme durumu |
| `ChatReaction`, `ChatPoll`, `ChatPollVote` | Tepki ve anket/oy ilişkileri; tek mesaj JSON'una sınırsız yazma yerine ilişkisel kayıtlar |
| `Friendship`, `ProfileLike`, `UserBlock` | İstek/kabul ilişkisi, profil beğenisi ve engel |
| `GroupInvite`, `GroupJoinRequest` | Eski arkadaş daveti ve yeni gruptaki eski onay akışı; normal şifreli katılımdan ayrı |
| `MediaAsset` | Görsel/PDF bytes, içerik tipi ve sahiplik; container geçici diski silinse de DB kaydı korunur |
| `AppNotification` | Kişiye ait başlık/mesaj/tür/isRead/zaman |
| `SocialReport` | Kullanıcı veya eski event/grup raporu, neden ve moderasyon durumu |
| `CarbonAssessment`, `WasteAction` | Tüketim hesap girdisi/sonucu ve ayrı kullanıcı beyanı atık eylemi |
| `Event`, `EventMember`, `EventAttendance`, `GroupMission`, `GroupWasteReport` | Eski etkinlik-tabanlı topluluk modeli; yeni GroupEvent ile aynı tablo değildir |

JPA entity doğrudan her yerde JSON'a verilmez; controller'lar DTO kullanır.
Bu hem alan/gizlilik seçimini hem ilişkilerden sonsuz JSON recursion riskini yönetir.
Kullanıcı satırı ve ilgili ilerleme üzerindeki DB kilitleri, eşzamanlı market
harcaması ve claim'de çift ödül gibi yarış durumlarını sınırlar.

Flyway migration'ları uygulama şemasının sürümlü değişiklikleridir. Entity
alanındaki Java varsayılanı, PostgreSQL DEFAULT ve migration ayrı kavramlardır;
bu rehberin üretilmesi hiçbir migration çalıştırmaz veya canlı veri silmez.

## 21. Eski ve uyumluluk akışları

Repoda bulunmak, ana menüden güncel akışta açılmak anlamına gelmez.

| Dosya / API | Durum ve işlev |
|---|---|
| `event_chat_screen.dart` + `/api/chat/events/{id}` | Eski Event üyeliğiyle çalışan sohbet; STOMP events topic ve tipli mesaj geçmişi bulunur |
| `group_info_screen.dart` | Eski Event modelindeki grup/üye/görev bilgisi; yeni `_GroupInfoSheet` ile karıştırılmamalı |
| `event_location_map_screen.dart` | Kendisine verilen etkinlik konumunu haritada gösteren yardımcı ekran; genel DOA envanteri değil |
| `/api/events` | Eski Event CRUD, üyelik, RSVP; ana keşif artık `/api/groups` kullanır |
| `/api/events/{id}/missions`, `/waste-reports` | Eski grup görev/atık raporları; görünür yeni GroupEvent formuyla aynı şey değildir |
| `/api/social/group-invites` | Eski Event davet ilişkisi; yeni invite-code katılımından ayrı |
| `/api/scans/eligibility` | Ambalaj koşulu hesaplama korunur; sadeleştirilen ResultScreen artık soru formunu göstermez |
| `detailed_carbon_screen.dart`, `/api/carbon/assessments` | Kaynak katsayılı kısa tüketim hesap ekranı/API; ana giriş 20 soruluk ekrandır |
| `/api/carbon/actions` | Kullanıcı beyanı gramaj/yönetim yolu; ResultScreen'de eylem kaydet düğmesi yoktur |
| `/api/gamification/redeem` | Önceki gamification redemption yolu; güncel dört ürünlü market `/api/market/purchase` kullanır |
| `/api/auth/google` | Backend legacy doğrulama yolu; Flutter'da Google login düğmesi/istemcisi yoktur |
| `/api/map-pins`, `/nearest`, `/nearby` | Eski istemci/format desteği; güncel sayfalı harita `/search` kullanır |

### Mevcut metin ve davranış ayrımları

Kaynak incelemesinde aşağıdaki noktalar çıktı; bu belge bunları olmuş gibi
göstermek yerine sınır olarak kaydeder:

1. ResultScreen'deki tekrar-fotoğraf uyarısında “bugün/günde” anlatımı bulunabilir;
   güncel backend aynı dosya hash'i için kullanıcıya ikinci ödülü ömür boyu vermez.
2. Settings alt açıklamasındaki yerel AI ifadesi her deployment'ta doğru değildir;
   gerçek sağlayıcı `AI_PROVIDER=gemini|local` ve sunucu ayarıyla seçilir.
3. Ortak paylaşım metni avatar yükseltme anlatır; her tarama avatar yükseltmiş olmaz.
4. Bildirim anahtarları yerel tercihtir; tam push altyapısı değildir.
5. Arkadaş daveti ve grup raporunun bir kısmı eski Event bağlamındadır. Yeni
   CommunityGroup için aynı ID alanını varsayarak kullanmak mantıksal risk taşır.
6. Yeni grubun sunucu/arayüz yönetim yetkileri bazı yerlerde farklı darlıktadır:
   UI kurucuya özel menü kullanırken sunucu bazı bilgi güncellemelerine ADMIN izin verir.
7. Satın alınmış çerçeve kaydı, bütün avatar widget'larında otomatik donatılmış
   kozmetik çizildiği anlamına gelmez; sahiplik ve görünür equip ayrı işlemdir.

Bu maddeler yeni bug fix olarak uygulanmadı; talep mevcut projenin açıklanmasıdır.

### 21.1 Eski EventChatScreen kontrolleri

Bu ekran yeni `CommunityGroup` kimliğiyle rastgele açılmamalıdır; kendisine
eski `Event` modeli verilir. Görünümü benzer olsa da endpoint bağlamı farklıdır.

| Kontrol | Eski API / sonuç |
|---|---|
| İlk mesajlar / eski mesajlar | GET `/api/chat/events/{eventId}`; 30'lu geçmiş sayfası |
| Metin gönder | POST `/api/chat/events/{eventId}`; sonrasında `/topic/events/{id}` canlı yayını |
| Yazıyor | STOMP `/app/events/{id}/typing` ve `/topic/events/{id}/typing` |
| Fotoğraf / PDF | `/api/chat/events/{id}/media` veya `/attachments`; yetkili medya |
| Avatar | `PublicProfileScreen(senderId)` |
| AppBar grup bilgisi | Eski `GroupInfoScreen(event: ...)` |
| Katılıyorum / katılamıyorum | PUT `/api/events/{id}/rsvp` |
| Katılımcıları göster | GET `/api/events/{id}/attendees` |
| Üyeler | GET `/api/events/{id}/members` |
| Yönetici yap / üye çıkar | Eski events members admin/remove yolları |
| Grup görevi oluştur | POST `/api/events/{id}/missions`; başlık/hedef/kategori |
| Grup atık raporu | POST `/api/events/{id}/waste-reports`; beyan niteliğinde miktar |
| Grubu sil | DELETE `/api/events/{id}`; eski event yapısını kaldırır |

Eski GroupInfoScreen'deki arkadaş daveti `/api/social/groups/{eventId}/invites/{friendId}`
çağırır; raporlama `/api/social/reports/groups/{id}` yolunu kullanır. Bunlar yeni
GroupDetailsScreen'in kendiliğinden birebir yerine geçmez. EventLocationMapScreen
yalnız kendisine verilen koordinatı gösterir; yeni grubun il/ilçe gizliliği veya
genel DOA makine arama sayfası olarak düşünülmemelidir.

### 21.2 Korunan kısa karbon ekranı

DetailedCarbonScreen açılırsa elektrik kWh, kişi sayısı, benzin/dizel litre ve
aylık/yıllık dönem alanları vardır. `Hesapla` POST `/api/carbon/assessments`
çağırır; `assessment` sonucu ve kaynak/kapsam açıklaması gösterilir.
Alt bölüm GET `/api/carbon/actions` ile önceki kullanıcı beyanlarını alır.
Kütleyi düzeltme diyaloğunda gram -> kg çevrilip PUT `/api/carbon/actions/{id}`;
silme DELETE aynı yol çağrılır. Bunlar görev puanından otomatik ölçülmüş
tasarruf üretmek değildir. Ana Eco Merkezi kartı bu ekran yerine 20 soruluk
CarbonFootprintScreen'e bağlıdır.

## 22. Dağıtım, izleme ve geliştirme altyapısı

| Bileşen | Nasıl tetiklenir / ne verir? |
|---|---|
| Backend Dockerfile | Maven ile JAR -> Java 17 runtime; Spring `PORT` ortam değişkeninde dinler |
| Docker Compose | Backend ve repoda tanımlı izleme servislerini aynı ağda başlatır; Neon konfigürasyonunda yerel PostgreSQL servisi zorunlu değildir |
| Neon PostgreSQL | Datasource ortam değişkenleriyle SSL bağlantısı; gerçek kimlik bilgileri belgede verilmez |
| Render | Container dağıtımı ve environment; dosya mevcutluğu canlı deploy başarısı demek değildir |
| GET `/api/health` | Public keep-alive; sabit `EcoVision Backend is awake!` string'i, büyük veri/AI işleme yok |
| GET `/actuator/health` | Sağlık durumu; bağlı bileşenler/config'e göre UP/DOWN |
| GET `/actuator/prometheus` | JVM/HTTP/pool gibi metriklerin Prometheus text çıktısı |
| Prometheus | 15 saniyede actuator scrape; zaman serisi saklama |
| Grafana | Prometheus/Loki veri kaynaklarıyla panel; uygulama kullanıcı hesabından ayrı yönetici oturumu |
| Promtail -> Loki | Container loglarını toplayıp sorgulanabilir log akışına yollar |
| Alertmanager | Instance down/JVM bellek kuralı -> tanımlı alıcı; webhook placeholder gerçek bildirim değildir |
| SonarQube | Maven scanner ile statik analiz; backend runtime API'si değildir |
| springdoc Swagger | `/swagger-ui.html` / `/swagger-ui/index.html`; `/v3/api-docs` makine-okunur OpenAPI |
| GitHub Actions | Main push -> Java 17/backend test -> Docker build/push; GitHub Secrets gerekir |
| Kubernetes manifestleri | Backend replica/service ve PostgreSQL/PVC/Secret tanımları; uygulanmadıkça çalışan cluster yoktur |
| `scripts/build_android.ps1` | Uyumluluk kontrolleriyle yerel Android derleme; telefon kurulumuyla aynı işlem değil |
| `ml/` | Eğitim, split, ölçüm ve model kartı; prod backend eğitimi her startup'ta tekrarlamaz |

AI seçiminde `AI_PROVIDER=local` kullanılırsa paketli modelin etkinleşmesi için
`ML_ENABLED=true` ve geçerli model dosyası gerekir. `GEMINI_ON_UNCERTAIN_ENABLED`
ile isteğe bağlı düşük-skor bulut yolu vardır; varsayılan kapalıdır. Bu, bir
Gemini model hatasında otomatik birçok farklı modele deneme zinciri değildir.
Gemini seçildiyse fotoğraf sunucu üzerinden dış bulut sağlayıcısına gider;
ONNX seçildiyse inference sunucuda CPU'da yapılır. İkisinde de frontend'in
çevrimdışı telefonda model çalıştırdığı iddia edilmez.

Swagger'da `Authorize` ile Bearer token verildikten sonra yetkili API denenir.
Public health izni `/api/groups` veya özel medya için anonim yetki vermez.
Monitoring güvenliği üretimde ayrı erişim politikası gerektirir; grafana
örnek admin şifresi uygulama kullanıcı parolası olarak değerlendirilmemelidir.

WebSocket yapılandırması `enableSimpleBroker("/topic")` kullanır; broker o
Spring Boot sürecinin belleğindedir. Kubernetes'te `replicas: 2` dosyası bulunması,
iki pod arasında mesajların harici bir broker ile paylaşıldığı anlamına gelmez.
Mevcut REST verisi ortak PostgreSQL'de kalıcıdır; canlı yayın kapsamı ve yatay
ölçekleme ayrı mimari konulardır.

Veri seed'i backend başlangıcında manifest/hash ve upsert kurallarıyla işlenir;
haritayı her sürükleme yeni seed başlatmaz. Var olan kullanıcılar veya grup
üyelikleri sıradan harita isteğiyle yeniden oluşturulmaz.

## 23. API sözleşmeleri ve hata çıktıları

### 23.1 Hangi veri tipi neye döner?

Tam Java alanları [API/DTO ekinde](api-route-inventory-tr.md) verilmiştir.
`@JsonProperty` varsa JSON alan adı Java adından farklıdır; örneğin
`updated_user_points`, `machine_eligible`, `is_recyclable`.

| Yanıt tipi | Kullanıldığı yer | Anlamı |
|---|---|---|
| `AuthResponse` | Login/register/refresh | accessToken, refreshToken, süre ve user |
| `UserResponse` | Me/profil/tema/market/avatar | Güncel hesap, bakiye/lifetime, avatar/fotoğraf ve gizlilik |
| `GeminiScanResponse` | Multipart analyze | detections, scan, updated_user_points, provider/model/inferenceMode/needsConfirmation |
| `ScanAnalysisResponse` | Analyze içindeki scan | Kaydedilen malzeme, zaman, uygulama ödülü, analysisId ve rewardStatus |
| `DoaLocationService.Inventory` | Harita il seçimi | 81 ilin ve ilçelerin kaynak sayıları/koordinat kapsamı |
| `DoaMapService.Page` | Harita search | items, total, limit, offset, hasMore |
| `CommunityGroupResponse` | Grup liste/detay/join | Grup bilgisi, üyelik/rol, katılım ve sabit içerik |
| `GroupEventResponse` | Grup etkinliği/RSVP | Grup/oluşturan, başlık, tarih, konum, kontenjan, katılımcılar |
| `ChatMessageResponse` | Mesaj POST/geçmiş/STOMP | Aynı mesajın kalıcı kimliği ve render için gereken tipli alanlar |
| `PublicProfileResponse` | Sosyal profil | İzin verilen profil + friendship/like/detailsVisible |
| `QuestProgressResponse` | Görevler/check-in | Quest tanımı, kişinin ilerlemesi, tamamlandı/claim durumu |
| `QuestClaimResponse` | Claim | Güncel puan ve gerçekten verilen ödül; ikinci claim aynı ödülü vermez |
| `EducationCompletionResponse` | Quiz submit | Geçme/puan/tamamlanmış olma bilgisi |
| `ResponseEntity<byte[]>` | GET `/api/media/{id}` | JSON değil; doğrulanmış dosya bytes + Content-Type/erişim başlıkları |

Her API `UserResponse` döndürmez; her POST de yeni kayıt yaratmaz. Refresh
oturumu yeniler, read-all mevcut kayıtları işaretler, reaction mevcut ilişkiyi
değiştirebilir. Ekran, sözleşmenin türüne göre farklı state uygular.

### 23.2 Standart hata

Controller exception handler'ı güvenli JSON üretir. Örnek yalnız şema içindir:

SecurityConfig'in filtre seviyesindeki 401/403 yanıtları daha kısa
`status/error/message` gövdesi kullanır; her hata mutlaka timestamp/path
alanı taşır diye istemci yazılmamalıdır.

```json
{
  "timestamp": "2026-10-24T12:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "İşlem tamamlanamadı. Girdiğiniz bilgileri kontrol edin.",
  "path": "/api/example"
}
```

| Durum | Tipik anlam / Flutter davranışı |
|---|---|
| 400 | Form/iş kuralı; alan mesajı veya SnackBar, tekrar giriş mümkün |
| 401 | Token/geçersiz kimlik; uygun durumda refresh, başarısızsa oturum temizleme |
| 403 | Rol, grup üyeliği, yaş veya medya gizliliği izin vermiyor |
| 404 | Kaynak bulunamadı; bazı eski backend uyumluluk durumları ayrıca ele alınır |
| 423 | Giriş denemeleri nedeniyle geçici kilit |
| 426 | Eski akademi istemcisi sürümlü quiz sözleşmesini karşılamıyor |
| 429 | Gerçek sağlayıcı kotası/limit gibi durum; otomatik ikinci farklı modele kaçış yok |
| 502/503/504 | Dış servis/erişilebilirlik/timeout; tekrar dene ve anlaşılır hata |
| 500 | Beklenmeyen hata; kullanıcıya güvenli mesaj, stack trace JSON'a dökülmez |

JSON yerine Render/ara sunucudan HTML gelirse `FormatException` yakalanır ve
“Sunucuya şu an ulaşılamıyor...” benzeri anlaşılır mesaja dönüştürülür. Ortak
API isteklerinde süre sınırı vardır; normal çağrılar yaklaşık 30 saniye,
analiz daha uzun pencere kullanır. Bütün eski yardımcı çağrıların aynı timeout
mekanizmasını kullandığını varsaymak doğru değildir.

Refresh eşzamanlılığı tek oturum yenilemeye indirgenir; logout/hesap değişiminde
eski yanıtın yeni oturumu geri getirmemesi için oturum nesli kontrolü vardır.
Özel medya istekleri de güncel yetkili oturumla yapılır; görsel URL'sinin varlığı
herkese erişim kanıtı değildir. Parola hash'i, API anahtarı ve refresh sırları
kamuya açık profil DTO'sunda gösterilmez.

## 24. Örnek uçtan uca kullanım senaryoları

### A. İlk kayıt -> ilk tarama

1. Login -> `Hesap Oluştur` -> RegisterScreen.
2. Form + doğum tarihi + il/ilçe + sözleşmeler -> POST `/api/auth/register`.
3. BCrypt/kural kontrolü -> AuthResponse -> güvenli oturum state'i.
4. Hesabın `hasSeenOnboarding_<id>` tercihi yoksa dört sayfalık tanıtım.
5. `Hemen Başla` veya `Atla` -> tercih true -> ana Tarama sekmesi.
6. `Fotoğraf Çek` -> ImagePicker -> multipart analyze.
7. AI sonucu ve sunucu puanı -> ResultScreen. Tarama fiziksel geri dönüşüm değildir.

### B. Cam tespiti -> rehber -> DOA noktası

1. ResultScreen'deki cam malzemesi model tahminidir; barkod/iade doğrulaması değil.
2. `Atık Rehberi` -> cam modülünün içerik ve güvenlik kuralları.
3. Geri -> `DOA Makinelerini Haritada Göster` -> glass malzeme filtresi.
4. GPS veya il seçimi + viewport -> sayfalı `/api/map-pins/search`.
5. Nokta -> detay -> kaynak/hazne/program/bilinmeyen durum ayrımı.
6. `Yol Tarifi` -> harici navigasyon. Para/depozito EcoVision tarafından ödenmez.

### C. Görev tamamla -> ödül -> avatar

1. Fotoğraf taraması ilgili quest olayını yayınlar; yalnız uygun görev ilerler.
2. Görevlerim -> tamamlanan kart -> `Ödülü Al` -> progress ID ile claim.
3. Sunucunun kilitli kontrolü -> bakiye ve lifetime XP güncellenir.
4. Avatar Yolu -> açılan seviye -> equip onayı -> UserResponse.
5. Profil, seçili avatarı anında uygular. Markette puan harcamak lifetime
   avatar seviyesini geriye düşürmez.

### D. Gruba katıl -> konuş -> etkinliğe katıl

1. 18+ hesap -> Topluluk -> grup ara/il seç.
2. Gruba katıl; şifreli ise doğru parola. Başarı -> GroupChatScreen.
3. `Gönder` -> HTTP kayıt -> STOMP yayın -> diğer üyede yeni balon.
4. Yönetici `Etkinlik Oluştur` -> form + cover -> grup etkinlik API'si.
5. Mesaj akışında kart -> üye `Katıl` -> RSVP -> kontenjan/katılımcı güncellenir.
6. Avatar -> doğru userId ile profil -> istenirse arkadaşlık isteği.

### E. Akademi -> tek ödül

1. Rehber -> modül -> dersi oku -> `Teste Başla`.
2. Paketli asset'in sürümlü üç sorusu -> üç seçimi gönder; sunucu kendi cevap
   kataloğuyla doğrular. Quiz GET'i vardır ama mevcut ekranın esas soru kaynağı asset'tir.
3. Backend cevap anahtarıyla en az 2 doğruyu doğrular.
4. İlk başarılı tamamlamada 30 puan ve progress kaydı.
5. Rehberde yeşil tik. Tekrar başarılı çözüm yeni 30 puan üretmez.

## 25. Ne var, ne yok ve neyi doğruladık?

Bu rehber mevcut kodun açıklamasıdır. Dokümantasyon sırasında uygulama,
authentication, veri modeli veya API davranışı değiştirilmedi; canlı Render,
Neon veya GitHub'a yazma yapılmadı.

Önceki yerel denetimin kayıtlı kanıtı [final-audit-verification.json](final-audit-verification.json)
ve [ayrıntılı rapordadır](ecovision-final-audit-tr.md). Bu belge için bütün
uygulama testleri yeniden çalıştırılmış gibi gösterilmez:

- Kayıtlı önceki sonuç: 114 backend, 124 Flutter, 11 veri testi başarılı.
- Kayıtlı kaynak/yerel PostgreSQL/API eşleşmesi: 4.037 nokta;
  2.162 DIM, 1.764 MIN, 111 SDM.
- 81 il / 973 ilçe ortak katalog doğrulaması vardır; 3 DOA adresinin ili
  çözümlenememiştir. Bu kayıtlar sahte il atamasıyla kapatılmaz.
- Debug APK ve web derleme kanıtı vardır. Release APK denemesi önbellekte
  bulunmayan Flutter engine bağımlılığı/ağ nedeniyle tamamlanamamıştır.
- ONNX modeli gerçekten eğitilmiş ve ayrılmış test kümesinde ölçülmüştür;
  bu, Türkiye saha başarısı veya depozito uygunluğu doğruluğu değildir.
- 512 MB yerel container testi üretim eşzamanlı yük kapasitesini kanıtlamaz;
  Render status 137'nin kesin nedenini yalnız bu sonuçla söylemek doğru değildir.
- iOS dağıtımı, gerçek para/ağaç dikimi, resmî DOA ödeme/barkod doğrulaması,
  doğrulanmış karbon kredisi, tamamlanmış e-posta parola kurtarma ve OS push
  sistemi varmış gibi sunulmamalıdır.

**Okuma yolu:** Kullanıcı butonunun ne yaptığını bu rehberin ilgili ekranında;
tam URL/parametre/Java dönüş tipini [API ekinde](api-route-inventory-tr.md);
çalıştırılmış testin komut/sonucunu [denetim raporunda](ecovision-final-audit-tr.md)
inceleyin. Böylece kodda bulunma, arayüzde erişilebilir olma ve canlıda doğrulanma
birbirine karıştırılmaz.
