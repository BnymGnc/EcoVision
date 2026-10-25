package com.ecovision.backend.security;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import static org.mockito.Mockito.*;

class JwtLivenessIsolationTest {
    @Test
    void getAndHeadLivenessNeverTouchJwtOrDatabaseEvenWithBearerHeader() throws Exception {
        var jwt = mock(JwtService.class);
        var users = mock(CustomUserDetailsService.class);
        var revocations = mock(AccessTokenRevocations.class);
        var filter = new JwtAuthenticationFilter(jwt, users, revocations);
        for (String method : new String[]{"GET", "HEAD"}) {
            for (String path : new String[]{"/api/health", "/api/health/live", "/actuator/health/liveness"}) {
                var request = new MockHttpServletRequest(method, path);
                request.setServletPath(path);
                request.addHeader("Authorization", "Bearer stale-monitor-token");
                var response = new MockHttpServletResponse();
                var chain = mock(FilterChain.class);
                filter.doFilter(request, response, chain);
                verify(chain).doFilter(request, response);
            }
        }
        verifyNoInteractions(jwt, users, revocations);
    }

    @Test
    void protectedRoutesAndOtherMethodsStillRunAuthentication() throws Exception {
        for (String[] route : new String[][]{{"GET", "/api/users/profile"}, {"POST", "/api/health/live"}}) {
            var jwt = mock(JwtService.class);
            var filter = new JwtAuthenticationFilter(jwt, mock(CustomUserDetailsService.class),
                    mock(AccessTokenRevocations.class));
            var request = new MockHttpServletRequest(route[0], route[1]);
            request.setServletPath(route[1]);
            request.addHeader("Authorization", "Bearer test-token");
            filter.doFilter(request, new MockHttpServletResponse(), mock(FilterChain.class));
            verify(jwt).extractEmail("test-token");
        }
    }
}
