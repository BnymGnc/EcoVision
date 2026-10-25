# EcoVision — DOA Türkiye iade noktaları

Bu paket, DOA'nın halka açık haritasının kullandığı veri servisinden alınan anlık görüntüyü ve listeyi yeniden toplamak için Python betiğini içerir. Veriler DOA'ya aittir; EcoVision tarafından yerinde doğrulanmamıştır.

Kaynak sayfa: https://doa.gov.tr/ambalaj-iadesi-nereye-yapilir

## Dosyalar

- `data/doa_points.json`: Bütün toplanan iade noktaları; uygulamaya aktarmak için uygundur.
- `data/doa_points_raw.json`: Nokta kayıtlarının servisten dönen bütün alanları; kaynak kodlarını ve teknik durum alanlarını yorumlamadan korur.
- `data/doa_points.csv`: Excel'de açılabilir bütün noktalar; UTF-8 BOM ve noktalı virgül ayıracı.
- `data/doa_machines_dim.csv`: Yalnız kaynak türü `dim` olan iade makineleri.
- `data/doa_machines_dim.json`: Aynı makine listesinin uygulamaya uygun JSON sürümü.
- `data/doa_points.geojson`: Harita için GeoJSON; koordinat sırası boylam, enlem.
- `data/manifest.json`: Kaynağın bildirdiği toplam, toplanan benzersiz kayıt sayısı, türlere göre sayılar, zaman ve kapsam durumu.
- `collect_doa_points.py`: Python 3.10+; ek paket veya API anahtarı gerektirmez.

`manifest.json` içindeki `count_matched_snapshot`, indirilen benzersiz kayıt sayısının başlangıç sorgusunun bildirdiği toplamla eşleştiğini belirtir. Bu, fiziksel olarak Türkiye'de bulunan bütün makinelerin envanteri veya her makinenin çalışır olduğunun kanıtı değildir. `partial` / `count_mismatch_review_required` durumunda listeyi eksiksiz kabul etmeyin.

Toplama ardışık sorgulardan oluşur; tek bir atomik veritabanı anını temsil etmez. Kaynak veri toplama sırasında değişebilir. Zaman damgası dışa aktarım zamanıdır; makinenin son saha kontrolü zamanı değildir.

## Türler

| Kaynak türü | Kaynak arayüzündeki anlamı |
| --- | --- |
| `dim` | İade Makinesi |
| `kim` | Kamusal İade Merkezi (KİM) |
| `min` | İade Merkezi |
| `sdm` | Toplu İade Merkezi |

Her iade noktası bir makine değildir. Kullanıcıya yalnız makine göstermek istiyorsanız `point_type == "dim"` filtresini kullanın. Toplu iade merkezlerini tüketiciye açık makine gibi sunmayın.

## Yeniden indirme

ZIP'i bir klasöre çıkarın; terminali o klasörde açın:

```powershell
py collect_doa_points.py --output doa-export
```

`py` yoksa `python` kullanabilirsiniz. Betik başarılı kapsam kontrolünde 0, eksik veya hata durumunda 2 çıkış kodu verir. Sonuçlar belirtilen klasöre yazılır.

Servis büyük alanlarda tek tek noktalar yerine kümeler döndürüyor. Betik önce Türkiye ve bölge kümelerini sorgular, sonra 100 km yarıçaplı sorguları sayfalar. Bu ölçekte de küme dönerse ve daha ayrıntılı tarama geçişlerinde 50 km kullanır. `id` ile tekrarları giderir. İstekler sırayla ve aralıklı gönderilir. HTTP 401/403/429 durumunda durur; kimlik doğrulama veya hız sınırı aşılmaz. Geçici önbellek bir saat geçerlidir. Ağ kesintisinden sonra aynı komutu aynı çıktı klasörüyle tekrar çalıştırmak yakın tarihli sorguları ve kayıtları yeniden kullanır.

Kümelerin merkezlerine göre tarama bir kapsama garantisi değildir; betik bu nedenle sonuç sayısını kaynak toplamıyla karşılaştırır. Sayılar farklıysa liste eksiktir veya veri toplama sırasında kaynak değişmiştir. Hata durumunda mevcut tam veri kümenizi bu çıktıyla değiştirmeyin.

## Veri isteği

İnceleme sırasında haritanın kullandığı, kimlik doğrulamasız çalışan istek:

```http
POST https://dbysmgw.doa.gov.tr/dbys/v3/web/rvm/search?pageNumber=1&pageSize=100
Content-Type: application/json
```

Örnek gövde:

```json
{"lat":41.02,"lon":29.04,"distance":8000,"userLat":41.02,"userLon":29.04}
```

`distance` gözlenen kullanımda metredir. Sayfa numarası 1'den başlar. Yanıttaki `rvmList` noktaları, `clusterDataList` kümeleri ve `totalElements` toplamı içerir. Tek bir büyük yarıçaplı yanıtı kaydetmek bütün noktaları vermez.

Bu, sitenin gözlenen web servisidir; belgelenmiş, üçüncü taraf entegrasyonuna garantili bir API sözleşmesi olduğu doğrulanmamıştır. Servis veya şema değişirse betik hata verebilir. Sürekli/üretim kullanımı ve yeniden yayımlama için DOA ile veri kullanım koşullarını ve resmî entegrasyon imkânını teyit edin.

## EcoVision'da kullanım

1. Noktaları backend'e veya uygulamanın harita veri katmanına `id` alanıyla aktarın.
2. Kullanıcı konumuna göre cihazda veya backend'de uzaklık hesaplayın; aynı veri kümesini her harita hareketinde kaynaktan tekrar indirmeyin.
3. İade noktası türünü, kaynağı ve son güncelleme tarihini gösterin. Kaynak durumunu gerçek zamanlı sensör doğrulaması olarak sunmayın; `active` ile açık/kapalı durumunu karıştırmayın.
4. `accepted_materials` kaynak kodlarını korur. Fotoğrafta PET/cam/metal görülmesi tek başına o ambalajın depozitoya uygun olduğunu kanıtlamaz; uygunluk için ürün/işaret/barkod kontrolünü ayrı tutun.
5. `weekly_schedule` varsa haftalık programı kullanın; saat dilimi ve tatil istisnaları teyit edilmeden 'kesin açık' demeyin.
6. Sonraki güncelleme eksik kalırsa önceki tam listeyi koruyun. Aynı `id` için güncelleme yapın; geçici hatada görünmeyen noktaları otomatik silmeyin.

İl/ilçe bilgisi her kayıtta ayrı alan olarak dönmüyor; adres metni korunmuştur. Koordinatlardan il/ilçe üretmek gerekirse idari sınır verisiyle ayrı bir mekânsal eşleştirme yapın; adres metninden tahmin edilen alanları resmî alan gibi sunmayın.
