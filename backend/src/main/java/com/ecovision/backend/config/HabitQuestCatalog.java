package com.ecovision.backend.config;

import com.ecovision.backend.model.QuestCategory;
import com.ecovision.backend.model.QuestTriggerType;
import java.util.*;

/** Reviewed, versioned actions; each is a distinct activity, never an LLM-generated runtime quest. */
final class HabitQuestCatalog {
    static final String VERSION = "habits-2026-10-24-v1";
    private HabitQuestCatalog() {}

    static List<QuestDataLoader.QuestSeed> entries() {
        List<QuestDataLoader.QuestSeed> result = new ArrayList<>();
        add(result, "prevent", "Atık oluşumunu önleme", 10, new String[][] {
            {"Alışverişten önce kontrol", "Evdeki stoklara bakarak yalnız eksik ürünlerin listesini hazırla."},
            {"Ambalajsız bir tercih", "İhtiyacın olan bir üründe gereksiz dış ambalajı olmayan seçeneği tercih et."},
            {"Bez çantan yanında", "Bir alışverişinde mevcut bez çantanı kullan; yeni çanta satın almak gerekmez."},
            {"Su matarası hazırlığı", "Güvenli içme suyu erişimin varsa mevcut mataranı doldurup yanına al."},
            {"Termosla bir mola", "Bir içecek molasında işletme izin veriyorsa mevcut termosunu kullan."},
            {"Gereksiz promosyonu reddet", "İhtiyacın olmayan tek kullanımlık bir promosyon ürününü nazikçe reddet."},
            {"Dijital fiş seçimi", "Seçenek sunulan bir alışverişte dijital fişi seç."},
            {"Kargo paketini birleştir", "Gerçek bir ihtiyacın varsa aynı siparişte gereksiz bölünmüş teslimattan kaçın."},
            {"Deneme boyuna ara", "Kullandığın ürünün ihtiyaç miktarına uygun ambalajını değerlendir."},
            {"Peçeteyi gerektiği kadar al", "Bir öğünde kullanacağın kadar peçete al."},
            {"Paket servis malzemeleri", "Bir siparişte kullanmayacağın plastik çatal, pipet ve poşeti istemediğini belirt."},
            {"Satın almadan bir gün düşün", "Zorunlu olmayan bir alışverişi bir gün erteleyip ihtiyacını yeniden değerlendir."},
            {"Dolum seçeneğini araştır", "Kullandığın bir ürün için güvenli ve gerçek bir yeniden dolum seçeneği araştır."}
        });
        add(result, "reuse", "Yeniden kullanım", 15, new String[][] {
            {"Kavanoza yeni görev", "Sağlam ve temiz bir gıda kavanozunu kuru ürün saklamak için yeniden kullan."},
            {"Hediye paketini koru", "Bir hediye paketini bozmadan açıp yeniden kullanmak üzere sakla."},
            {"Kargo kutusunu değerlendir", "Sağlam bir kutuyu evde düzenleyici olarak kullan."},
            {"İkinci el kitap", "İhtiyacın olan bir kitabı satın almadan önce ikinci el seçeneğini kontrol et."},
            {"Kütüphane ziyareti", "Bir kitabı kütüphaneden ödünç al veya uygunluk koşullarını öğren."},
            {"Yemek kabını yanında taşı", "Bir öğünü mevcut, gıdaya uygun saklama kabınla götür."},
            {"Tamir bezi ayır", "Kullanılamayacak temiz bir kumaşı güvenli temizlik bezi olarak değerlendir."},
            {"Çift taraflı not", "Kişisel veri içermeyen bir kağıdın boş yüzünü not için kullan."},
            {"Oyuncak değişimi", "İzinle ve temiz durumda bir oyuncağı takas et veya paylaş."},
            {"Şarj edilebilir seçenek", "Bir cihazında üreticinin desteklediği tekrar şarj edilebilir seçeneği araştır."},
            {"Zarfı yeniden kullan", "Kişisel bilgileri kapatılmış sağlam bir zarfı yeniden değerlendir."},
            {"Bez servis hazırlığı", "Evdeki bir öğünde mevcut yıkanabilir servis bezini kullan."},
            {"Mevcut saksıyı değerlendir", "Yeni saksı almadan önce elindeki sağlam saksılardan birini kullan."}
        });
        add(result, "repair", "Onarım ve ürün ömrü", 20, new String[][] {
            {"Düğmeye ikinci şans", "Biliyorsan güvenli biçimde gevşek düğmeni dik veya yardım iste."},
            {"Giysi bakım etiketi", "Bir giysinin bakım etiketini okuyup uygun yıkama ayarını belirle."},
            {"Ayakkabı bakımı", "Mevcut ayakkabını malzemesine uygun yöntemle temizle."},
            {"Fermuarı kontrol et", "Bir fermuar sorunu için terziden onarım bilgisi al."},
            {"Bisiklet bakım kontrolü", "Bisikletinin bakım ihtiyacını kontrol et; güvenlik onarımını uzmana bırak."},
            {"Cihaz havalandırması", "Kapalı ve fişi çekilmiş cihazının dış havalandırmasını üretici talimatına göre temizle."},
            {"Garanti belgesini bul", "Bir cihazının garanti ve servis bilgilerini düzenle."},
            {"Tamirci araştırması", "Bozuk bir eşya için yetkili veya uygun yerel onarım hizmeti araştır."},
            {"Yazılım güncellemesi", "Desteklenen bir cihazını resmî kaynaktan güncelle."},
            {"Şarj kablosu kontrolü", "Hasarlı kablolarını kullanımdan ayır ve güvenli değiştirme yolunu araştır."},
            {"Mobilyayı koru", "Bir mobilyanın gevşeyen parçası için güvenli bakım planı yap."},
            {"Onarım maliyetini karşılaştır", "Bozuk bir ürün için yenisini almadan önce onarım fiyatı öğren."},
            {"Pil güvenliğini öğren", "Şişen veya hasarlı pili sökmeden, üreticinin güvenli servis talimatını oku."}
        });
        add(result, "food", "Gıda ve organik atık", 15, new String[][] {
            {"Buzdolabı envanteri", "Buzdolabındaki ürünleri son kullanma bilgileriyle kontrol et."},
            {"Önce açılanı tüket", "Güvenli tüketim süresi içindeki açılmış bir ürünü öğün planına ekle."},
            {"Bir haftalık öğün planı", "Evdeki gıdaları kullanacak gerçekçi bir haftalık menü hazırla."},
            {"Porsiyonu ayarla", "Bir öğünde yiyebileceğin kadar servis al."},
            {"Güvenli kalan yemeği sakla", "Güvenli süre ve sıcaklık kurallarına uyarak kalan yemeği sakla."},
            {"Dondurucu etiketi", "Dondurduğun uygun bir gıdaya içerik ve tarih etiketi koy."},
            {"Ekmek israfını önle", "Güvenli durumdaki fazla ekmeği bozulmadan değerlendirecek bir plan yap."},
            {"Mevsim ürünü araştır", "Bulunduğun bölgede mevsiminde yetişen bir sebze veya meyveyi öğren."},
            {"Tarih etiketini öğren", "TETT ile son tüketim tarihi arasındaki farkı güvenilir bir gıda kaynağından öğren."},
            {"Organik atığı tart", "Güvenli biçimde bir günlük mutfak atığını tartıp miktarını not et."},
            {"Kompost imkanını kontrol et", "Belediyende veya kampüsünde gerçek bir organik atık programı olup olmadığını araştır."},
            {"Kompost sınırlarını öğren", "Erişebildiğin program varsa kabul ettiği gıda türlerini öğren; yoksa görev için atık biriktirme."},
            {"Gıda paylaşımında güvenlik", "Fazla gıdayı paylaşmadan önce saklama ve alerjen bilgisini kontrol et."}
        });
        add(result, "deposit", "İçecek ambalajları ve DOA", 15, new String[][] {
            {"DOA işaretini tanı", "Mevcut bir içecek ambalajında DOA işaretinin olup olmadığını kontrol et."},
            {"Hacim sınırını öğren", "DOA rehberindeki 0,10–3,01 litre kapsamını oku."},
            {"Şişeyi boşalt", "Mevcut uygun içecek şişesini boşaltıp bütünlüğünü koru."},
            {"İade rotasını planla", "Yeni ambalaj almadan, mevcut uygun ambalajın için gerçek bir DIM noktası bul."},
            {"Malzeme farkını öğren", "Genel plastik ile PET içecek şişesinin aynı şey olmadığını rehberden öğren."},
            {"Kavanozun yolunu ayır", "Cam kavanozun yalnız cam olduğu için DOA kapsamına girmediğini kontrol et."},
            {"Süt ambalajı kontrolü", "Süt ve içilebilir süt ürünleri için DOA kapsamını resmî rehberden kontrol et."},
            {"Hazne bilgisini kontrol et", "Bir iade noktasında ilgili malzemenin destek bilgisini kontrol et."},
            {"Kaynak tarihine bak", "Bir noktanın veri tarihini kontrol edip canlı durum garantisi olmadığını öğren."},
            {"İade ve taramayı ayır", "Fotoğraf taramasının resmî ambalaj iadesi olmadığını öğren."},
            {"İadeni beyan et", "Gerçek bir uygun ambalaj iadesi yaptıysan kendi beyanın olarak not et; yapmadıysan tamamlamadan bırak."},
            {"Güvenli ambalaj taşıma", "Zaten birikmiş sağlam ambalajları güvenli taşıma kabına yerleştir; kırık cama dokunma."}
        });
        add(result, "sorting", "Doğru ayrıştırma", 15, new String[][] {
            {"Yerel ayrıştırma kuralı", "Belediyenin ambalaj ayrıştırma kurallarını resmî sayfasından oku."},
            {"Atık pil teslim yolu", "Kullanılmış pili açmadan resmî toplama yolunu araştır."},
            {"E-atık için yetkili nokta", "Bozuk elektronik için belediye veya üreticinin yetkili teslim yolunu bul."},
            {"Atık yağ güvenliği", "Soğumuş bitkisel atık yağı uygun kapta tutma ve teslim kurallarını öğren."},
            {"İlaç atığı araştırması", "Kullanılmayan ilaç için yerel yetkili teslim bilgisini öğren."},
            {"Yağlı karton ayrımı", "Yağlı veya kirlenmiş kartonun yerel kabul koşullarını öğren."},
            {"Kırık cam güvenliği", "Kırık camı eline almadan belediyenin güvenli teslim talimatını öğren."},
            {"Tekstil toplama seçeneği", "Gerçek bir tekstil toplama veya yeniden kullanım noktası araştır."},
            {"Kompozit ambalaj kuralı", "İçecek kartonlarının belediyendeki kabul koşullarını kontrol et."},
            {"Ambalajı kirletme", "Bir geri dönüşüm kabına yemek kalıntısı koymaktan kaçın."},
            {"Tehlikeli atığı ayır", "Boya ve kimyasal ambalajlarını normal kutuya atmayıp yetkili teslim talimatını öğren."},
            {"Kutu etiketlerini oku", "Kampüsündeki toplama kutularının malzeme etiketlerini kontrol et."}
        });
        add(result, "sharing", "Paylaşım ve topluluk", 20, new String[][] {
            {"Komşuyla alet paylaş", "İzin alarak ihtiyaç duyduğun bir aleti satın almak yerine ödünç kullan."},
            {"Kitap takası duyurusu", "Güvenli ve izinli bir alanda kitap takası önerisi paylaş."},
            {"Kullanılabilir giysi bağışı", "Temiz ve sağlam giysiyi gerçekten kabul eden bir kuruma teslim yolunu öğren."},
            {"Arkadaşına doğru rehber", "Bir arkadaşınla resmî ayrıştırma rehberini paylaş."},
            {"Etkinlik erişimini kontrol et", "Bir temizlik etkinliğinin erişim ve güvenlik koşullarını organizatörden öğren."},
            {"Etkinlikte gönüllü rol", "Gerçek bir çevre etkinliğine katıldıysan güvenli görevini yerine getirdiğini beyan et."},
            {"Grubun güvenlik planı", "Bir grup etkinliği için izin, eldiven ve riskli atık kurallarını konuş."},
            {"Yurt paylaşım köşesi", "Yurt yönetiminden izin alarak eşya paylaşım fikrini öner."},
            {"Tamir bilgisini paylaş", "Kullandığın güvenilir bir onarım kaynağını topluluğunla paylaş."},
            {"İade noktasını tarif et", "Arkadaşına gerçek ve ilgili bir iade noktasının yol tarifini gönder."},
            {"Gıda paylaşım kuralı", "Toplulukta gıda paylaşırken alerjen ve saklama bilgisinin önemini konuş."},
            {"Etkinlik geri bildirimi", "Katıldığın bir etkinlik için yapıcı erişilebilirlik veya güvenlik geri bildirimi ver."}
        });
        add(result, "learning", "Ölçüm ve alışkanlık", 10, new String[][] {
            {"Başlangıç atık günlüğü", "Bir gün ürettiğin atık türlerini miktar uydurmadan not et."},
            {"En büyük kaynağı bul", "Kendi atık günlüğünde en sık oluşan atık kaynağını belirle."},
            {"Bir azaltım hedefi", "Günlüğüne göre küçük ve ölçülebilir bir haftalık hedef yaz."},
            {"Hedefini gözden geçir", "Daha önce koyduğun hedefin gerçekleşen ve gerçekleşmeyen adımlarını not et."},
            {"Fatura birimini öğren", "Elektrik faturanda kWh tüketim alanını bul."},
            {"Su sayacını oku", "Yetkin varsa su sayacındaki hacim birimini öğren; ortak tesisata müdahale etme."},
            {"Karbon hesabı sınırları", "Tahmini karbon hesabının kapsam ve veri sınırlarını oku."},
            {"Tarama hatasını fark et", "Bir malzeme tahmini belirsizse kesin kabul etmek yerine yeniden fotoğraf çek."},
            {"Gizlilik kontrolü", "Paylaştığın fotoğraflarda yüz ve kişisel bilgilerin görünmediğini kontrol et."},
            {"Ulaşım seçeneği karşılaştır", "Günlük bir rotada yürüyüş veya toplu taşımanın güvenli ve erişilebilir olup olmadığını incele."},
            {"Enerji kaçaklarını gözle", "Kullanılmayan bir odadaki gereksiz aydınlatmayı kapat."},
            {"Su israfını bildir", "Gerçek bir musluk sızıntısı fark ettiysen sorumlu kişiye bildir; yoksa arızayı uydurma."}
        });
        return List.copyOf(result);
    }

    private static void add(List<QuestDataLoader.QuestSeed> target, String area, String label,
                            int points, String[][] actions) {
        for (int i = 0; i < actions.length; i++) {
            Map<String, Object> criteria = Map.of(
                    "selfReport", true, "action", "habit_checkin", "oncePerDay", true,
                    "catalogVersion", VERSION, "area", label, "verification", "USER_DECLARED",
                    "difficulty", "EASY", "estimatedMinutes", 10, "requiredResources", "Yönergede belirtilen imkan",
                    "unit", "eylem");
            target.add(new QuestDataLoader.QuestSeed("habit_" + area + "_" + String.format(Locale.ROOT, "%02d", i + 1),
                    actions[i][0], actions[i][1], points, 1, QuestCategory.MILESTONE,
                    QuestTriggerType.TIME_BASED, criteria));
        }
    }
}
