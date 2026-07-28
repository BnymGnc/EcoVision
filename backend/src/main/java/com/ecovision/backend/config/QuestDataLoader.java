package com.ecovision.backend.config;

import com.ecovision.backend.model.Quest;
import com.ecovision.backend.model.QuestCategory;
import com.ecovision.backend.model.QuestDomain;
import com.ecovision.backend.model.QuestTriggerType;
import com.ecovision.backend.repository.QuestRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.HashSet;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@Order(20)
public class QuestDataLoader implements CommandLineRunner {
    private final QuestRepository questRepository;
    private final ObjectMapper objectMapper;

    public QuestDataLoader(
            QuestRepository questRepository,
            ObjectMapper objectMapper
    ) {
        this.questRepository = questRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    @Transactional
    public void run(String... args) {
        List<QuestSeed> seeds = catalog();
        validateCatalog(seeds);
        Set<String> catalogCodes = new HashSet<>();
        Map<String, Quest> existingByCode = new HashMap<>();
        for (Quest existing : questRepository.findAll()) {
            existingByCode.put(existing.getCode(), existing);
        }
        List<Quest> updates = new ArrayList<>(seeds.size());

        for (QuestSeed seed : seeds) {
            catalogCodes.add(seed.code());
            Quest quest = existingByCode.getOrDefault(seed.code(), new Quest());
            quest.setCode(seed.code());
            quest.setTitle(seed.title());
            quest.setDescription(seed.description());
            quest.setRewardPoints(seed.rewardPoints());
            quest.setTargetAmount(seed.targetAmount());
            quest.setQuestCategory(seed.category());
            quest.setTriggerType(seed.triggerType());
            quest.setDomain(domainFor(seed));
            quest.setCriteriaJson(toJson(seed.criteria()));
            quest.setActive(true);
            updates.add(quest);
        }

        for (Quest existing : existingByCode.values()) {
            if (existing.isActive() && !catalogCodes.contains(existing.getCode())) {
                existing.setActive(false);
                updates.add(existing);
            }
        }
        questRepository.saveAll(updates);
    }

    private void validateCatalog(List<QuestSeed> seeds) {
        if (seeds.size() != 100) {
            throw new IllegalStateException(
                    "Görev kataloğu tam olarak 100 görev içermelidir: "
                            + seeds.size()
            );
        }
        Set<String> codes = new HashSet<>();
        Set<String> titles = new HashSet<>();
        for (QuestSeed seed : seeds) {
            if (!codes.add(seed.code()) || !titles.add(seed.title())) {
                throw new IllegalStateException(
                        "Görev kodu ve başlığı benzersiz olmalıdır: " + seed.code()
                );
            }
            if (seed.rewardPoints() <= 0 || seed.targetAmount() <= 0) {
                throw new IllegalStateException(
                        "Görev hedefi ve ödülü pozitif olmalıdır: " + seed.code()
                );
            }
        }
    }

    static List<QuestSeed> catalog() {
        return List.of(
                // 1-10: Günlük görevler
                q("daily_morning_coffee", "Sabah Kahvesi",
                        "Saat 06.00-10.00 arasında bir atık tara.",
                        15, 1, QuestCategory.DAILY, QuestTriggerType.TIME_BASED,
                        Map.of("action", "scan", "startHour", 6, "endHour", 10)),
                q("daily_lunch_cleanup", "Öğle Arası Temizliği",
                        "Öğle arasında üç atığı doğaya kazandır.",
                        25, 3, QuestCategory.DAILY, QuestTriggerType.TIME_BASED,
                        Map.of("action", "scan", "startHour", 12, "endHour", 14)),
                q("daily_harvest", "Günün Hasadı",
                        "Bugün beş farklı atık taraması yap.",
                        35, 5, QuestCategory.DAILY,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan")),
                q("daily_quick_streak", "Hızlı Seri",
                        "Kısa bir tarama oturumunda arka arkaya üç atık tara.",
                        30, 3, QuestCategory.DAILY, QuestTriggerType.TIME_BASED,
                        Map.of("action", "quick_scan")),
                q("daily_night_watch", "Gece Nöbeti",
                        "Gece 22.00-02.00 arasında iki atık tara.",
                        35, 2, QuestCategory.DAILY, QuestTriggerType.TIME_BASED,
                        Map.of("action", "scan", "startHour", 22, "endHour", 2)),
                q("daily_plastic_enemy", "Plastik Düşmanı",
                        "Üç plastik atığı tespit edip doğru kutuya yönlendir.",
                        30, 3, QuestCategory.DAILY,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("plastic"))),
                q("daily_glass_friend", "Cam Dostu",
                        "İki cam atığı geri dönüşüm döngüsüne kat.",
                        30, 2, QuestCategory.DAILY,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("glass"))),
                q("daily_paper_guardian", "Kağıt Koruyucusu",
                        "Üç kağıt veya karton atık tara.",
                        25, 3, QuestCategory.DAILY,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan",
                                "wasteTypes", List.of("paper", "cardboard"))),
                q("daily_clean_start", "Temiz Başlangıç",
                        "Pazartesi gününün ilk taramasını tamamla.",
                        20, 1, QuestCategory.DAILY, QuestTriggerType.TIME_BASED,
                        Map.of("action", "first_scan",
                                "daysOfWeek", List.of("MONDAY"))),
                q("daily_weekend_warrior", "Hafta Sonu Savaşçısı",
                        "Hafta sonunda on atık tara.",
                        60, 10, QuestCategory.DAILY, QuestTriggerType.TIME_BASED,
                        Map.of("action", "scan",
                                "daysOfWeek", List.of("SATURDAY", "SUNDAY"))),

                // 11-18: Seri görevleri
                q("streak_3", "3 Günlük Kıvılcım",
                        "Üç günlük tarama serisine ulaş.",
                        40, 3, QuestCategory.MILESTONE,
                        QuestTriggerType.STREAK_DAYS,
                        Map.of("metric", "streak_days")),
                q("streak_7", "7 Günlük Ateş",
                        "Yedi günlük kesintisiz tarama serisine ulaş.",
                        100, 7, QuestCategory.MILESTONE,
                        QuestTriggerType.STREAK_DAYS,
                        Map.of("metric", "streak_days")),
                q("streak_30", "30 Günlük Efsane",
                        "Otuz günlük kesintisiz tarama serisine ulaş.",
                        350, 30, QuestCategory.MILESTONE,
                        QuestTriggerType.STREAK_DAYS,
                        Map.of("metric", "streak_days")),
                q("streak_100", "100 Günlük Usta",
                        "Yüz günlük kesintisiz tarama serisine ulaş.",
                        1200, 100, QuestCategory.MILESTONE,
                        QuestTriggerType.STREAK_DAYS,
                        Map.of("metric", "streak_days")),
                q("streak_perfect_week", "Kusursuz Hafta",
                        "Bir haftanın her gününde en az bir tarama yap.",
                        120, 7, QuestCategory.WEEKLY,
                        QuestTriggerType.STREAK_DAYS,
                        Map.of("metric", "streak_days")),
                q("streak_weekend_combos", "Hafta Sonu Komboları",
                        "Arka arkaya dört hafta sonu serisini tamamla.",
                        180, 4, QuestCategory.MILESTONE,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "weekend_combo")),
                q("streak_no_holiday", "Tatil Tanımaz",
                        "Yedi resmi tatil gününde tarama yap.",
                        220, 7, QuestCategory.HIDDEN,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "holiday_scan_days")),
                q("streak_revival", "Diriliş",
                        "Bir Seri Dondurucu kullanarak serini koru.",
                        60, 1, QuestCategory.HIDDEN,
                        QuestTriggerType.BUY_MARKET_ITEM,
                        Map.of("action", "streak_freeze_used",
                                "itemIds", List.of("streak_freeze"))),

                // 19-23: Seviye kilometre taşları
                q("level_5_unlock", "Seviye 5 Kilidi",
                        "Üç cam ve iki plastik atık tara.",
                        150, 5, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan",
                                "requirements", Map.of("glass", 3, "plastic", 2))),
                q("level_10_unlock", "Seviye 10 Kilidi",
                        "Kendi ilçenden farklı bir ilçede tarama yap.",
                        220, 1, QuestCategory.MILESTONE,
                        QuestTriggerType.LOCATION_BASED,
                        Map.of("action", "scan_different_district")),
                q("level_15_unlock", "Seviye 15 Kilidi",
                        "Nadir bir elektronik atık tara.",
                        300, 1, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "rare_scan",
                                "wasteTypes", List.of("electronics"))),
                q("level_20_unlock", "Seviye 20 Kilidi",
                        "Grubunla birlikte yüz taramaya ulaş.",
                        500, 100, QuestCategory.MILESTONE,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "group_scans")),
                q("mastery_exam", "Ustalık Sınavı",
                        "Arka arkaya on yüksek güvenli yapay zeka taraması yap.",
                        250, 10, QuestCategory.MILESTONE,
                        QuestTriggerType.AI_CONFIDENCE_HIGH,
                        Map.of("action", "scan", "minimumConfidence", 0.90)),

                // 24-33: Sosyal görevler
                q("social_first_hello", "İlk Merhaba",
                        "Bir topluluk grubunda ilk mesajını gönder.",
                        25, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "first_group_message")),
                q("social_popular_choice", "Popüler Seçim",
                        "Profilinde on beğeniye ulaş.",
                        80, 10, QuestCategory.SOCIAL,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "profile_likes")),
                q("social_influencer", "Fenomen",
                        "Profilinde elli beğeniye ulaş.",
                        250, 50, QuestCategory.SOCIAL,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "profile_likes")),
                q("social_group_founder", "Grup Kurucusu",
                        "İlk temizlik grubunu oluştur.",
                        75, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "group_created")),
                q("social_socialize", "Sosyalleşme",
                        "Bir grupta beş mesaj gönder.",
                        50, 5, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "group_message")),
                q("social_helper", "Yardımsever",
                        "Bir topluluk üyesini başarısından dolayı tebrik et.",
                        35, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "congratulate_member")),
                q("social_team_player", "Takım Oyuncusu",
                        "Bir grup görevine katkı sağla.",
                        60, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "group_mission_contribution")),
                q("social_competitive_spirit", "Rekabetçi Ruh",
                        "Şehir sıralamasında ilk yüz içinde kal.",
                        90, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "city_top_100")),
                q("social_champion", "Şampiyon",
                        "Şehir liderlik tablosunda birinci ol.",
                        500, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "city_rank_first")),
                q("social_ambassador", "Elçi",
                        "Bir arkadaşını EcoVision topluluğuna davet et.",
                        70, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "friend_invited")),

                // 34-41: Keşif ve uzmanlık
                q("explore_traveling_cleaner", "Gezgin Temizleyici",
                        "Üç farklı mahallede atık tara.",
                        120, 3, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.LOCATION_BASED,
                        Map.of("action", "scan", "mode", "UNIQUE",
                                "uniqueAttribute", "neighborhood")),
                q("explore_metal_hunter", "Metal Avcısı",
                        "Beş metal atık tara.",
                        80, 5, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("metal"))),
                q("explore_ewaste_expert", "E-Atık Uzmanı",
                        "On elektronik atığı güvenli geri dönüşüme yönlendir.",
                        180, 10, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan",
                                "wasteTypes", List.of("electronics"))),
                q("explore_organic_converter", "Organik Dönüşümcü",
                        "On organik atık tara.",
                        100, 10, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("organic"))),
                q("explore_big_cleanup", "Büyük Temizlik",
                        "Tek bir günde elli atık taramasına ulaş.",
                        300, 50, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "daily_scan_count")),
                q("explore_bug_hunter", "Hata Avcısı",
                        "Yanlış sınıflandırma bildirimini kullan.",
                        50, 1, QuestCategory.HIDDEN,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "wrong_classification_reported")),
                q("explore_knowledge_search", "Bilgi Arayışı",
                        "Atık ansiklopedisinde bir eğitim içeriği oku.",
                        25, 1, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "education_articles_read",
                                "mode", "INCREMENT")),
                q("explore_market_wolf", "Pazar Yeri Kurdu",
                        "Eco-Market'ten beş alışveriş yap.",
                        125, 5, QuestCategory.MILESTONE,
                        QuestTriggerType.BUY_MARKET_ITEM,
                        Map.of("action", "market_purchase")),

                // 42-50: Takımlar ve küresel etki
                q("faction_choose_side", "Tarafını Seç",
                        "EcoVision takımını seç.",
                        50, 1, QuestCategory.FACTION,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "faction_selected")),
                q("faction_soldier", "Takım Askeri",
                        "Takımına yüz taramalık katkı sağla.",
                        250, 100, QuestCategory.FACTION,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "faction_scans")),
                q("faction_weekly_mvp", "Haftanın MVP'si",
                        "Takımında haftanın en yüksek katkısını yap.",
                        300, 1, QuestCategory.FACTION,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "faction_weekly_mvp")),
                q("faction_comeback", "Geri Dönüş",
                        "Geriden gelip haftalık takım mücadelesini kazan.",
                        180, 1, QuestCategory.FACTION,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "faction_comeback")),
                q("faction_ocean_savior", "Okyanusun Kurtarıcısı",
                        "Mavi takım için yüz plastik atık tara.",
                        350, 100, QuestCategory.FACTION,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "faction", "blue",
                                "wasteTypes", List.of("plastic"))),
                q("faction_forest_voice", "Ormanın Sesi",
                        "Yeşil takım için yüz kağıt atık tara.",
                        350, 100, QuestCategory.FACTION,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "faction", "green",
                                "wasteTypes", List.of("paper", "cardboard"))),
                q("faction_carbon_neutralizer", "Karbon Nötrleyici",
                        "Takımın için yüz kilogram CO2 etkisini önle.",
                        400, 100, QuestCategory.FACTION,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "faction_co2_kg")),
                q("faction_zero_waste_day", "Sıfır Atık Günü",
                        "Takımınla bir Sıfır Atık Günü tamamla.",
                        225, 1, QuestCategory.FACTION,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "faction_zero_waste_day")),
                q("faction_earth_hero", "Dünya'nın Kahramanı",
                        "Avatar yolundaki yirmi seviyenin tamamını bitir.",
                        1000, 20, QuestCategory.FACTION,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "avatar_level")),

                // 51-53: İleri dönüşüm ve eğitim
                q("upcycle_creative_spark", "Yaratıcı Kıvılcım",
                        "İlk ileri dönüşüm fikrini incele.",
                        30, 1, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "upcycle_guides_read",
                                "mode", "INCREMENT")),
                q("upcycle_zero_waste_artisan", "Sıfır Atık Zanaatkarı",
                        "On ileri dönüşüm çalışmasını tamamla.",
                        220, 10, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "upcycle_projects")),
                q("upcycle_encyclopedia_worm", "Ansiklopedi Kurdu",
                        "Ansiklopedinin beş ana kategorisini oku.",
                        100, 5, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "education_category",
                                "mode", "UNIQUE",
                                "uniqueAttribute", "category")),

                // 54-57: Yapay zeka hassasiyeti
                q("ai_whisperer", "Yapay Zeka Fısıldayanı",
                        "Yüzde doksan üzeri güvenle beş tarama yap.",
                        120, 5, QuestCategory.HIDDEN,
                        QuestTriggerType.AI_CONFIDENCE_HIGH,
                        Map.of("action", "scan", "minimumConfidence", 0.90)),
                q("ai_hawk_eye", "Şahin Gözlü",
                        "Yüzde doksan beş üzeri güvenle on tarama yap.",
                        220, 10, QuestCategory.HIDDEN,
                        QuestTriggerType.AI_CONFIDENCE_HIGH,
                        Map.of("action", "scan", "minimumConfidence", 0.95)),
                q("ai_glow_in_dark", "Karanlıkta Parlayan",
                        "Düşük ışıkta başarılı bir tarama tamamla.",
                        75, 1, QuestCategory.HIDDEN,
                        QuestTriggerType.AI_CONFIDENCE_HIGH,
                        Map.of("action", "low_light_scan")),
                q("ai_perfect_observer", "Kusursuz Gözlemci",
                        "Kamera açıldıktan sonraki ilk on saniyede tarama yap.",
                        60, 1, QuestCategory.HIDDEN,
                        QuestTriggerType.AI_CONFIDENCE_HIGH,
                        Map.of("action", "fast_scan")),

                // 58-61: Eco-Market
                q("market_first_investment", "İlk Yatırım",
                        "Eco-Market'ten ilk ürününü satın al.",
                        40, 1, QuestCategory.MILESTONE,
                        QuestTriggerType.BUY_MARKET_ITEM,
                        Map.of("action", "market_purchase")),
                q("market_generous_customer", "Cömert Müşteri",
                        "Eco-Market'te toplam beş bin puan harca.",
                        300, 5000, QuestCategory.MILESTONE,
                        QuestTriggerType.BUY_MARKET_ITEM,
                        Map.of("action", "market_purchase", "mode", "INCREMENT")),
                q("market_point_rich", "Puan Zengini",
                        "Kullanılabilir bakiyende on bin Eko Puana ulaş.",
                        500, 10000, QuestCategory.MILESTONE,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "total_points")),
                q("market_collector", "Koleksiyoner",
                        "Her Eco-Market ürün türünden en az bir eşya edin.",
                        250, 4, QuestCategory.MILESTONE,
                        QuestTriggerType.BUY_MARKET_ITEM,
                        Map.of("action", "market_purchase", "mode", "UNIQUE",
                                "uniqueAttribute", "itemType")),

                // 62-65: Ölçülebilir ekolojik etki
                q("impact_water_guardian", "Su Koruyucusu",
                        "Yüz litre su tasarrufu etkisine ulaş.",
                        150, 100, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "water_liters")),
                q("impact_forest_guardian", "Orman Muhafızı",
                        "Bir ağacın korunmasına eşdeğer etki oluştur.",
                        180, 1, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "trees_saved")),
                q("impact_energy_saver", "Enerji Tasarrufçusu",
                        "Elli kWh enerji tasarrufu etkisine ulaş.",
                        180, 50, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "energy_kwh")),
                q("impact_carbon_warrior", "Karbon Savaşçısı",
                        "On kilogram CO2 salımını önle.",
                        200, 10, QuestCategory.ECO_IMPACT,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "co2_kg")),

                // 66-69: Zaman ve konum
                q("time_early_bird", "Erken Kalkan Yol Alır",
                        "Saat 05.00-07.00 arasında bir atık tara.",
                        45, 1, QuestCategory.HIDDEN,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "scan", "startHour", 5, "endHour", 7)),
                q("time_student_break", "Öğrenci Molası",
                        "Saat 15.00-17.00 arasında üç atık tara.",
                        55, 3, QuestCategory.HIDDEN,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "scan", "startHour", 15, "endHour", 17)),
                q("time_productive_day", "Bereketli Gün",
                        "Aynı gün içinde dört ana atık kategorisini tara.",
                        120, 4, QuestCategory.HIDDEN,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "mode", "UNIQUE",
                                "uniqueAttribute", "wasteCategory", "period", "DAY")),
                q("time_last_minute_goal", "Son Dakika Golü",
                        "Bir görevi bitimine en fazla bir saat kala ilerlet.",
                        75, 1, QuestCategory.HIDDEN,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "quest_progress",
                                "expiresWithinMinutes", 60)),

                // 70-75: Gelişmiş sosyal görevler
                q("advanced_social_attraction_center", "Çekim Merkezi",
                        "Kurduğun grupta on üyeye ulaş.",
                        180, 10, QuestCategory.SOCIAL,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "created_group_members")),
                q("advanced_social_duo", "İkili Takım",
                        "Bir arkadaşınla karşılıklı beşer atık tara.",
                        200, 10, QuestCategory.SOCIAL,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "duo_pair_scans")),
                q("advanced_social_city_legend", "Şehir Efsanesi",
                        "Şehrinde özel Şehir Efsanesi başarısını kazan.",
                        450, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "city_legend_awarded")),
                q("advanced_social_model_citizen", "Örnek Vatandaş",
                        "Profilini gizli moddan herkese açık moda geçir.",
                        45, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "profile_made_public")),
                q("advanced_social_new_you", "Yeni Bir Sen",
                        "Kullandığın avatarı değiştir.",
                        40, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.BUY_MARKET_ITEM,
                        Map.of("action", "avatar_changed")),
                q("advanced_social_sustainable_hero", "Sürdürülebilir Kahraman",
                        "EcoVision kaydının üzerinden otuz gün geçsin.",
                        250, 30, QuestCategory.MILESTONE,
                        QuestTriggerType.REACH_SCORE,
                        Map.of("metric", "registration_days")),

                // 76-83: Geri dönüşüm uzmanlıkları
                q("recycling_pet_five", "5 Pet Şişe Geri Dönüştür",
                        "Beş PET şişeyi tarayıp doğru geri dönüşüm noktasına yönlendir.",
                        50, 5, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("plastic"))),
                q("recycling_pet_master", "PET Ustası",
                        "Toplam yirmi beş PET şişeyi geri dönüşüme kazandır.",
                        100, 25, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("plastic"))),
                q("recycling_pet_marathon", "PET Maratonu",
                        "Yüz PET şişeyi geri dönüşüm yolculuğuna çıkar.",
                        500, 100, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("plastic"))),
                q("recycling_glass_five", "Cam Beşlisi",
                        "Beş cam ambalajı güvenle geri dönüşüme yönlendir.",
                        50, 5, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("glass"))),
                q("recycling_glass_cycle", "Cam Döngüsü",
                        "Yirmi beş cam atığı sonsuz dönüşüm döngüsüne kat.",
                        100, 25, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "wasteTypes", List.of("glass"))),
                q("recycling_aluminum_three", "Alüminyum Üçlüsü",
                        "Üç alüminyum kutuyu tara ve enerji tasarrufuna katkı sağla.",
                        50, 3, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan",
                                "wasteTypes", List.of("metal", "aluminum"))),
                q("recycling_aluminum_hero", "Alüminyum Enerji Kahramanı",
                        "Yirmi alüminyum ambalajı geri dönüşüme kazandır.",
                        100, 20, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan",
                                "wasteTypes", List.of("metal", "aluminum"))),
                q("recycling_mixed_fifteen", "Karma Geri Dönüşüm",
                        "Beş PET, beş cam ve beş alüminyum atık tara.",
                        100, 15, QuestCategory.MILESTONE,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        Map.of("action", "scan", "requirements",
                                Map.of("plastic", 5, "glass", 5, "metal", 5))),

                // 84-87: Çevreci ulaşım
                q("transport_public_three", "Haftada 3 Gün Toplu Taşıma Kullan",
                        "Bu hafta üç farklı gün toplu taşıma kullanarak karbon salımını azalt.",
                        100, 3, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "public_transport",
                                "selfReport", true, "oncePerDay", true)),
                q("transport_bicycle_day", "Bisikletle Bir Gün",
                        "Bugünkü bir yolculuğunu bisikletle tamamla.",
                        50, 1, QuestCategory.DAILY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "bicycle_commute",
                                "selfReport", true, "oncePerDay", true)),
                q("transport_car_free_week", "Otomobilsiz Hafta",
                        "Bir hafta içinde beş gün özel otomobil kullanma.",
                        100, 5, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "car_free_day",
                                "selfReport", true, "oncePerDay", true)),
                q("transport_walking_series", "Yürüyüş Serisi",
                        "Yedi farklı günde kısa mesafelerini yürüyerek tamamla.",
                        100, 7, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "walking_commute",
                                "selfReport", true, "oncePerDay", true)),

                // 88-91: Enerji tasarrufu
                q("energy_lights_off", "Gereksiz Işıkları Kapat",
                        "Beş farklı gün kullanmadığın odaların ışıklarını kapat.",
                        20, 5, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "lights_off",
                                "selfReport", true, "oncePerDay", true)),
                q("energy_saving_mode", "Enerji Tasarruf Modu",
                        "Yedi gün boyunca cihazlarında enerji tasarruf modunu kullan.",
                        100, 7, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "energy_saving",
                                "selfReport", true, "oncePerDay", true)),
                q("energy_unplug_five", "Fişleri Çek",
                        "Kullanmadığın beş cihazı bekleme modunda bırakma.",
                        50, 5, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "unplug_device",
                                "selfReport", true, "oncePerDay", true)),
                q("energy_class_awareness", "Enerji Sınıfı Bilinci",
                        "Evindeki bir cihazın enerji sınıfını kontrol et.",
                        10, 1, QuestCategory.MILESTONE,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "energy_label_checked",
                                "selfReport", true, "oncePerDay", true)),

                // 92-95: Su tasarrufu
                q("water_tap_off", "Musluğu Kapat",
                        "Beş farklı gün diş fırçalarken musluğu kapalı tut.",
                        50, 5, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "tap_off",
                                "selfReport", true, "oncePerDay", true)),
                q("water_short_shower", "Kısa Duş Meydan Okuması",
                        "Beş farklı gün duş süreni beş dakikanın altında tut.",
                        100, 5, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "short_shower",
                                "selfReport", true, "oncePerDay", true)),
                q("water_full_machine", "Tam Dolu Makine",
                        "Çamaşır veya bulaşık makinesini üç kez tam dolu çalıştır.",
                        50, 3, QuestCategory.WEEKLY,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "full_load_wash",
                                "selfReport", true, "oncePerDay", true)),
                q("water_rain_friend", "Yağmur Suyu Dostu",
                        "Bitkilerin için bir kez yağmur suyu biriktir ve kullan.",
                        100, 1, QuestCategory.MILESTONE,
                        QuestTriggerType.TIME_BASED,
                        Map.of("action", "rainwater_reuse",
                                "selfReport", true, "oncePerDay", true)),

                // 96-100: Topluluk ve sürdürülebilir alışkanlık
                q("community_first_event", "Bir Çevre Temizliği Etkinliğine Katıl",
                        "EcoVision topluluğundaki ilk çevre etkinliğine katıl.",
                        200, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "event_attended")),
                q("community_event_volunteer", "Topluluk Gönüllüsü",
                        "Üç farklı çevre temizliği etkinliğine katıl.",
                        500, 3, QuestCategory.MILESTONE,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "event_attended", "mode", "UNIQUE",
                                "uniqueAttribute", "eventId")),
                q("community_event_organizer", "Etkinlik Organizatörü",
                        "Bir çevre temizliği etkinliği oluştur.",
                        200, 1, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "event_created")),
                q("community_cleanup_team", "Temizlik Ekibi",
                        "Bir grup görevinin beş adımına katkıda bulun.",
                        100, 5, QuestCategory.SOCIAL,
                        QuestTriggerType.INVITE_FRIEND,
                        Map.of("action", "group_mission_contribution")),
                q("streak_login_ten", "10 Gün Boyunca Uygulamaya Giriş Yap",
                        "On günlük EcoVision giriş serisini tamamla.",
                        150, 10, QuestCategory.MILESTONE,
                        QuestTriggerType.STREAK_DAYS,
                        Map.of("metric", "login_streak_days"))
        );
    }

    private static QuestDomain domainFor(QuestSeed seed) {
        String code = seed.code();
        if (code.startsWith("recycling_")
                || code.contains("plastic")
                || code.contains("glass")
                || code.contains("metal")
                || code.contains("paper")
                || code.contains("scan")) {
            return QuestDomain.RECYCLING;
        }
        if (code.startsWith("transport_")) {
            return QuestDomain.TRANSPORTATION;
        }
        if (code.startsWith("energy_")) {
            return QuestDomain.ENERGY_SAVING;
        }
        if (code.startsWith("water_")) {
            return QuestDomain.WATER_SAVING;
        }
        if (code.startsWith("community_") || code.contains("group")) {
            return QuestDomain.COMMUNITY;
        }
        if (code.startsWith("streak_")) {
            return QuestDomain.STREAK;
        }
        if (code.startsWith("market_")) {
            return QuestDomain.ECO_MARKET;
        }
        if (code.startsWith("upcycle_") || code.contains("education")) {
            return QuestDomain.EDUCATION;
        }
        if (seed.category() == QuestCategory.SOCIAL) {
            return QuestDomain.SOCIAL;
        }
        return QuestDomain.ECO_IMPACT;
    }

    private String toJson(Map<String, Object> criteria) {
        try {
            return objectMapper.writeValueAsString(criteria);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Görev kriteri yazılamadı", exception);
        }
    }

    private static QuestSeed q(
            String code,
            String title,
            String description,
            int rewardPoints,
            int targetAmount,
            QuestCategory category,
            QuestTriggerType triggerType,
            Map<String, Object> criteria
    ) {
        return new QuestSeed(
                code,
                title,
                description,
                rewardPoints,
                targetAmount,
                category,
                triggerType,
                criteria
        );
    }

    record QuestSeed(
            String code,
            String title,
            String description,
            int rewardPoints,
            int targetAmount,
            QuestCategory category,
            QuestTriggerType triggerType,
            Map<String, Object> criteria
    ) {
    }
}
