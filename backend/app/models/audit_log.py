"""Audit log model."""

from sqlalchemy import Column, Integer, ForeignKey, String, DateTime
from datetime import datetime
from . import Base


class AuditLog(Base):
    """Immutable admin action log."""
    
    __tablename__ = "audit_logs"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    action = Column(String(100), nullable=False)
    resource_type = Column(String(50), nullable=False)
    resource_id = Column(Integer, nullable=False)
    changes = Column(String(1000), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<AuditLog {self.action}>"
