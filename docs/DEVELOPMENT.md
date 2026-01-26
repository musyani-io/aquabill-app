# Development

## Environment

- Copy env template and fill values:
  - `cp .env.example .env`
  - Set `AQUABILL_DATABASE_URL` to your Postgres connection string.
  - Adjust `AQUABILL_SUBMISSION_WINDOW_DAYS` if needed (default 5).
- Python: 3.11. Create venv and install deps:
  - `python -m venv .venv && . .venv/bin/activate`
  - `pip install -r requirements.txt`

## Running

- Start API: `uvicorn app.main:app --host 0.0.0.0 --port 8000`
- Health: `http://localhost:8000/api/v1/health`

## Migrations

- Alembic config uses `AQUABILL_DATABASE_URL`.
- Create new migration after models change: `alembic revision --autogenerate -m "msg"`
- Apply migrations: `alembic upgrade head`

## Testing

- Run tests: `pytest`
- Add new tests under `tests/` (e.g., integration for cycles, conflicts, SMS retries).

## Project Layout

- `app/` FastAPI app (api, core, db, domain, models, schemas, services, repositories)
- `migrations/` Alembic scripts
- `tests/` Pytest suite
- `render.yaml` Render blueprint (free tier)
- `Dockerfile` Container entry (uvicorn)
