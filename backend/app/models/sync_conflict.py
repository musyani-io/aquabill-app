"""Sync conflict model."""

from sqlalchemy import Column, Integer, ForeignKey, String, DateTime, Enum
from datetime import datetime
from app.core.constants import SyncConflictStatus
from . import Base


class SyncConflict(Base):
    """Duplicate collector submission tracking."""
    
    __tablename__ = "sync_conflicts"
    
    id = Column(Integer, primary_key=True)
    cycle_id = Column(Integer, ForeignKey("cycles.id"), nullable=False)
    assignment_id = Column(Integer, ForeignKey("meter_assignments.id"), nullable=False)
    reading1_id = Column(Integer, ForeignKey("readings.id"), nullable=False)
    reading2_id = Column(Integer, ForeignKey("readings.id"), nullable=False)
    collector1_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    collector2_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(Enum(SyncConflictStatus), default=SyncConflictStatus.DETECTED, nullable=False, index=True)
    resolution = Column(String(255), nullable=True)
    resolved_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<SyncConflict {self.assignment_id}>"
