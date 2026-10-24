package com.ecovision.backend.config;

import java.sql.DatabaseMetaData;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.stereotype.Component;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class DatabaseCompatibilityInitializer implements CommandLineRunner {
    private static final Logger LOGGER =
            LoggerFactory.getLogger(DatabaseCompatibilityInitializer.class);

    private final JdbcTemplate jdbcTemplate;

    public DatabaseCompatibilityInitializer(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(String... args) {
        String productName = jdbcTemplate.execute((ConnectionCallback<String>) connection -> {
            DatabaseMetaData metadata = connection.getMetaData();
            return metadata.getDatabaseProductName();
        });
        if (!"PostgreSQL".equalsIgnoreCase(productName)) {
            return;
        }

        normalizeProfileVisibilityColumn();

        Boolean tableExists = jdbcTemplate.queryForObject(
                "select to_regclass('public.group_members') is not null",
                Boolean.class
        );
        if (Boolean.TRUE.equals(tableExists)) {
            updateGroupRoleConstraint();
        }

        Boolean chatTableExists = jdbcTemplate.queryForObject(
                "select to_regclass('public.chat_messages') is not null",
                Boolean.class
        );
        if (Boolean.TRUE.equals(chatTableExists)) {
            updateChatMessageTypeConstraint();
        }
    }

    /**
     * Keeps fresh Hibernate-created schemas aligned with the versioned Flyway
     * migration. This deliberately uses PostgreSQL's separate TYPE and
     * DEFAULT statements; Hibernate must never combine them for this column.
     */
    private void normalizeProfileVisibilityColumn() {
        Boolean columnExists = jdbcTemplate.queryForObject(
                """
                select exists (
                    select 1
                    from information_schema.columns
                    where table_schema = 'public'
                      and table_name = 'users'
                      and column_name = 'profile_visibility'
                )
                """,
                Boolean.class
        );
        if (!Boolean.TRUE.equals(columnExists)) {
            return;
        }

        ProfileVisibilityColumn column = jdbcTemplate.queryForObject(
                """
                select data_type, character_maximum_length, column_default, is_nullable
                from information_schema.columns
                where table_schema = 'public'
                  and table_name = 'users'
                  and column_name = 'profile_visibility'
                """,
                (resultSet, rowNumber) -> new ProfileVisibilityColumn(
                        resultSet.getString("data_type"),
                        resultSet.getObject("character_maximum_length", Integer.class),
                        resultSet.getString("column_default"),
                        resultSet.getString("is_nullable")
                )
        );
        if (column == null) {
            return;
        }

        boolean typeNeedsUpdate = !"character varying".equals(column.dataType())
                || !Integer.valueOf(20).equals(column.maximumLength());
        boolean hasPublicDefault = column.defaultValue() != null
                && column.defaultValue().toUpperCase().contains("'PUBLIC'");
        boolean needsNotNull = "YES".equalsIgnoreCase(column.nullable());
        if (!typeNeedsUpdate && hasPublicDefault && !needsNotNull) {
            return;
        }

        // Existing values are intentionally preserved. Only legacy null/blank
        // rows are normalized before enforcing the non-null contract.
        jdbcTemplate.execute(
                "update public.users set profile_visibility = 'PUBLIC' "
                        + "where profile_visibility is null "
                        + "or btrim(profile_visibility::text) = ''"
        );
        if (typeNeedsUpdate) {
            jdbcTemplate.execute(
                    "alter table public.users alter column profile_visibility drop default"
            );
            jdbcTemplate.execute(
                    "alter table public.users alter column profile_visibility "
                            + "type varchar(20) using profile_visibility::text"
            );
        }
        if (!hasPublicDefault || typeNeedsUpdate) {
            jdbcTemplate.execute(
                    "alter table public.users alter column profile_visibility "
                            + "set default 'PUBLIC'"
            );
        }
        if (needsNotNull) {
            jdbcTemplate.execute(
                    "alter table public.users alter column profile_visibility set not null"
            );
        }
    }

    private void updateGroupRoleConstraint() {
        List<RoleConstraint> constraints = jdbcTemplate.query(
                """
                select conname, pg_get_constraintdef(oid)
                from pg_constraint
                where conrelid = 'public.group_members'::regclass
                  and contype = 'c'
                  and lower(pg_get_constraintdef(oid)) like '%role%'
                """,
                (resultSet, rowNumber) -> new RoleConstraint(
                        resultSet.getString(1),
                        resultSet.getString(2)
                )
        );
        boolean alreadyCompatible = constraints.stream()
                .map(RoleConstraint::definition)
                .map(String::toUpperCase)
                .anyMatch(definition ->
                        definition.contains("FOUNDER")
                                && definition.contains("ADMIN")
                                && definition.contains("MEMBER"));
        if (alreadyCompatible) {
            return;
        }

        for (RoleConstraint constraint : constraints) {
            String safeName = constraint.name().replace("\"", "\"\"");
            jdbcTemplate.execute(
                    "alter table public.group_members drop constraint if exists \""
                            + safeName + "\""
            );
        }
        jdbcTemplate.execute(
                """
                alter table public.group_members
                add constraint chk_group_members_role
                check (role in ('FOUNDER', 'ADMIN', 'GROUP_ADMIN', 'MEMBER'))
                """
        );
        LOGGER.info("Updated group_members role constraint for FOUNDER/ADMIN RBAC");
    }

    private void updateChatMessageTypeConstraint() {
        // Legacy chat rows belonged only to events. Group chat uses group_id,
        // so the old event_id NOT NULL constraint must not reject new rows.
        jdbcTemplate.execute(
                "alter table public.chat_messages alter column event_id drop not null"
        );
        jdbcTemplate.execute(
                "update public.chat_messages set message_type = 'USER' "
                        + "where message_type is null"
        );
        jdbcTemplate.execute(
                "alter table public.chat_messages alter column message_type "
                        + "set default 'USER'"
        );
        jdbcTemplate.execute(
                "alter table public.chat_messages alter column message_type "
                        + "set not null"
        );
        List<RoleConstraint> constraints = jdbcTemplate.query(
                """
                select conname, pg_get_constraintdef(oid)
                from pg_constraint
                where conrelid = 'public.chat_messages'::regclass
                  and contype = 'c'
                  and lower(pg_get_constraintdef(oid)) like '%message_type%'
                """,
                (resultSet, rowNumber) -> new RoleConstraint(
                        resultSet.getString(1),
                        resultSet.getString(2)
                )
        );
        boolean alreadyCompatible = constraints.stream()
                .map(RoleConstraint::definition)
                .map(String::toUpperCase)
                .anyMatch(definition ->
                        definition.contains("POLL")
                                && definition.contains("SYSTEM_EVENT")
                                && definition.contains("SYSTEM_ACTIVITY"));
        if (alreadyCompatible) {
            return;
        }
        for (RoleConstraint constraint : constraints) {
            String safeName = constraint.name().replace("\"", "\"\"");
            jdbcTemplate.execute(
                    "alter table public.chat_messages drop constraint if exists \""
                            + safeName + "\""
            );
        }
        jdbcTemplate.execute(
                """
                alter table public.chat_messages
                add constraint chk_chat_messages_type
                check (message_type in (
                    'USER', 'POLL', 'SYSTEM_ACTIVITY', 'SYSTEM_BADGE',
                    'SYSTEM_LEVEL', 'SYSTEM_EVENT'
                ))
                """
        );
        LOGGER.info("Updated chat_messages type constraint for rich group chat");
    }

    private record RoleConstraint(String name, String definition) {
    }

    private record ProfileVisibilityColumn(
            String dataType,
            Integer maximumLength,
            String defaultValue,
            String nullable
    ) {
    }
}
