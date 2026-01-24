"""Reading model."""

from sqlalchemy import Column, Integer, ForeignKey, Float, Boolean, DateTime, Enum
from datetime import datetime
from app.core.constants import ReadingStatus
from . import Base


class Reading(Base):
    """Meter reading submission."""
    
    __tablename__ = "readings"
    
    id = Column(Integer, primary_key=True)
    cycle_id = Column(Integer, ForeignKey("cycles.id"), nullable=False)
    assignment_id = Column(Integer, ForeignKey("meter_assignments.id"), nullable=False)
    collector_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reading_value = Column(Float, nullable=False)
    is_baseline = Column(Boolean, default=False)
    submitted_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    approved_at = Column(DateTime, nullable=True)
    approved_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    status = Column(Enum(ReadingStatus), default=ReadingStatus.SUBMITTED, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<Reading {self.id}>"
