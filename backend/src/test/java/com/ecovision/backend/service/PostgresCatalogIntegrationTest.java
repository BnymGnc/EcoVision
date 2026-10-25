package com.ecovision.backend.service;

import com.ecovision.backend.config.RvmDataLoader;
import com.ecovision.backend.repository.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.springframework.lang.NonNull;
import org.springframework.lang.Nullable;
import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named = "ECOVISION_TEST_JDBC_URL", matches = "jdbc:postgresql://127\\.0\\.0\\.1:(25439|5432)/ecovision_test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.datasource.url=${ECOVISION_TEST_JDBC_URL}",
        "spring.datasource.username=ecovision_test", "spring.datasource.password=local-validation-only",
        "app.jwt.secret=local-integration-test-only-signing-key-1234567890",
        "jwt.secret=local-integration-test-only-signing-key-1234567890", "GEMINI_API_KEY=",
        "spring.jpa.hibernate.ddl-auto=update", "spring.datasource.hikari.maximum-pool-size=3"
})
class PostgresCatalogIntegrationTest {
    @NonNull
    private static <T> T required(@Nullable T value) {
        if (value == null) throw new AssertionError("Required test fixture or response value was null");
        return value;
    }
    @Autowired MapPinRepository pins;
    @Autowired AppUserRepository users;
    @Autowired ObjectMapper mapper;
    @Autowired DoaMapService maps;
    @Autowired JdbcTemplate jdbc;
    @Autowired AuthService auth;
    @Autowired QuestCatalogService quests;
    @Autowired QuestRepository questRepository;
    @Autowired CarbonService carbon;
    @Autowired ScanHistoryRepository scans;
    @Autowired LeaderboardService leaderboard;
    @Autowired LoginActivityService logins;
    @Autowired DoaLocationService locations;
    @Autowired org.springframework.boot.test.web.client.TestRestTemplate http;
    @Autowired org.springframework.context.ApplicationContext context;

    @Test
    @org.springframework.transaction.annotation.Transactional
    void recyclingSummaryAggregatesUniqueRewardedScansWithoutChangingUsersOrActions() throws Exception {
        String suffix = java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        var response = auth.register(new com.ecovision.backend.dto.RegisterRequest(
                "Recycling", "Test", "recycling_" + suffix + "@ecovision.invalid",
                "LocalTest!" + suffix + "8aA", java.time.LocalDate.of(2000, 1, 1),
                "Kayseri", "Talas", "recycling_" + suffix, true, true));
        var user = users.findById(required(response.user().id())).orElseThrow();
        for (int i = 0; i < 6; i++) {
            var scan = new com.ecovision.backend.model.ScanHistory();
            scan.setUser(user);
            scan.setMaterialType(i == 2 ? "Cam Atık" : i == 3 ? "Metal Atık" : "Plastik Atık");
            scan.setImpactMaterial(i == 2 || i == 3 ? null : "pet");
            scan.setImageHash((i <= 1 ? "a" : Integer.toString(i)).repeat(64));
            scan.setPointsAwarded(i == 4 ? 0 : 10);
            scan.setIsRecyclable(i != 5);
            scans.save(scan);
        }
        scans.flush();
        var result = carbon.summary(user).recyclingPotential();
        assertEquals(3, result.recyclableScanCount());
        assertEquals(2, result.modeledScanCount());
        assertEquals(1, result.unmodeledScanCount());
        assertEquals(CarbonMath.wasteDifference("pet", 0.025, "LANDFILL", "RECYCLING")
                + CarbonMath.wasteDifference("glass", 0.2, "LANDFILL", "RECYCLING"), result.potentialKgCo2e(), 1e-12);
        assertEquals(0, carbon.summary(user).declaredActionCount());
        assertEquals(0, user.getTotalPoints());
        try (var input = new ClassPathResource("db/migration/V7__scan_recycling_potential_material.sql").getInputStream()) {
            String sql = new String(input.readAllBytes(), StandardCharsets.UTF_8);
            jdbc.execute(sql); jdbc.execute(sql);
        }
        assertEquals(3, carbon.summary(user).recyclingPotential().recyclableScanCount());
    }

    @Test void cityInventoryAndPagedApiPreserveAllSourceIdsAndDistrictFilters() throws Exception {
        var inventory = locations.inventory();
        assertEquals(81, inventory.cities().size());
        assertEquals(973, inventory.cities().stream().mapToInt(c -> c.districts().size()).sum());
        assertEquals(inventory.total(), inventory.unresolved() + inventory.cities().stream()
                .mapToInt(c -> c.counts().values().stream().mapToInt(v -> required(v).intValue()).sum()).sum());
        Set<Long> seen = new java.util.HashSet<>();
        int total = 0;
        for (int offset = 0; ; offset += 100) {
            var page = maps.search(39, 35, null, 100, offset, Set.of(), Set.of(), false, null, null, null, null, null);
            total = page.total();
            page.items().forEach(p -> assertTrue(seen.add(p.id())));
            if (!page.hasMore()) break;
        }
        assertEquals(total, seen.size()); assertTrue(total >= 4037);
        for (var city : inventory.cities()) {
            var ids = locations.ids(city.name(), null);
            var page = maps.search(39, 35, null, 100, 0, Set.of(), Set.of(), false, null, null, null, null, ids);
            assertEquals(ids.size(), page.total(), city.name());
        }
        var urfa = inventory.cities().stream().filter(c -> c.name().equals("Şanlıurfa")).findFirst().orElseThrow();
        assertEquals(27L, urfa.counts().get("DIM"));
        assertEquals(31, locations.ids("Şanlıurfa", null).size());
        assertFalse(locations.ids("Kayseri", "Talas").isEmpty());
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void startupImporterUpdatesAcrossBatchBoundaryWithinOnePooledTransaction() throws Exception {
        var catalog = RvmDataLoader.loadCatalog(mapper);
        long before = pins.count();
        jdbc.update("""
                update map_pins set dataset_hash = null where id in
                (select id from map_pins where provider = 'DOA' order by id limit 101)
                """);
        context.getBean("seedRvmMachineCatalog", org.springframework.boot.CommandLineRunner.class).run();
        assertEquals(before, pins.count());
        assertEquals(4037, pins.countByProviderAndDatasetHash("DOA", catalog.hash()));
        // Spring rolls back the fixture changes after this test.
    }
    @Test void importsAndQueriesAllSourcePointsWithoutDuplicatesAndMigrationIsIdempotent() throws Exception {
        var catalog = RvmDataLoader.loadCatalog(mapper);
        assertEquals(4037, pins.countByProviderAndDatasetHash("DOA", catalog.hash()));
        long before = pins.count();
        RvmDataLoader.importCatalog(catalog, users, pins, false);
        assertEquals(before, pins.count());
        var points = maps.nearby(37.17, 38.8, null, 500, Set.of(), Set.of("DIM"), false, null, null, null, null);
        assertFalse(points.isEmpty());
        assertTrue(points.stream().allMatch(p -> p.pointType().equals("DIM")));
        assertTrue(points.stream().anyMatch(p -> p.address().toUpperCase(java.util.Locale.forLanguageTag("tr")).contains("ŞANLIURFA")));
        assertNotNull(maps.detail(points.get(0).id()).weeklySchedule());
        try (var input = new ClassPathResource("db/migration/V3__expand_doa_map_pin_catalog.sql").getInputStream()) {
            String sql = new String(input.readAllBytes(), StandardCharsets.UTF_8);
            jdbc.execute(sql); jdbc.execute(sql);
        }
        assertEquals(before, pins.count());
    }

    @Test void concurrentClaimAwardsOnlyOnceAndDeclaredActionsAreIdempotent() throws Exception {
        String suffix = java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        var response = auth.register(new com.ecovision.backend.dto.RegisterRequest(
                "Integration", "Test", "integration_" + suffix + "@ecovision.invalid",
                "LocalTest!" + suffix + "8aA", java.time.LocalDate.of(2000, 1, 1),
                "Kayseri", "Talas", "integration_" + suffix, true, true));
        var user = users.findById(required(response.user().id())).orElseThrow();
        var quest = questRepository.findByActiveTrueOrderByIdAsc().stream()
                .filter(q -> q.getCode().equals("habit_prevent_01")).findFirst().orElseThrow();
        var progress = quests.checkIn(user, quest.getId());
        var executor = java.util.concurrent.Executors.newFixedThreadPool(2);
        try {
            var first = executor.submit(() -> quests.claim(user, progress.progressId()));
            var second = executor.submit(() -> quests.claim(user, progress.progressId()));
            assertEquals(quest.getRewardPoints(), first.get().pointsAwarded() + second.get().pointsAwarded());
            assertEquals(quest.getRewardPoints(), users.findById(required(user.getId())).orElseThrow().getTotalPoints());
        } finally { executor.shutdownNow(); }
        var action = new CarbonService.ActionRequest("one-real-action", "pet", 0.1, "LANDFILL", "RECYCLING");
        assertEquals(carbon.saveAction(user, action).id(), carbon.saveAction(user, action).id());
        assertEquals(1, carbon.summary(user).declaredActionCount());
        var saved = carbon.actions(user).get(0);
        double beforeCorrection = carbon.summary(user).estimatedDifferenceKg();
        carbon.updateMass(user, saved.id(), 0.2);
        assertEquals(beforeCorrection * 2, carbon.summary(user).estimatedDifferenceKg(), 1e-9);
        carbon.deleteAction(user, saved.id());
        assertEquals(0, carbon.summary(user).declaredActionCount());
        assertEquals(1, logins.record(user.getId()).currentStreak());
        assertEquals(1, logins.record(user.getId()).lastSevenDays().size());
        var today = java.time.LocalDate.now(java.time.ZoneId.of("Europe/Istanbul"));
        assertEquals(java.util.List.of(today), logins.history(user.getId(), null).loginDates());
        assertTrue(logins.history(user.getId(), java.time.YearMonth.from(today).minusMonths(1).toString()).loginDates().isEmpty());
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void surveyUpdatesProfileEstimateWithoutRepeatingRewardAndLeaderboardPagesAcrossCities() {
        String suffix = java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        var response = auth.register(new com.ecovision.backend.dto.RegisterRequest(
                "Survey", "Test", "survey_" + suffix + "@ecovision.invalid",
                "LocalTest!" + suffix + "8aA", java.time.LocalDate.of(2000, 1, 1),
                "Kayseri", "Talas", "survey_" + suffix, true, true));
        var user = users.findById(required(response.user().id())).orElseThrow();
        int before = user.getTotalPoints();
        assertEquals(75, carbon.completeSurvey(user, 4200).pointsAwarded());
        assertEquals(0, carbon.completeSurvey(user, 3100).pointsAwarded());
        assertEquals(3100.0, carbon.summary(user).latestAnnualKg());
        assertEquals(before + 75, users.findById(required(user.getId())).orElseThrow().getTotalPoints());
        var global = leaderboard.globalLeaderboard(user, null, 0, 1);
        assertEquals(1, global.items().size());
        assertEquals(users.count(), global.total());
        var city = leaderboard.globalLeaderboard(user, "Kayseri", 0, 100);
        assertTrue(city.items().stream().allMatch(entry -> "Kayseri".equals(entry.city())));
        assertTrue(city.items().stream().anyMatch(entry -> required(user.getId()).equals(entry.userId())));
    }

    @Test void protectedApisRejectAnonymousAccessAndHealthRemainsPublic() {
        assertEquals(401, http.getForEntity("/api/map-pins/nearby?lat=38&lng=35", String.class).getStatusCode().value());
        assertEquals(401, http.getForEntity("/api/users/login-history", String.class).getStatusCode().value());
        assertEquals(200, http.getForEntity("/api/health", String.class).getStatusCode().value());
        assertEquals(200, http.getForEntity("/api/health/live", String.class).getStatusCode().value());
        assertEquals(200, http.exchange("/api/health/live", org.springframework.http.HttpMethod.HEAD,
                org.springframework.http.HttpEntity.EMPTY, String.class).getStatusCode().value());
        assertEquals(200, http.getForEntity("/actuator/health/readiness", String.class).getStatusCode().value());
        assertEquals(200, http.getForEntity("/actuator/health/liveness", String.class).getStatusCode().value());
    }

    private com.ecovision.backend.dto.AuthResponse securityAccount() {
        String suffix = java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        return auth.register(new com.ecovision.backend.dto.RegisterRequest(
            "Security", "Test", suffix+"@ecovision.invalid", "Local!8aA"+suffix,
            java.time.LocalDate.of(2000,1,1), "Kayseri","Talas","sec_"+suffix,true,true));
    }
    @NonNull
    private org.springframework.http.HttpHeaders bearer(@Nullable String token) {
        var headers = new org.springframework.http.HttpHeaders();
        if (token != null) headers.setBearerAuth(token);
        return headers;
    }
    private org.springframework.http.ResponseEntity<String> media(String path, String token) {
        return http.exchange(path, org.springframework.http.HttpMethod.GET,
            new org.springframework.http.HttpEntity<>(bearer(token)), String.class);
    }

    @Test void profileMediaEnforcesLivePrivacyFriendshipAgeAndLegacyRules() throws Exception {
        var owner = securityAccount(); var friend = securityAccount(); var stranger = securityAccount();
        var png = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(2,2,1),"png",png);
        var part = new org.springframework.core.io.ByteArrayResource(required(png.toByteArray())) {
            @Override public String getFilename() { return "avatar.png"; }
        };
        var body = new org.springframework.util.LinkedMultiValueMap<String,Object>();
        body.add("image", part);
        var headers = bearer(owner.accessToken());
        headers.setContentType(org.springframework.http.MediaType.MULTIPART_FORM_DATA);
        var uploaded = http.exchange("/api/auth/me/profile-picture", org.springframework.http.HttpMethod.POST,
            new org.springframework.http.HttpEntity<>(body, headers), java.util.Map.class);
        assertEquals(200, uploaded.getStatusCode().value());
        String path = required(required(uploaded.getBody()).get("profilePictureUrl")).toString();
        var record = users.findById(required(owner.user().id())).orElseThrow();
        record.setProfileVisibility(com.ecovision.backend.model.ProfileVisibility.FRIENDS_ONLY);
        users.save(record);
        assertEquals(401, media(path,null).getStatusCode().value());
        assertEquals(403, media(path,stranger.accessToken()).getStatusCode().value());
        assertEquals(200, media(path,owner.accessToken()).getStatusCode().value());
        assertTrue(required(media(path,owner.accessToken()).getHeaders().getCacheControl()).contains("no-store"));
        var friendship = new com.ecovision.backend.model.Friendship();
        friendship.setRequester(users.findById(required(owner.user().id())).orElseThrow());
        friendship.setAddressee(users.findById(required(friend.user().id())).orElseThrow());
        friendship.setStatus(com.ecovision.backend.model.FriendshipStatus.ACCEPTED);
        var friends = context.getBean(FriendshipRepository.class);
        friendship = friends.save(friendship);
        assertEquals(200, media(path,friend.accessToken()).getStatusCode().value());
        friends.deleteById(required(friendship.getId()));
        assertEquals(403, media(path,friend.accessToken()).getStatusCode().value());
        record = users.findById(required(owner.user().id())).orElseThrow();
        record.setProfileVisibility(com.ecovision.backend.model.ProfileVisibility.PUBLIC);
        users.save(record);
        assertEquals(200, media(path,null).getStatusCode().value());
        // Existing media with no uploader metadata still uses its current domain owner.
        jdbc.update("update media_assets set owner_user_id=null where id=?",
            java.util.UUID.fromString(path.substring(path.lastIndexOf('/')+1)));
        assertEquals(200, media(path,null).getStatusCode().value());
        record = users.findById(required(owner.user().id())).orElseThrow();
        record.setDateOfBirth(java.time.LocalDate.now().minusYears(16)); users.save(record);
        assertEquals(403, media(path,owner.accessToken()).getStatusCode().value());
    }

    @Test void privateGroupMediaRevokesOnKickAndLogoutAndUnknownMediaFailsClosed() {
        var founder = securityAccount(); var member = securityAccount(); var stranger = securityAccount();
        var group = new com.ecovision.backend.model.CommunityGroup();
        group.setCreator(users.findById(required(founder.user().id())).orElseThrow());
        group.setName("Private test"); group.setDescription("Local test only");
        group.setCity("Kayseri"); group.setDistrict("Talas"); group.setPrivateGroup(true);
        group = context.getBean(CommunityGroupRepository.class).save(group);
        var membership = new com.ecovision.backend.model.GroupMember();
        membership.setGroup(group); membership.setUser(users.findById(required(member.user().id())).orElseThrow());
        var memberships = context.getBean(GroupMemberRepository.class);
        membership = memberships.save(membership);
        var asset = new com.ecovision.backend.model.MediaAsset();
        asset.setCategory("group-chat"); asset.setOwnerUserId(founder.user().id());
        asset.setContentType("application/pdf"); asset.setOriginalFileName("test.pdf");
        asset.setData("%PDF-1.7 local test".getBytes(java.nio.charset.StandardCharsets.UTF_8));
        asset.setSizeBytes(asset.getData().length);
        asset = context.getBean(MediaAssetRepository.class).save(asset);
        String path = "/api/media/"+asset.getId();
        var message = new com.ecovision.backend.model.ChatMessage();
        message.setGroup(group); message.setSender(users.findById(required(founder.user().id())).orElseThrow());
        message.setMessage(""); message.setFileUrl(path);
        context.getBean(ChatMessageRepository.class).save(message);
        assertEquals(401, media(path,null).getStatusCode().value());
        assertEquals(403, media(path,stranger.accessToken()).getStatusCode().value());
        assertEquals(200, media(path,member.accessToken()).getStatusCode().value());
        // Delegated admins may upload a cover: uploader need not be the founder.
        var cover = new com.ecovision.backend.model.MediaAsset();
        cover.setCategory("groups"); cover.setOwnerUserId(member.user().id());
        cover.setContentType("image/png"); cover.setOriginalFileName("cover.png");
        cover.setData(new byte[]{1}); cover.setSizeBytes(1);
        cover = context.getBean(MediaAssetRepository.class).save(cover);
        String coverPath = "/api/media/"+cover.getId();
        group.setCoverImageUrl(coverPath);
        context.getBean(CommunityGroupRepository.class).save(group);
        assertEquals(200,media(coverPath,founder.accessToken()).getStatusCode().value());
        assertEquals(200,media(coverPath,member.accessToken()).getStatusCode().value());
        assertEquals(403,media(coverPath,stranger.accessToken()).getStatusCode().value());
        var legacy = new com.ecovision.backend.model.Event();
        legacy.setCreator(users.findById(required(founder.user().id())).orElseThrow());
        legacy.setTitle("Legacy group"); legacy.setDescription("Local security fixture");
        legacy.setLocation("Kayseri"); legacy.setEventDate(java.time.Instant.now());
        legacy=context.getBean(EventRepository.class).save(legacy);
        group.setLegacyEventId(legacy.getId());
        context.getBean(CommunityGroupRepository.class).save(group);
        var oldMembership = new com.ecovision.backend.model.EventMember();
        oldMembership.setEvent(legacy);
        oldMembership.setUser(users.findById(required(member.user().id())).orElseThrow());
        oldMembership.setRole(com.ecovision.backend.model.GroupRole.MEMBER);
        context.getBean(EventMemberRepository.class).save(oldMembership);
        var legacyAsset = new com.ecovision.backend.model.MediaAsset();
        legacyAsset.setCategory("chat"); legacyAsset.setOwnerUserId(founder.user().id());
        legacyAsset.setContentType("application/pdf"); legacyAsset.setOriginalFileName("legacy.pdf");
        legacyAsset.setData(new byte[]{1}); legacyAsset.setSizeBytes(1);
        legacyAsset=context.getBean(MediaAssetRepository.class).save(legacyAsset);
        String legacyPath="/api/media/"+legacyAsset.getId();
        var oldMessage=new com.ecovision.backend.model.ChatMessage();
        oldMessage.setEvent(legacy); oldMessage.setSender(users.findById(required(founder.user().id())).orElseThrow());
        oldMessage.setMessage(""); oldMessage.setFileUrl(legacyPath);
        context.getBean(ChatMessageRepository.class).save(oldMessage);
        assertEquals(200,media(legacyPath,member.accessToken()).getStatusCode().value());
        memberships.deleteById(required(membership.getId()));
        assertEquals(403, media(path,member.accessToken()).getStatusCode().value());
        assertEquals(403, media(legacyPath,member.accessToken()).getStatusCode().value());
        assertEquals(200, media(path,founder.accessToken()).getStatusCode().value());
        var logout = http.exchange("/api/auth/logout",org.springframework.http.HttpMethod.POST,
            new org.springframework.http.HttpEntity<>(java.util.Map.of("refreshToken",founder.refreshToken()),bearer(founder.accessToken())),
            String.class);
        assertEquals(204, logout.getStatusCode().value());
        assertEquals(401, media(path,founder.accessToken()).getStatusCode().value());
        var orphan = new com.ecovision.backend.model.MediaAsset();
        orphan.setCategory("unknown"); orphan.setContentType("application/pdf");
        orphan.setOriginalFileName("orphan.pdf"); orphan.setSizeBytes(1); orphan.setData(new byte[]{1});
        orphan = context.getBean(MediaAssetRepository.class).save(orphan);
        assertEquals(403,media("/api/media/"+orphan.getId(),stranger.accessToken()).getStatusCode().value());
    }

    @Test void quizServerGradesAllThresholdsAndConcurrentCompletionAwardsOnce() throws Exception {
        var user = securityAccount(); var other = securityAccount();
        String path = "/api/education/complete/modul-1";
        for (var answers : java.util.List.of(java.util.List.of(0,1,0),java.util.List.of(1,1,0))) {
            var response = http.exchange(path,org.springframework.http.HttpMethod.POST,
                new org.springframework.http.HttpEntity<>(java.util.Map.of("quizVersion","2026-10-24-v1","answers",answers),bearer(user.accessToken())), java.util.Map.class);
            assertEquals(422,response.getStatusCode().value());
        }
        var missing = http.exchange(path,org.springframework.http.HttpMethod.POST,
            new org.springframework.http.HttpEntity<>(java.util.Map.of(),bearer(user.accessToken())),java.util.Map.class);
        assertEquals(426, missing.getStatusCode().value());
        var payload = java.util.Map.of("quizVersion","2026-10-24-v1","answers",java.util.List.of(1,0,0));
        var executor = java.util.concurrent.Executors.newFixedThreadPool(2);
        try {
            java.util.concurrent.Callable<Integer> claim = () -> {
                var response = http.exchange(path,org.springframework.http.HttpMethod.POST,
                    new org.springframework.http.HttpEntity<>(payload,bearer(user.accessToken())),java.util.Map.class);
                assertEquals(200,response.getStatusCode().value());
                return ((Number)required(required(response.getBody()).get("pointsAwarded"))).intValue();
            };
            var a=executor.submit(claim); var b=executor.submit(claim);
            assertEquals(30,a.get()+b.get());
        } finally { executor.shutdownNow(); }
        var repeated=http.exchange(path,org.springframework.http.HttpMethod.POST,
            new org.springframework.http.HttpEntity<>(java.util.Map.of("quizVersion","2026-10-24-v1","answers",java.util.List.of(1,0,2)),bearer(user.accessToken())),java.util.Map.class);
        assertEquals(0,((Number)required(required(repeated.getBody()).get("pointsAwarded"))).intValue());
        assertEquals(0,users.findById(required(other.user().id())).orElseThrow().getTotalPoints());
        var publicQuiz=http.exchange("/api/education/quiz/modul-1",org.springframework.http.HttpMethod.GET,
            new org.springframework.http.HttpEntity<>(bearer(user.accessToken())),String.class);
        assertEquals(200,publicQuiz.getStatusCode().value());
        assertFalse(required(publicQuiz.getBody()).contains("correctOptionIndex"));
    }

    @Test void imageRewardsAreSerializedPerUserAndLegacyLabelsCannotMintPoints() throws Exception {
        var identity=securityAccount(); var other=securityAccount();
        var user=users.findById(required(identity.user().id())).orElseThrow();
        var scans=context.getBean(ScanService.class);
        String hash="1".repeat(64);
        var executor=java.util.concurrent.Executors.newFixedThreadPool(2);
        try {
            java.util.concurrent.Callable<Integer> call=()->scans.saveVerifiedAnalysis(user,"plastic",true,hash).pointsAwarded();
            var a=executor.submit(call); var b=executor.submit(call);
            assertEquals(10,a.get()+b.get());
        } finally {executor.shutdownNow();}
        assertEquals(10,users.findById(required(user.getId())).orElseThrow().getTotalPoints());
        assertEquals("DUPLICATE_IMAGE",scans.saveVerifiedAnalysis(user,"plastic",true,hash).rewardStatus());
        jdbc.update("update scan_history set reward_date=reward_date - 1 where user_id=? and image_hash=? and points_awarded>0", user.getId(), hash);
        assertEquals(0, scans.saveVerifiedAnalysis(user,"plastic",true,hash).pointsAwarded(), "The next day must not mint another reward for the same bytes");
        assertEquals(1,context.getBean(ScanHistoryRepository.class)
            .countByUserIdAndMaterialTypeIgnoreCase(required(user.getId()),"Plastik Atık"));
        assertEquals(10,scans.saveVerifiedAnalysis(users.findById(required(other.user().id())).orElseThrow(),"plastic",true,hash).pointsAwarded());
        var legacy=http.exchange("/api/scans",org.springframework.http.HttpMethod.POST,
            new org.springframework.http.HttpEntity<>(java.util.Map.of("materialType","plastic","recyclable",true),bearer(identity.accessToken())),java.util.Map.class);
        assertEquals(200,legacy.getStatusCode().value());
        assertEquals(10,users.findById(required(user.getId())).orElseThrow().getTotalPoints());
        try(var in=new ClassPathResource("db/migration/V6__media_scope_scan_reward_and_token_revocation.sql").getInputStream()) {
            String sql=new String(in.readAllBytes(),StandardCharsets.UTF_8); jdbc.execute(sql);jdbc.execute(sql);
        }
    }
}
