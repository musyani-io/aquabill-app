"""SMS log model."""

from sqlalchemy import Column, Integer, ForeignKey, String, DateTime, Enum
from datetime import datetime
from app.core.constants import SMSStatus
from . import Base


class SmsLog(Base):
    """SMS delivery tracking."""
    
    __tablename__ = "sms_logs"
    
    id = Column(Integer, primary_key=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False)
    phone_number = Column(String(20), nullable=False)
    message = Column(String(1000), nullable=False)
    status = Column(Enum(SMSStatus), default=SMSStatus.PENDING, nullable=False, index=True)
    delivery_attempts = Column(Integer, default=0)
    last_attempt_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<SmsLog {self.phone_number}>"
