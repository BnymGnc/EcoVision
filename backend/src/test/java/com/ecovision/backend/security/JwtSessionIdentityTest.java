package com.ecovision.backend.security;
import com.ecovision.backend.model.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class JwtSessionIdentityTest {
    private JwtService service() { return new JwtService("local-unit-test-signing-key-never-for-production-12345",900000); }
    @Test void sessionsIssuedInSameSecondHaveDifferentTokens() {
        var jwt=service();
        var user=new AppUser(); user.setId(1L); user.setEmail("test@ecovision.invalid");user.setRole(Role.USER);
        String first=jwt.generateToken(user),second=jwt.generateToken(user);
        assertNotEquals(first,second);
        assertTrue(jwt.isValid(first,user));assertTrue(jwt.isValid(second,user));
    }
    @Test void invalidLogoutTokenDoesNotCreateRevocationRecords() {
        var jdbc=new org.springframework.jdbc.core.JdbcTemplate() {
            @Override public int update(String sql,Object... args) { throw new AssertionError("Invalid token must not write to DB"); }
        };
        new AccessTokenRevocations(jdbc,service()).revokeHeader("Bearer not-a-token");
    }
}
