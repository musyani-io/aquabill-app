"""Ledger entry model."""

from sqlalchemy import Column, Integer, ForeignKey, String, DateTime, Enum
from datetime import datetime
from app.core.constants import LedgerEntryType
from . import Base


class LedgerEntry(Base):
    """Financial transaction ledger."""
    
    __tablename__ = "ledger_entries"
    
    id = Column(Integer, primary_key=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False, index=True)
    reading_id = Column(Integer, ForeignKey("readings.id"), nullable=True)
    amount = Column(Integer, nullable=False)  # Amount in TZS
    type = Column(Enum(LedgerEntryType), nullable=False, index=True)
    description = Column(String(255), nullable=True)
    balance_before = Column(Integer, nullable=False)
    balance_after = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    def __repr__(self):
        return f"<LedgerEntry {self.type} {self.amount}>"
