package com.ecovision.backend.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.scheduling.annotation.Scheduled;

@Service
public class AccessTokenRevocations {
    private final JdbcTemplate jdbc;
    private final JwtService jwt;
    public AccessTokenRevocations(JdbcTemplate jdbc, JwtService jwt) { this.jdbc = jdbc; this.jwt = jwt; }
    public boolean revoked(String token) {
        return Boolean.TRUE.equals(jdbc.queryForObject(
                "select exists(select 1 from revoked_access_tokens where token_hash=? and expires_at>now())",
                Boolean.class, hash(token)));
    }
    public void revokeHeader(String header) {
        if (header == null || !header.startsWith("Bearer ")) return;
        String token = header.substring(7);
        try {
            Instant expiry = jwt.expiration(token);
            jdbc.update("insert into revoked_access_tokens(token_hash,expires_at) values (?,?) on conflict do nothing",
                    hash(token), java.sql.Timestamp.from(expiry));
        } catch (io.jsonwebtoken.JwtException | IllegalArgumentException ignored) {
            // Invalid tokens do not create database rows or reveal token data.
        }
    }
    @Scheduled(fixedDelay = 3600000)
    public void purgeExpired() { jdbc.update("delete from revoked_access_tokens where expires_at<=now()"); }
    private String hash(String token) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
}
