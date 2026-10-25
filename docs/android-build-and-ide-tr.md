# Android derleme ve IDE duzeltmeleri

Tarih: 24 Ekim 2026. Bu calisma Android arac zincirini ve Flutter analiz
tanilarini hedefler. Backend, API sozlesmeleri, veritabani veya kimlik
dogrulama kurallari degistirilmedi. Onceki arayuz degisiklikleri korundu.

## Java 25 / Gradle 8.12 hatasinin kaynagi

`Unsupported class file major version 69`, Java 25 sinif bicimini ifade eder.
Bu makinede `JAVA_HOME` tanimli degildi; terminal Oracle Java 25'i, VS Code Java
eklentisi ise kendi Java 25.0.4.1 runtime'ini secebiliyordu. Flutter ayri olarak
Android Studio'nun JBR 21.0.8 kurulumunu kullaniyordu. Ayni proje farkli giris
yollarinda farkli JVM ile import ediliyordu.

Gradle'in uyumluluk tablosunda Java 25 ile calisma destegi 9.1.0'dan baslar;
Java 21 icin 8.5 yeterlidir. Cozum tum Flutter/AGP zincirini Gradle 9'a
yukseltmek degil, Android derlemesini desteklenen JDK 21'de tutmaktir.

- `frontend/android/gradle/gradle-daemon-jvm.properties`: daemon JVM 21'e
  sabitlendi; makinaya ozel mutlak yol repository'ye eklenmedi.
- Yerel ve Git disindaki `.vscode/settings.json`: Gradle import JVM'i ve yeni
  Windows terminallerinin `JAVA_HOME` degeri Android Studio JBR 21'e ayarlandi.
  Java dil sunucusunun kendisinin Java 25 kullanmasi tek basina hata degildir;
  Gradle'i calistiran JVM farklidir.
- Sistem genelindeki Java kurulumu, kullanici PATH'i ve Flutter surumu
  degistirilmedi. Eski acik terminaller yeni workspace ortam ayarlarini almaz.
- Flutter 3.35.7 `compileSdk=36` kullaniyor. AGP 8.9.1'in resmen destekledigi
  maksimum API 35 oldugu icin AGP 8.10.1'e guncellendi. Gradle 8.12 ve Kotlin
  2.1.0 korundu. AGP 8.10, API 36 ve Gradle 8.11.1+ ile uyumludur.

Derleme sirasinda Windows'ta 8.001.384 kB kullanilabilir toplam bellekte sadece
3.472 kB bos fiziksel bellek kaldi. Gradle surecinin private commit degeri
yaklasik 2.361 MiB idi; bu deger fiziksel resident bellekle ayni sey degildir.
Eszamanli test kosusu durduruldu, eski uc Gradle daemon'i kapatildi ve isler
siraya alindi. Gradle heap ust siniri 1.536'dan 1.024 MiB'ye, metaspace
512'den 384 MiB'ye ve code cache 256'dan 128 MiB'ye indirildi. Isci sayisi
2'den 1'e alindi; Kotlin ayni surecte derlenerek ek compiler JVM'i acmaz.
Bu, yerel derleme kaynak butcesidir; uygulamanin telefon FPS'i veya Render
status 137 hatasi hakkinda bir kapasite kaniti degildir.

JDK 21 sadece diskte bulunmakla Gradle tarafindan otomatik kesfedilemeyebilir.
Proje JVM kriteri JDK kurmaz. IDE disindaki terminalde `JAVA_HOME` ayarlanmalidir:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
cd frontend\android
.\gradlew.bat --version
.\gradlew.bat help --no-daemon --console=plain
```

VS Code icin `Developer: Reload Window` calistirin ve eski terminal yerine yeni
terminal acin. Eski Java hata kaydi kalirsa `Java: Clean Java Language Server
Workspace` ile yeniden import edin. Android Studio'da Gradle JDK olarak JBR 21
secilmelidir; dil sunucusu runtime'ini zorla JDK 17'ye dusurmeyin.

## Eksik Flutter SDK kaynaklari

`flutter analyze`, uygulamadan bir tani vermeden `No definition of type Future`
ile cokuyordu. SDK'nin `bin/cache/pkg/sky_engine/lib/async` klasoru gercekten
bostu. Dart SDK'nin kendi `lib/async` dosyalari mevcut olsa da Flutter analizoru
`sky_engine` embedder kaynaklarini kullandigi icin derleme ile analiz farkli
sonuc verebiliyordu.

Once yalniz uretilmis analiz onbellegi silinmeden yedeklendi; bu sorunu cozmedi.
Ardindan **ayni** `d3d45dcf251823c1769909cd43698d126db38deb` engine revizyonunun
resmi `sky_engine.zip` paketi indirildi, arsiv yollari dogrulandi ve eksik SDK
kaynaklari geri yuklendi. Paket SHA-256:
`9d7a4252405e16925eb4611ba6b9505bb3ec7c191d23619fcc7a6ea129f3fdc1`.
Flutter 3.35.7 / Dart 3.9.2 surumleri degismedi. SDK dosyalari Git'e eklenmedi.

`analysis_options.yaml` artik `build/**` ve `.dart_tool/**` gibi uretilmis
dosyalari uygulama kaynagi gibi analiz etmez. `lib` veya `test` icin kurallar
kapatilmadi. Onarim icin build altina acilan SDK kopyasinin binlerce tanisi
uygulamanin hatasi olarak sayilmadi. Gercek uygulama analizindeki 91 tani
duzeltildi; son sonuc `android-toolchain-verification.json` icindedir.

## Uygulama kaynaklarinda yapilanlar

- Etkinlik sohbetinin silme menusunde `Theme.of(context)` kullanan hatali
  `const` kaldirildi. Tema rengi ve menu davranisi korundu.
- Avatar, tarama, sohbet ve moderasyon akislarinda await sonrasinda ekran
  kapanmissa diyalog/navigasyon veya dispose edilmis controller kullanilmaz.
- Grup uye sayfasi zaten alinan uye Future'ini kullanir; ilk acilista ayni
  liste yeniden istenmez. On yukleme hatasi gozlemlenir ve uyeler acilinca
  hata durumu gosterilir. Arkadaslik/gorsel gizliligi baglami korunur.
- Referanslanmayan eski `_MembersSheet`, kullanilmayan `_addMember` kalintisi
  ve bas harf yardimcisi kaldirildi. Aktif rol bazli uye yonetimi, profil acma
  ve uye cikarma akisinin yerine baska bir ekran konulmadi.
- Dart'in kendi duzelticisiyle sinirli mekanik duzeltmeler yapildi: suslu
  parantezler, gereksiz import, widget key/super parametreleri ve her zaman
  dogru olan null kosulu. Renkler, yerlesimler ve API endpoint'leri degismedi.

## Tek komutla APK

Windows'taki mevcut Turkce dizinlerde native shader cikti yolu sorunu daha
once dogrulanmisti. Kaynaklari tasimadan tekrar uretilebilir bir derleme betigi
eklendi:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_android.ps1
```

Bagimliliklar bu makinede onceden indirilmisken agda SSL beklemesi varsa:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_android.ps1 -Offline
```

Bu secenek Pub ve Gradle icin onbellek kullanir. Ilk kurulumda eksik paketleri
indiremez ve eksik bagimlilik hatasi verir; normal IDE/CI akisinin agini
kapatmaz. Gradle `isOffline` secenegi yalniz betigin gecici ortam degiskeni
ile etkinlesir. Uygulamanin calisma zamanindaki API/AI baglantilari etkilenmez.

Betik ayrica yalniz kendi gecici ortaminda `assembleDebug` istegini
`:app:assembleDebug` olarak niteler. Diger turlu Flutter'in nitelendirilmemis
gorevi plugin AAR paketleme gorevlerini de tetikliyordu. Bekleyen gorev
`:file_picker:extractDebugAnnotations` idi; lint/uast/compiler artefaktlari
isteniyordu. Uygulamanin gerekli plugin derlemeleri ve native kutuphaneleri
`:app` bagimlilik grafiginde kalir. Acikca calistirilan lint gorevleri
kapatilmadi; normal IDE/CI gorev secimi de degismedi.

Bu tur uzun bekleyen bir Gradle thread'i SSL/HTTP artefakt indirmesinde
gozlendi. Ayni kaynak kopyasindaki `:app:assembleDebug --offline --no-daemon`
53 sn'de, 274 gorevle basarili oldu. Ilk iki uzun derleme denemesi kaynak
baskisi ve ag beklemesini incelemek icin kontrollu durduruldu; bunlar basarili
derleme gibi raporlanmadi. Hicbir konteyner calismadigi dogrulandiktan sonra
bos yerel Docker Desktop kapatildi; volume veya veritabanlari silinmedi.

Betik JDK 21'i secer, lockfile'i zorlar, anahtarsiz bir ASCII gecici kaynak
kopyasinda ARM64 debug APK derler ve son APK'yi
`frontend/build/app/outputs/flutter-apk/app-debug.apk` konumuna alir. `.env`,
gercek `constants.dart`, imzalama anahtarlari ve build/onbellekler kopyalanmaz.
Gecici kaynakta `constants.example.dart` kullanilir. Bu betik kaynaklari veya
mevcut SDK'yi tasimaz, APK'yi telefona otomatik kurmaz ve canli API'yi test etmez.
Inceleme icin gecici derleme dizini korunur; baslangicta yolu yazdirilir.

## Kalan uyarilarin anlami

Son dogrulama: `flutter analyze --no-pub` sifir taniyla tamamlandi. Tam
Flutter test paketi tek isciyle 49 sn'de **119 test** gecti. Nihai betik
`-Offline` ile calistirildi; Gradle 149,6 sn'de APK uretti. Cikti
97.284.372 byte ve SHA-256
`6be486485841e5872749771a4b77ba8c836367a68f718d04b9a64c0f80d7a99b`.
APK'da `lib/arm64-v8a/libflutter.so` ve 20. avatar asset'i kontrol edildi.
Bu bir fiziksel cihaz veya canli API testi degildir.

- Bazi ucuncu taraf Android plugin'leri Java 8 bytecode hedefi kullandigindan
  JDK 21 `source/target value 8 is obsolete` uyarisi uretebilir. Pub cache
  kaynaklari elle yamalanmadi ve `-Xlint:-options` ile uyari gizlenmedi.
- Plugin Groovy betiklerindeki space-assignment deprecation uyarilari Gradle
  10'a gecisle ilgilidir; mevcut Gradle 8.12 derlemesini durdurmaz. Kapsamli
  paket major yukseltmesi ozellikle secure storage gibi veri tasima riski
  tasiyan bagimliliklarda ayri uyumluluk testi ister.
- `pub get` ciktilarindaki daha yeni paket bilgisi derleme hatasi degildir.
  Bu calismada rastgele toplu dependency upgrade yapilmadi.
- `android.overridePathCheck=true` Turkce workspace yolunda IDE import'u icin
  korunur; experimental uyarisi beklenebilir. APK betigi ASCII cikti kullanir.
- `flutter doctor`'in PATH ciktisindaki Turkce SDK yolunu yanlis cozumleme
  hatasi ayri bir yerel arac siniridir; SDK'yi kalici ASCII bir konuma tasima
  bu calismada yapilmadi. APK ve analyze sonucu doctor'a bakilarak varsayilmadi.
- Bazi Android SDK lisanslari kabul edilmemis. Kullanici
  `flutter doctor --android-licenses` ile kosullari okuyup kabul etmelidir;
  kullanici yerine otomatik onay verilmedi.
- Visual Studio/C++ eksikligi Windows desktop hedefini ilgilendirir;
  Android APK icin gerekli degildir. Debug imzasi magaza yayini imzasi degildir.

Kaynaklar: [Gradle Java uyumlulugu](https://docs.gradle.org/current/userguide/compatibility.html),
[Gradle daemon JVM kriterleri](https://docs.gradle.org/current/userguide/gradle_daemon.html#sec:daemon_jvm_criteria),
[AGP 8.10 uyumlulugu](https://developer.android.com/build/releases/agp-8-10-0-release-notes).
