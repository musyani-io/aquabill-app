"""SQLAlchemy models package."""

from sqlalchemy.orm import declarative_base

Base = declarative_base()

# Import all models to make them available
from .user import User
from .client import Client
from .meter import Meter
from .assignment import MeterAssignment
from .cycle import Cycle
from .reading import Reading
from .ledger import LedgerEntry
from .payment import Payment
from .penalty import Penalty
from .alert import Alert
from .sms import SmsLog
from .audit_log import AuditLog
from .sync_conflict import SyncConflict

__all__ = [
    "Base",
    "User",
    "Client",
    "Meter",
    "MeterAssignment",
    "Cycle",
    "Reading",
    "LedgerEntry",
    "Payment",
    "Penalty",
    "Alert",
    "SmsLog",
    "AuditLog",
    "SyncConflict",
]
