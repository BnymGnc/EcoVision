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

        Boolean tableExists = jdbcTemplate.queryForObject(
                "select to_regclass('public.group_members') is not null",
                Boolean.class
        );
        if (!Boolean.TRUE.equals(tableExists)) {
            return;
        }

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

    private record RoleConstraint(String name, String definition) {
    }
}
