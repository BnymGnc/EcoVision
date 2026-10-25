# Kubernetes Templates

These manifests are an optional cluster deployment, not the live Render/Neon
configuration. Committing them does not apply anything to a cluster or migrate
production data.

- Build/load or publish the backend image, then replace
  `ecovision-backend:latest` with your registry image and immutable version.
- Create `ecovision-secrets` in the target namespace using your secret manager.
  Required keys: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`,
  `JWT_SECRET`, `GEMINI_API_KEY`, and `PUBLIC_BASE_URL`. Never commit real values.
- The PostgreSQL service is `postgres-service:5432`. Its database starts on
  the PVC specified in `postgres-deployment.yaml`; it does not copy Neon data.
  StorageClass availability, database backup and restore need separate setup.
- Configure the model and allowed web origins for your environment before
  deployment. Do not assume the template's model is enabled for your API key.
- Startup/liveness use the lightweight `/api/health/live`; readiness uses
  `/actuator/health/readiness`. Startup permits up to ten minutes before restart.
- A LoadBalancer requires cluster support and can incur provider charges.
  Do not apply these templates merely to run the local app.

The backend template requests two replicas. The existing in-memory STOMP
broker is not shared across replicas: cross-replica chat fan-out and
multi-replica scheduled jobs require an external broker/distributed coordination
before treating this as a production HA deployment. A single-node PostgreSQL
deployment with a PVC is persistent storage, not database high availability.
