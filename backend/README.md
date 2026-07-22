# EcoVision Backend

Spring Boot 3 API for EcoVision with PostgreSQL, JWT auth, scan history,
cleanup events, chat messages, and multipart image uploads.

## Run

```bash
docker compose up -d
mvn spring-boot:run
```

Default database settings are in `src/main/resources/application.yml`.
Override secrets and database credentials with environment variables:

```bash
DB_URL=jdbc:postgresql://localhost:5432/ecovision
DB_USERNAME=postgres
DB_PASSWORD=postgres
JWT_SECRET=replace-with-a-long-random-secret-at-least-32-chars
PUBLIC_BASE_URL=http://localhost:8080
```

## Main Endpoints

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/google`
- `GET /api/auth/me`
- `POST /api/auth/me/profile-picture`
- `GET /api/scans`
- `POST /api/scans`
- `POST /api/scans/analyze` with JSON body `{"detected_class": "plastic waste"}`
- `GET /api/events`
- `POST /api/events`
- `POST /api/events/multipart`
- `GET /api/chat/events/{eventId}`
- `POST /api/chat/events/{eventId}`
