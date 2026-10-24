package com.ecovision.backend.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import jakarta.persistence.Column;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;

class ProfileVisibilitySchemaTest {

    @Test
    void profileVisibilityDoesNotAskHibernateToEmbedDefaultInTypeAlteration()
            throws NoSuchFieldException {
        Field field = AppUser.class.getDeclaredField("profileVisibility");
        Column column = field.getAnnotation(Column.class);

        assertEquals("profile_visibility", column.name());
        assertEquals(20, column.length());
        assertTrue(column.columnDefinition().isBlank());
    }

    @Test
    void hibernateManagedDefaultsAreNotEmbeddedInColumnDefinitions()
            throws NoSuchFieldException {
        for (Field field : List.of(
                AppUser.class.getDeclaredField("selectedAvatarPath"),
                AppUser.class.getDeclaredField("themePreference"),
                AppUser.class.getDeclaredField("banned"),
                AppUser.class.getDeclaredField("failedLoginAttempts"),
                AppUser.class.getDeclaredField("profileVisibility"),
                ChatMessage.class.getDeclaredField("deleted"),
                ChatMessage.class.getDeclaredField("messageType"),
                CommunityGroup.class.getDeclaredField("privateGroup")
        )) {
            assertTrue(field.getAnnotation(Column.class).columnDefinition().isBlank());
        }
    }

    @Test
    void migrationUsesPostgreSqlCompatibleSeparateDefaultStatement() throws Exception {
        ClassPathResource migration = new ClassPathResource(
                "db/migration/V1__normalize_users_profile_visibility.sql"
        );
        String sql = new String(
                migration.getInputStream().readAllBytes(),
                StandardCharsets.UTF_8
        ).toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");

        assertTrue(sql.contains("alter column profile_visibility type varchar(20)"));
        assertTrue(sql.contains("alter column profile_visibility set default 'public'"));
        assertFalse(sql.contains("type varchar(20) default"));
    }
}
