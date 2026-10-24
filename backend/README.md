# EcoVision Backend

Java 17 / Spring Boot 3 modular monolith with PostgreSQL, REST, STOMP, JWT and
server-side Gemini or packaged ONNX image classification. See the root
[README](../README.md) for the complete architecture, setup and known limitations.

## Run

From the repository root, copy `.env.example` to `.env`, set your database and
JWT secrets, choose an AI provider, then run:

```bash
docker compose up -d --build ecovision-backend
```

For Maven instead, export `SPRING_DATASOURCE_URL`,
`SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` and `JWT_SECRET`
in the shell before running `./mvnw spring-boot:run` inside this directory.
Spring Boot does not automatically load the root Compose `.env`.
The old `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` names are not datasource settings.

- `PORT`: HTTP port, defaults to 8080.
- `AI_PROVIDER=local` and `ML_ENABLED=true`: packaged server-side ONNX model.
- `AI_PROVIDER=gemini`: set `GEMINI_API_KEY` and an accessible `GEMINI_MODEL`.
- `SPRING_PROFILES_ACTIVE=prod`: Hibernate validation; first review schema baseline.

## Main APIs

| Route | Purpose |
| --- | --- |
| `GET /api/health` | Public lightweight health string |
| `POST /api/auth/register`, `/login`, `/refresh`, `/logout` | Authentication |
| `GET /api/auth/me` | Current user |
| `POST /api/auth/me/profile-picture` | Multipart profile image |
| `POST /api/scans/analyze` | Multipart image part named `image`; not a JSON label |
| `GET /api/scans` | Own scan history |
| `GET /api/map-pins/nearby` | Bounded/material-filtered DOA point search |
| `GET /api/education/progress` | Own completed module IDs |
| `GET /api/education/quiz/{categoryId}` | Versioned questions/options without answer key |
| `POST /api/education/complete/{categoryId}` | JSON quizVersion + answers; server grades before one-time reward |
| `GET /api/media/{id}` | Dynamic photo/group ACL; authorized byte response, private/no-store |
| `GET /api/quests` | Catalog and progress |
| `POST /api/quests/progress/{progressId}/claim` | Server-validated quest reward |
| `GET /api/groups`, `/api/groups/{groupId}/events` | Groups and their events |
| `GET /api/chat/groups/{groupId}` | Paginated group messages |
| `/ws`, `/topic/groups/{id}` | STOMP connection and subscriptions |
| `GET /api/users/login-history?month=YYYY-MM` | Own monthly login calendar |

Swagger: [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html).
There are compatibility routes beyond this table; see generated OpenAPI and
the security review before removing any route.

V6 is additive: media uploader metadata, scan reward identifiers/indexes and
access-token revocations. Legacy label-only scan records award zero XP.
Same-user/exact-image/day replays return the result with zero extra reward.
See [the migration and old-client plan](../docs/deployment-readiness-tr.md).

## Verification

```bash
./mvnw clean verify
```

See [verification](../docs/verification.md) for explicit local PostgreSQL integration
settings. Never aim integration tests at Neon production. Canonical DOA raw JSON,
manifest, migrations, ONNX model and licences remain packaged; redundant CSV,
GeoJSON, helper scripts and derived exports are retained in the source tree but
excluded from application resources.
