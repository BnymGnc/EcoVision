# Task 3 copyable fields

**Product:** EcoVision, a photo-led waste-sorting and return-point guidance app.

**Stack:** Flutter/Dart; Java 17 and Spring Boot 3.3.5; Spring Security/JWT; JPA/Hibernate; Flyway; PostgreSQL/Neon; STOMP/WebSocket; Docker/Render. Monitoring configuration includes Actuator, Prometheus, Grafana and Loki/Promtail.

**AI in the product:** image-based material classification. Packaging acceptance is determined separately by versioned DOA rules and user declarations. Local model results and cloud-call availability must be copied from the actual verification report.

**Data:** dated DOA public point snapshot, normalised by point type and material; per-user progress stored in PostgreSQL. The point database is not visual-classification training data.

**Working/mock distinction:** core HTTP, data persistence, quest and map paths are implemented; training/field/deployment checks and missing carbon categories are disclosed in `verification.md`. Password-reset email delivery is not complete. No external return/payment verification exists.

**Link:** insert the tested public frontend or actual downloadable APK link. The Render backend hostname alone is not an end-user Flutter application link.
