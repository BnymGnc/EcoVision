# Render / Neon delivery

This file describes configuration read by the code. Preserve existing secret values in the deployment dashboard. Do not paste real credentials into this document or Git.

| Variable | Required | Secret | Example/default | Purpose |
|---|---|---|---|---|
| SPRING_DATASOURCE_URL | yes | treat as sensitive | `jdbc:postgresql://<neon-pooler-host>:5432/<db>?sslmode=require&channelBinding=require` | PostgreSQL JDBC connection; a `postgresql://` URI is not a JDBC URL |
| SPRING_DATASOURCE_USERNAME | yes | yes | existing value / dashboard | database role |
| SPRING_DATASOURCE_PASSWORD | yes | yes | existing value / dashboard | database credential |
| JWT_SECRET | yes | yes | existing sufficiently long value / dashboard | access-token signing; do not rotate accidentally |
| PORT | platform supplied | no | `10000` on Render; local `8080` | binds HTTP on `0.0.0.0` |
| SPRING_PROFILES_ACTIVE | recommended for existing production schema | no | `prod` | uses schema validation instead of Hibernate auto-update |
| JPA_HIBERNATE_DDL_AUTO | development only unless deliberately baselining | no | `update` in default profile | legacy development bootstrap; prod profile explicitly uses `validate` |
| DB_POOL_MAX_SIZE | optional | no | `5` | bounds connection count; import uses a transaction-scoped advisory lock on its own transaction connection |
| DB_POOL_MIN_IDLE | optional | no | `0` | avoids unnecessary idle connections |
| DB_CONNECTION_TIMEOUT_MS | optional | no | `10000` | pool connection wait |
| AI_PROVIDER | optional | no | `gemini` or `local` | actual image inference route |
| GEMINI_API_KEY | required only for cloud inference | yes | dashboard value; example placeholder cannot analyze | Gemini authentication |
| GEMINI_MODEL | optional | no | `gemini-3.6-flash` | configured single vision model; no automatic model chain |
| GEMINI_CONNECT_TIMEOUT_MS | optional | no | `10000` | cloud connect timeout |
| GEMINI_READ_TIMEOUT_MS | optional | no | `60000` | cloud response timeout |
| GEMINI_ON_UNCERTAIN_ENABLED | optional, off by default | no | `false` | explicitly permits Gemini after a low-scoring local result; can consume provider quota |
| ML_ENABLED | optional | no | `false` | loads the packaged local ONNX model only when true |
| ML_MODEL_PATH | optional | no | `ml/waste-mobilenet-v1.onnx` | classpath artifact; package the actual model and matching metadata |
| RVM_IMPORT_DRY_RUN | optional | no | `false`; first inspect with `true` | report-only import versus validated upsert |
| CORS_ALLOWED_ORIGIN_PATTERNS | optional | no | explicit web origins recommended; legacy default `*` | browser-origin policy with Bearer-token auth |
| JWT_EXPIRATION_MS | optional | no | `900000` | access-token lifetime |
| JWT_REFRESH_EXPIRATION_MS | optional | no | `2592000000` | refresh-token lifetime |
| PUBLIC_BASE_URL | set for deployment | no | current HTTPS Render hostname | publicly served media URLs |
| UPLOAD_DIR | optional | no | `/tmp/uploads` | temporary working storage, not persistent user-data storage |
| JAVA_TOOL_OPTIONS | optional | no | `-Xmx128m -XX:MaxMetaspaceSize=112m -XX:MaxDirectMemorySize=16m -XX:ReservedCodeCacheSize=48m -XX:+UseSerialGC -Xss512k` | tested local 512 MB recipe; remeasure actual Render load before enabling local inference |

The code has no paid OpenAI fallback adapter or fallback billing switch to configure. It does not read a hypothetical OpenAI variable. A Gemini API key is not evidence of a free quota on a particular account. Provider 429 remains a distinct provider error.

Current server safety bounds: image size at most 5 MB; image decode at most 4 million pixels; one simultaneous inference per provider; 224×224 local model input; two ONNX intra-op CPU threads; ten-minute/64-entry in-memory Gemini result cache; one provider attempt with no alternate-model fallback. Cloud photos are re-encoded to JPEG without EXIF/GPS metadata and bounded to 1600 pixels on the longest side. Nearby map limit defaults to 500 and caps at 1000, with validated coordinates, bounds, material and point type.

## Deploy sequence

1. Use Render root directory **backend**, Dockerfile **./Dockerfile**, health path **/api/health**. Actuator health is also available at `/actuator/health` without authentication and without internal details.
2. Preserve the Neon environment variables and JWT secret. Confirm the database account can execute migrations. Do not reset tables or delete production data.
3. The default-profile bootstrap is retained for empty development databases. For an existing production database, Flyway V3–V6 add the new columns/tables before JPA; `SPRING_PROFILES_ACTIVE=prod` validates the resulting schema. V6 adds media uploader metadata, scan reward identity/indexes and the access-token revocation table without resetting historical values. Back up and rehearse on staging first; index creation can block writes on large tables. A pre-existing schema not yet matching all historical entities needs a controlled baseline review rather than disabling validation blindly.
4. Set `RVM_IMPORT_DRY_RUN=true` for a preview deployment if desired. The logs report source/inserted/updated/unchanged/invalid counts. Set it to `false` to apply. Every actual run validates the full source and previews before writing. An unchanged source hash skips writes; no point deletion/reconciliation is performed.
5. For cloud analysis, supply a real `GEMINI_API_KEY`. For local analysis, first verify the packaged artifact/metrics and memory, then set `ML_ENABLED=true` and `AI_PROVIDER=local`. Local training never runs during deployment or requests.
6. Rebuild/redeploy Flutter web and rebuild the Android APK. The client now sends versioned answers to `/api/education/complete/{categoryId}`, fetches `/api/media/{id}` with Authorization headers, and uses `/api/map-pins/nearby` and `/api/users/login-history`. Older quiz clients receive 426 rather than unverified XP; label-only scans receive zero XP; private media cannot be fetched without authorization. Deploy both sides in the same release window. The result screen still opens the map directly; eligibility/action APIs remain available but are not extra mandatory steps.

No live deployment, Neon write, video submission or paid resource provisioning is implied by local test results. The supplied production hostname's actual dashboard/autodeploy state must be checked separately.

The importer uses `pg_advisory_xact_lock` inside a Spring JPA transaction, not a session lock held across batch transactions. Every 100 records are flushed and the persistence context cleared. This matches [Neon's transaction pooling constraints](https://neon.com/docs/connect/connection-pooling). For Flyway/administrative migrations, Neon recommends a direct connection; provide an optional `SPRING_FLYWAY_URL`, `SPRING_FLYWAY_USER` and `SPRING_FLYWAY_PASSWORD` through Spring Boot's standard environment binding if your pooled endpoint rejects migration session operations. These are migration-only credentials, not a replacement for the existing datasource variables.

## Existing admin recovery

The normal email/password Login screen is the admin entry route. The seeded account identifier in code is `admin@ecovision.com`; its actual production role/existence has not been queried here. Existing passwords cannot be recovered from BCrypt hashes.

The local tool affects only the explicitly selected existing ADMIN/SUPERUSER. It reads the same three datasource variables from the operator's environment, prompts twice without echoing the password, updates BCrypt and credential version, and revokes refresh tokens. It starts no HTTP reset service.

From `backend` in PowerShell, with environment variables securely available:

```powershell
.\mvnw.cmd -q -DskipTests compile dependency:build-classpath '-Dmdep.outputFile=target/runtime-classpath.txt'
$runtimeClasspath = 'target/classes;' + (Get-Content -Raw target/runtime-classpath.txt).Trim()
java -cp $runtimeClasspath com.ecovision.backend.tools.AdminPasswordReset admin@ecovision.com
```

Linux/macOS use `./mvnw` and `:` instead of `;` in the classpath. Invoke Java directly from an interactive terminal so `Console.readPassword` is available. Do not pass a password in command-line arguments. Migration V4 must be present before the reset. Old access tokens are rejected after the credential-version change.
