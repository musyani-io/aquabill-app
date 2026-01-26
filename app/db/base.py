from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Base class for SQLAlchemy models."""

    pass


# Import models here so Alembic can discover metadata
from app import models  # noqa: E402,F401
