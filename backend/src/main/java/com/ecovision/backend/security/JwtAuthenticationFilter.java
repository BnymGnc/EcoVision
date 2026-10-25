package com.ecovision.backend.security;

import com.ecovision.backend.model.AppUser;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import io.jsonwebtoken.JwtException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtService jwtService;
    private final CustomUserDetailsService userDetailsService;
    private final AccessTokenRevocations revocations;

    public JwtAuthenticationFilter(
            JwtService jwtService,
            CustomUserDetailsService userDetailsService,
            AccessTokenRevocations revocations
    ) {
        this.jwtService = jwtService;
        this.userDetailsService = userDetailsService;
        this.revocations = revocations;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        boolean probe = "GET".equals(request.getMethod()) || "HEAD".equals(request.getMethod());
        // A stray/old Authorization header must not turn liveness into a DB lookup.
        return probe && java.util.Set.of("/api/health", "/api/health/live",
                "/actuator/health/liveness").contains(request.getServletPath());
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        try {
            String token = authHeader.substring(7);
            String email = jwtService.extractEmail(token);
            if (email != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                AppUser user = (AppUser) userDetailsService.loadUserByUsername(email);
                if (jwtService.isValid(token, user) && user.isAccountNonLocked() && user.isEnabled() && !revocations.revoked(token)) {
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(
                                    user,
                                    null,
                                    user.getAuthorities()
                            );
                    authentication.setDetails(
                            new WebAuthenticationDetailsSource().buildDetails(request)
                    );
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            }
        } catch (JwtException | IllegalArgumentException exception) {
            SecurityContextHolder.clearContext();
        }

        filterChain.doFilter(request, response);
    }
}
