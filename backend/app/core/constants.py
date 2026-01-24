"""Application constants and enums."""

from enum import Enum


class UserRole(str, Enum):
    """User roles."""
    COLLECTOR = "COLLECTOR"
    ADMIN = "ADMIN"


class CycleStatus(str, Enum):
    """Billing cycle statuses."""
    OPEN = "OPEN"
    PENDING_REVIEW = "PENDING_REVIEW"
    APPROVED = "APPROVED"
    CLOSED = "CLOSED"


class ReadingStatus(str, Enum):
    """Reading submission statuses."""
    SUBMITTED = "SUBMITTED"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"


class LedgerEntryType(str, Enum):
    """Ledger entry types."""
    CHARGE = "CHARGE"
    PAYMENT = "PAYMENT"
    PENALTY = "PENALTY"


class SMSStatus(str, Enum):
    """SMS delivery statuses."""
    PENDING = "PENDING"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    FAILED = "FAILED"
    PERMANENTLY_FAILED = "PERMANENTLY_FAILED"


class AlertType(str, Enum):
    """Anomaly alert types."""
    HIGH_CONSUMPTION = "HIGH_CONSUMPTION"
    METER_ROLLBACK = "METER_ROLLBACK"
    METER_ROLLOVER = "METER_ROLLOVER"


class SyncConflictStatus(str, Enum):
    """Sync conflict statuses."""
    DETECTED = "DETECTED"
    RESOLVED = "RESOLVED"
