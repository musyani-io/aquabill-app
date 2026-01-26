# AQUABILL-APP

AquaBill is an offline-capable water meter reading and billing management system for small-medium water utilities. It digitizes meter collection, consumption-based billing, ledger-driven payments, and arrears tracking. The system supports offline field data capture, admin-controlled approvals, penalties, and SMS notifications.

## Quick Start

### Local

1. Create a virtualenv and install deps:

```
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

2. Run the API:

```
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

3. Health check: http://localhost:8000/api/v1/health

### Render (Free)

- This repo includes render.yaml for a simple web service on the Free plan.
- Configure environment variables as secrets on Render:
  - AQUABILL_DATABASE_URL
  - AQUABILL_SMS_GATEWAY_URL
  - AQUABILL_SMS_API_KEY
  - AQUABILL_SUBMISSION_WINDOW_DAYS
- Deploy from the repository; service runs uvicorn via the Dockerfile.

## Next

See guideline.md and TODOs.md for the implementation plan and sequencing.
