"""Payment model."""

from sqlalchemy import Column, Integer, ForeignKey, Date, DateTime
from datetime import datetime
from . import Base


class Payment(Base):
    """Client payment record."""
    
    __tablename__ = "payments"
    
    id = Column(Integer, primary_key=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False)
    amount = Column(Integer, nullable=False)  # Amount in TZS
    payment_date = Column(Date, default=datetime.utcnow, nullable=False)
    recorded_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<Payment {self.amount}>"
