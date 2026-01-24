"""Meter model."""

from sqlalchemy import Column, Integer, String, Float, DateTime
from datetime import datetime
from . import Base


class Meter(Base):
    """Physical meter device."""
    
    __tablename__ = "meters"
    
    id = Column(Integer, primary_key=True)
    serial_number = Column(String(50), unique=True, nullable=False, index=True)
    max_reading = Column(Float, default=99999.9999, nullable=False)
    alert_threshold = Column(Float, default=90000.0, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<Meter {self.serial_number}>"
