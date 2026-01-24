"""Alert model."""

from sqlalchemy import Column, Integer, ForeignKey, String, DateTime, Boolean, Enum
from datetime import datetime
from app.core.constants import AlertType
from . import Base


class Alert(Base):
    """Anomaly detection alert."""
    
    __tablename__ = "alerts"
    
    id = Column(Integer, primary_key=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False)
    reading_id = Column(Integer, ForeignKey("readings.id"), nullable=True)
    alert_type = Column(Enum(AlertType), nullable=False, index=True)
    description = Column(String(255), nullable=False)
    is_acknowledged = Column(Boolean, default=False, index=True)
    acknowledged_at = Column(DateTime, nullable=True)
    acknowledged_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<Alert {self.alert_type}>"
