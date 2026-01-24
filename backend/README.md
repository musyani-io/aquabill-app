# AquaBill Backend Setup

## Installation

### Prerequisites

- Python 3.11+
- PostgreSQL
- Redis

### Local Development Setup

1. **Create virtual environment:**

   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**

   ```bash
   pip install -r requirements.txt
   # or with Poetry:
   poetry install
   ```

3. **Set up environment variables:**

   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Run database migrations:**

   ```bash
   alembic upgrade head
   ```

5. **Create demo admin user:**

   ```bash
   python scripts/seed_demo_data.py
   ```

6. **Start the server:**

   ```bash
   uvicorn app.main:app --reload
   ```

The API will be available at `http://localhost:8000`
API documentation: `http://localhost:8000/docs`

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app

# Run specific test file
pytest app/tests/unit/test_precision.py
```

## Project Structure

- `app/main.py` - FastAPI application entry point
- `app/core/` - Core utilities (config, security, DB, constants)
- `app/models/` - SQLAlchemy database models
- `app/schemas/` - Pydantic validation schemas
- `app/api/v1/` - API endpoints
- `app/services/` - Business logic layer
- `app/integrations/` - External service integrations
- `app/tasks/` - Celery background tasks
- `app/utils/` - Utility functions
- `app/tests/` - Test suite
- `alembic/` - Database migrations
