from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint, func

from app.db.base import Base


class Meter(Base):
    __tablename__ = "meters"
    __table_args__ = (
        UniqueConstraint("serial_number", name="uq_meters_serial_number"),
    )

    id = Column(Integer, primary_key=True, index=True)
    serial_number = Column(String(50), nullable=False, unique=True)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
