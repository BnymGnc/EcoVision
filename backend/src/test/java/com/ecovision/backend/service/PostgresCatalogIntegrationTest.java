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
import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named = "ECOVISION_TEST_JDBC_URL", matches = "jdbc:postgresql://127\\.0\\.0\\.1:25439/ecovision_test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.datasource.url=${ECOVISION_TEST_JDBC_URL}",
        "spring.datasource.username=ecovision_test", "spring.datasource.password=local-validation-only",
        "app.jwt.secret=local-integration-test-only-signing-key-1234567890",
        "jwt.secret=local-integration-test-only-signing-key-1234567890", "GEMINI_API_KEY=",
        "spring.jpa.hibernate.ddl-auto=update", "spring.datasource.hikari.maximum-pool-size=3"
})
class PostgresCatalogIntegrationTest {
    @Autowired MapPinRepository pins;
    @Autowired AppUserRepository users;
    @Autowired ObjectMapper mapper;
    @Autowired DoaMapService maps;
    @Autowired JdbcTemplate jdbc;
    @Autowired AuthService auth;
    @Autowired QuestCatalogService quests;
    @Autowired QuestRepository questRepository;
    @Autowired CarbonService carbon;
    @Autowired LoginActivityService logins;
    @Autowired org.springframework.boot.test.web.client.TestRestTemplate http;
    @Autowired org.springframework.context.ApplicationContext context;

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
        var user = users.findById(response.user().id()).orElseThrow();
        var quest = questRepository.findByActiveTrueOrderByIdAsc().stream()
                .filter(q -> q.getCode().equals("habit_prevent_01")).findFirst().orElseThrow();
        var progress = quests.checkIn(user, quest.getId());
        var executor = java.util.concurrent.Executors.newFixedThreadPool(2);
        try {
            var first = executor.submit(() -> quests.claim(user, progress.progressId()));
            var second = executor.submit(() -> quests.claim(user, progress.progressId()));
            assertEquals(quest.getRewardPoints(), first.get().pointsAwarded() + second.get().pointsAwarded());
            assertEquals(quest.getRewardPoints(), users.findById(user.getId()).orElseThrow().getTotalPoints());
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
    }

    @Test void protectedApisRejectAnonymousAccessAndHealthRemainsPublic() {
        assertEquals(401, http.getForEntity("/api/map-pins/nearby?lat=38&lng=35", String.class).getStatusCode().value());
        assertEquals(200, http.getForEntity("/api/health", String.class).getStatusCode().value());
    }
}
