# 25 Ekim 2026: tarama, harita, karbon ve görev düzeltmeleri

## Doğrulanan nedenler

1. **Harita:** Render public `/v3/api-docs` cevabında `/api/map-pins/search`
   ve `/locations` yoktu. `/nearby`, `/nearest`, `/{id}` ve ana liste vardı.
   Yeni istemcinin `search` yolu eski sunucuda `/{id}` ile eşleşip Long dönüşüm
   hatasına düşebiliyor. Önceki istemci yalnız 404'te fallback yaptığı için bu
   400 hatası kullanıcıya yansıyordu. Bu bulgu veritabanının boş olduğunu kanıtlamaz.
2. **Tarama:** Geniş ekranda serbest AspectRatio, yüksekliği ekranı aşan bir
   tarama çerçevesi üretiyordu. Küçük ekran/yüksek yazı ölçeği de ayrıca test edildi.
3. **Görevler:** 320 px genişlik ve 1,6 yazı ölçeğinde 200 kayıt kaydırılırken
   `_StatusLabel` Row'u 36–59 px taşıyordu. İlk stres denemesinde 115 layout
   exception oluştu. Kayıtların değişken yüksekliği de test kaydırmasında hesaba alındı.
4. **Android:** Gradle 8.12, Java 25 ile çalışamaz. Yüklü JBR 21.0.8 kullanılabilir.
   Gradle wrapper veya AGP'yi gereksiz yere yükseltmedik.

## Uygulanan değişiklikler

- `home_screen.dart`: hareketli tarama çizgisi ve çerçeve korundu; overlay tam
  alana yerleştirildi. Çerçeve kullanılabilir yüksekliğe ve en fazla 360 px
  genişliğe sığar. Çok kısa erişilebilirlik ekranlarında içerik kaydırılabilir.
- `api_service.dart`: yalnız eksik route 404 / bilinen parametre dönüşüm 400
  hatasında `/nearby` uyumluluk yolu kullanılır. Yetki ve gerçek iş kuralı
  hataları gizlenmez. Konum/yarıçap doğrulanır. Eksik route bilgisi beş dakika
  tutulur; her kamera hareketinde başarısız ek istek atılmaz.
- Eski liste API'sinde 100'lük görünür sayfalar daha geniş ama sınırlı bir
  prefix üzerinden alınır; istemci aynı noktaları ikinci kez eklemez. Eski
  endpoint toplam sayıyı vermiyorsa bunu kesin ülke envanteri gibi sunmaz.
- `map_screen.dart`: il/ilçe seçicisi ve “Bu alanda ara” düğmesi kaldırıldı.
  Malzeme, nokta türü, yarıçap/sınırsız, program ve otomatik viewport sorgusu
  korundu. Sınırlar geçerli koordinat aralığına alınır. Şehir API'leri eski
  istemciler ve veri denetimleri için backend'den silinmedi.
- `missions_screen.dart`: durum etiketi esnek satırda bölünür; miktar/eylem
  alanı Wrap kullanır. Kayıt kimlikleri ve kategoriye ait scroll key'leri sabittir.
  Yenileme ve claim/check-in istekleri çakışmaya karşı korunur.
- `carbon_footprint_screen.dart`: açılır “Daha net hesapla” alanları kaldırıldı.
  20 sorunun her birinde doğrudan isteğe bağlı, birimi belirtilen sayısal alan
  vardır. Yöntem/tür sorularında kategori seçimi hâlâ gereklidir. Diğer nicel
  sorularda yalnız sayı girmek yeterlidir. Hızlı yanıta dokunmak o sorunun sayı
  girişini temizler; sayı girilirse seçenek aralığının yerine kullanılır.
- Sonuç yerelde kısa animasyonun ardından gösterilir; sunucu puan yanıtı
  sonucu bloke etmez. Ödül yalnız sunucu doğrulamasıyla kesinleşir. Puan API'si
  ve tek-seferlik ödül mantığı değiştirilmedi.

## Karbon hesabının sınırı

Bu değişiklikte eğitimli bir karbon ML modeli üretilmedi. Projede bunu eğitmek
ve saha doğruluğunu ölçmek için hedef verisi yok. Deterministik hesap “ML” diye
etiketlenmedi. Boş sayı alanları eski 20 soruluk anket sonucunu aynen korur.

- Araç km girdisi: hafta × 52; varsayılan benzinli araç için 7 L/100 km
  varsayımı ve EPA yakıt katsayısı. Bu, aracın gerçek tüketim ölçümü değildir.
- Elektrik: aylık hane kWh × 12 × 0,469 / kişi sayısı; mevcut ETKB katsayısı.
- Bu girdiler ilgili araç/elektrik tahminlerinin yerine geçer; iki kez toplanmaz.
- Diğer sorular eski anket ağırlıkları arasında açık, parçalı doğrusal ölçekleme
  kullanır; kaynaklı tam kişisel emisyon envanteri veya ML tahmini değildir.
- Negatif/NaN/sonsuz ve birime uymayan aşırı sayılar reddedilir. Ayrıştırma
  bonusu nedeniyle negatif olabilen katkı ile toplam emisyon farklı kavramdır.

Metodoloji kaynakları: [impact-methodology.md](impact-methodology.md).

## Yerel JDK ayarları

Flutter `config --jdk-dir` yüklü Android Studio JBR 21'e ayarlandı. Kök ve
frontend VS Code çalışma alanlarında Gradle JVM seçimi 21; eski import
başlatıcısının Java 25 seçmesini engellemek için build server kapalı. Android
Studio'nun yerel Gradle ayarı `#GRADLE_LOCAL_JAVA_HOME` üzerinden aynı JBR'ye bağlandı.
Makineye özel `.idea`, `.vscode` ve `.gradle/config.properties` Git dışında kalır.

IDE önceden açıkken eski import hata listesi kalabilir: VS Code'da
`Developer: Reload Window`, ardından Gradle proje yenilemesi gerekir.
Backend'in Java 17 derleme hedefi değiştirilmedi.

Resmî kaynaklar: [Gradle uyumluluk tablosu](https://docs.gradle.org/current/userguide/compatibility.html),
[VS Code Gradle JDK seçimi](https://github.com/microsoft/vscode-gradle#gradle--java-settings).

## Dağıtım ve veri sınırı

Bu çalışmada Render'a deploy, GitHub push veya canlı Neon seed işlemi yapılmadı.
Yerel 4.037 noktalık dosyanın canlıda aynı sayıda olduğuna yalnız dosyaya bakarak
karar verilemez. Uyumlu istemci Render'ın hâlihazırda döndürdüğü noktaları gösterir;
canlı tam katalog ve yeni endpoint'ler için backend'in ayrıca yayımlanması gerekir.

## Test sonuçları

Test/derleme tamamlandığında aşağıdaki doğrulama listesi güncellenir. Bir önceki
denetimdeki test sayıları bu çalışmanın sonucu gibi kullanılmaz.

- `gradlew.bat --version --offline`: Gradle 8.12, Launcher JVM 21.0.8, Daemon Java 21.
- `gradlew.bat help --offline --console=plain`: BUILD SUCCESSFUL, 56 saniye.
- Tam Flutter paketi: `flutter test --no-pub --concurrency=1 --reporter=expanded`,
  **133 test başarılı**, test koşusu 2 dk 50 sn. Komut SDK'nin Dart başlatıcısı
  üzerinden çalıştırıldı; Flutter test mantığı aynı.
- `dart analyze lib test`: **No issues found**. İlk analizdeki iki süslü-parantez
  stil bildirimi düzeltilip analiz yeniden çalıştırıldı.
- Tarama overlay: 930×830, 320×480, 390×844 ve 1,5 yazı ölçeği regresyonları geçti.
- 200 görev, 320×640, 1,6 yazı ölçeği: son kayda kadar kaydırma/yenileme geçti.
- `scripts/build_android.ps1 -Mode debug -Offline -JavaHome <JBR21>`:
  **başarılı**, Gradle aşaması 393,3 saniye. Gerçek çıktı:
  `frontend/build/app/outputs/flutter-apk/app-debug.apk`, **94.703.236 byte**.
  SHA256: `e7f17b56a937515995800196bd533c4d28745f0b8c86bc9d9bec0c3c6fd3b196`.
  Bu debug APK'dır; telefona kurulum yapılmadı ve release build iddiası yoktur.
- Chrome: `http://127.0.0.1:7357`, yeni kod derlendi ve Flutter debug bağlantısı
  kuruldu (web debug derlemesi 72,8 saniye). Ekran görüntüsünde uygulama görünür.
- **Canlı sınır:** Açılışta korunan oturum kontrolü Render'a erişemedi. Chrome
  içinden public health isteği 8 saniyede, Windows üzerinden uzun deneme de
  zaman aşımına uğradı. Ekran güvenli “Bağlantı kurulamadı / Yeniden Dene”
  durumunda; mevcut oturum silinmedi. Render'ın o anki logları/instance durumu
  bu araçlarla görülemiyor. Cold start, ağ veya servis hatasından hangisi
  olduğuna dair kesin hüküm verilmedi. Canlı giriş/harita/AI akışının bu anda
  başarılı olduğu iddia edilmez.

Sonraki kontrolde public health gerçek uygulama yanıtıyla 200 döndü. Chrome
yenilendiğinde saklanan oturumla ana sayfa görüntülendi. Bu, önceki kesintinin
kök nedenini kanıtlamaz; canlı fotoğraf/AI/harita uçtan uca kabul testi değildir.
Önceki bağlantı hatası ekranı kalıcı son durum olarak yorumlanmamalıdır.

Gradle'ın incubating/deprecation ve `android.overridePathCheck` deneysel ayar
bildirimleri Java 25 derleme hatası değildir. İkincisi Windows Türkçe karakterli
proje yolunu IDE'de açabilmek için korunur; APK script'i native araçlar için
ASCII geçici dizinde derler. “Yeni paket sürümü var” mesajları da tek başına
derleme hatası veya güvenlik açığı tespiti değildir; bağımlılıklar körlemesine
yükseltilmedi.
