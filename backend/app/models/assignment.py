"""Meter assignment model."""

from sqlalchemy import Column, Integer, ForeignKey, Date, Boolean, DateTime
from datetime import datetime
from . import Base


class MeterAssignment(Base):
    """Links a meter to a client for a specific period."""
    
    __tablename__ = "meter_assignments"
    
    id = Column(Integer, primary_key=True)
    meter_id = Column(Integer, ForeignKey("meters.id"), nullable=False, index=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False, index=True)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<MeterAssignment meter={self.meter_id} client={self.client_id}>"
