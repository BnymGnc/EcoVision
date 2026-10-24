# Climathon final demosu

Son teslim: 25 Ekim 2026 Pazar 23.59 (Türkiye). Bu metin senaryodur; video kaydı,
YouTube yüklemesi, PDF üretimi veya form gönderimi yapılmış değildir.

## 120 saniyelik gerçek akış

| Süre | Ekran / eylem | Savunulabilir anlatım |
|---|---|---|
| 0–15 | Gerçek bir içecek ambalajı | “Atığın malzemesini ve doğru teslim yerini tek akışta bulmak istiyorum.” Kendi gözlemini kullan; araştırma uydurma. |
| 15–40 | Fotoğraf çek/seç, gerçek analiz | Provider/modeli ve belirsizliği göster. Cache varsa söyle. Genel plastik PET doğrulaması değildir. |
| 40–60 | İlgili kaynaklı rehber | Hazırlık ve güvenlik kuralını, kaynak bağlantısını göster. |
| 60–90 | Geri dön → DOA düğmesi → nokta → yol tarifi | Destek ve kaynak durumu ayrı; veri snapshot. Gerçek koordinata harici harita açılır. Depozito ödeme EcoVision'da yapılmaz. |
| 90–105 | Akademi veya bir görev | Eko Puan uygulama motivasyonudur; kg/CO₂ veya fiziksel iade belgesi değildir. |
| 105–120 | Sonuç ve pilot hedefi | “Doğru ayırma ve uygun noktayı bulma süresini kampüs pilotunda ölçeceğim.” Henüz yapılmadıysa sonuç deme. |

Ambalaj soru formunu veya kaldırılmış eylem-kaydı butonunu geri getirmeyin.
Jüri için ayrı normal hesap kullanın; admin anahtarı veya .env ekranda görünmesin.

## Gerçekte kullanılan teknoloji

Flutter/Dart/Material 3, Spring Boot 3/Java 17 modüler monolit, PostgreSQL/Neon,
JWT + BCrypt, REST multipart, STOMP grup sohbeti; DOA snapshot ve OpenStreetMap;
Gemini veya sunucuda ONNX MobileNetV2/TrashNet. Deterministik kurallar ve karbon
aritmetiği AI diye sunulmaz. AI Studio Build ile geliştirilmiş olduğu iddia edilmez.

Modelin 395 görsellik ayrılmış testinde accuracy 0.8253, macro-F1 0.7881;
bunlar saha metrikleri değildir. 0.9140 yalnız eşik sonrası tutulan alt kümenin
doğruluğudur. Eğitim kaynağı, DOA veri kaynağı ve karbon katsayıları farklıdır.

## İddia tutarlılık tablosu

| Form | Ortak hikaye | Kanıt / eksik |
|---|---|---|
| Task 1 | Ayrıştırma ve teslim kararı problemi; kampüs kullanıcı hipotezi | Kendi gözlemin, motivasyonun ve baseline gerekiyor |
| Task 2 | Fotoğraftan kaynaklı rehber ve uygun noktaya yönlendirme | PDR ve gerçek kod; talep/gelir henüz doğrulanmadı |
| Task 3 | Gerçek görüntü sınıflandırma ve nokta keşfi | Model kartı, test/gerçek demo; canlı link ayrıca doğrulanmalı |
| Task 4 | Aynı çekirdeğin testli ve güvenlik açısından güçlendirilmiş hali | Yeni test raporu + gerçek 2 dk video + son PDF'ler |

Program hizası: Cutting waste by half by 2035. Siemens: Resource Efficiency &
Circularity. Birincil SDG 12.5, ikincil SDG 13. Programın hedefini ürünün
ölçülmüş başarısı gibi yazmayın.

## Etki ve iş modeli

Önerilen pilot: 20 gönüllü, 2 hafta; 10 örnekte doğru ayırma ve nokta bulma süresi
önce/sonra. Hipotez: +15 yüzde puan doğru karar, medyan sürede %30 azalma.
Bunlar gerçekleşmiş sonuç değildir. İadeler yalnız beyan ise öyle etiketlenir.
Kurumsal kampanya/katılım analitiği lisansı bir iş modeli hipotezidir; ödeme isteği
veya müşteri sözleşmesi kanıtı yoktur.

## Teslim kontrolü

- Ürün linki başka bir cihazda denenmiş mi?
- Gerçek AI anahtarı/motoru ve ilgili model erişimi çalışıyor mu?
- Yeni backend ve APK/web aynı güvenlik sözleşmesini kullanıyor mu?
- Puan, tahmin, beyan ve fiziksel iade ayrı ifade edilmiş mi?
- Kişisel motivasyon ve baseline gerçek mi?
- Video gerçekten çalışır akış mı; YouTube listedışı link hazır mı?
- PDR/Problem Definition tek ve tutarlı hikaye anlatıyor mu?

Güncel test ve açık riskler: final-security-and-tests-tr.md,
deployment-readiness-tr.md ve verification.md.
