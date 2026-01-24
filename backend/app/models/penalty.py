"""Penalty model."""

from sqlalchemy import Column, Integer, ForeignKey, String, DateTime, Boolean
from datetime import datetime
from . import Base


class Penalty(Base):
    """Manual penalty record."""
    
    __tablename__ = "penalties"
    
    id = Column(Integer, primary_key=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False)
    amount = Column(Integer, nullable=False)  # Amount in TZS
    reason = Column(String(255), nullable=False)
    applied_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_resolved = Column(Boolean, default=False, index=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<Penalty {self.amount}>"
