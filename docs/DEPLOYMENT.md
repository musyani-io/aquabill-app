# Deployment

## Render (Free tier)

- Uses `render.yaml` blueprint.
- Connect repo in Render, enable Blueprint deploys.
- Configure secrets in Render dashboard:
  - `AQUABILL_DATABASE_URL`
  - `AQUABILL_SMS_GATEWAY_URL`
  - `AQUABILL_SMS_API_KEY`
  - `AQUABILL_SUBMISSION_WINDOW_DAYS` (optional override)
- Service runs via `Dockerfile` using `uvicorn app.main:app --host 0.0.0.0 --port 8000`.
- Health check path: `/api/v1/health`.

## Database

- For free-tier Postgres, use an external managed provider (e.g., Neon) and set its URL in `AQUABILL_DATABASE_URL`.
- After deploy, run migrations: `alembic upgrade head` (via Render shell or a one-off job).

## Env/Secrets

- Never commit `.env`. Use Render secret env vars.

## Observability (minimal for prototype)

- Rely on Render logs for now; add structured logging later.
