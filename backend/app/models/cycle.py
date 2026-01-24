"""Cycle model."""

from sqlalchemy import Column, Integer, String, Date, DateTime, Enum
from datetime import datetime
from app.core.constants import CycleStatus
from . import Base


class Cycle(Base):
    """Billing cycle."""
    
    __tablename__ = "cycles"
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    status = Column(Enum(CycleStatus), default=CycleStatus.OPEN, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f"<Cycle {self.name}>"
