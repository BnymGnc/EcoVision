package com.ecovision.backend.tools;

import java.io.Console;
import java.sql.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Arrays;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** Local operator tool. Does not start Spring, seed data, or expose an HTTP endpoint. */
public final class AdminPasswordReset {
    private AdminPasswordReset() {}
    public static void main(String[] args) throws Exception {
        Console console = System.console();
        if (console == null || args.length != 1) {
            System.err.println("Use an interactive terminal and pass the existing admin email as the only argument.");
            System.exit(2);
        }
        char[] first = console.readPassword("New password: ");
        char[] second = console.readPassword("Confirm password: ");
        try {
            if (first == null || second == null || !Arrays.equals(first, second)
                    || !new String(first).matches("(?s)^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).{12,72}$")) {
                throw new IllegalArgumentException("Passwords must match and contain 12-72 characters, upper/lowercase, a digit and a symbol.");
            }
            String url = required("SPRING_DATASOURCE_URL");
            try (Connection connection = DriverManager.getConnection(url,
                    required("SPRING_DATASOURCE_USERNAME"), required("SPRING_DATASOURCE_PASSWORD"))) {
                connection.setAutoCommit(false);
                try {
                    Long userId;
                    try (PreparedStatement query = connection.prepareStatement(
                            "select id, role from users where lower(email) = lower(?) for update")) {
                        query.setString(1, args[0].trim());
                        try (ResultSet row = query.executeQuery()) {
                            if (!row.next() || !("ADMIN".equals(row.getString("role"))
                                    || "SUPERUSER".equals(row.getString("role"))))
                                throw new IllegalArgumentException("The selected existing account is not an admin.");
                            userId = row.getLong("id");
                        }
                    }
                    try (PreparedStatement update = connection.prepareStatement(
                            "update users set password=?, credentials_changed_at=?, failed_login_attempts=0, lockout_until=null where id=?")) {
                        update.setString(1, new BCryptPasswordEncoder().encode(new String(first)));
                        update.setTimestamp(2, Timestamp.from(Instant.now().truncatedTo(ChronoUnit.MILLIS)));
                        update.setLong(3, userId);
                        update.executeUpdate();
                    }
                    try (PreparedStatement revoke = connection.prepareStatement(
                            "update refresh_tokens set revoked=true where user_id=?")) {
                        revoke.setLong(1, userId); revoke.executeUpdate();
                    }
                    connection.commit();
                    console.printf("Selected admin password updated; existing sessions revoked.%n");
                } catch (Exception failure) {
                    connection.rollback();
                    throw failure;
                }
            }
        } catch (SQLException failure) {
            System.err.println("Database operation failed. Check environment and migration state. SQLState=" + failure.getSQLState());
            System.exit(1);
        } finally {
            if (first != null) Arrays.fill(first, '\0');
            if (second != null) Arrays.fill(second, '\0');
        }
    }
    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) throw new IllegalArgumentException("Missing environment variable: " + name);
        return value;
    }
}
