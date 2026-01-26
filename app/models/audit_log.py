"""Audit log model for tracking all admin actions - immutable append-only log"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, Enum as SQLEnum
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum


class AuditAction(str, enum.Enum):
    """Types of auditable actions"""

    # Reading management
    READING_APPROVED = "READING_APPROVED"
    READING_REJECTED = "READING_REJECTED"
    READING_EDITED = "READING_EDITED"
    READING_DELETED = "READING_DELETED"

    # Cycle management
    CYCLE_CREATED = "CYCLE_CREATED"
    CYCLE_STATE_CHANGED = "CYCLE_STATE_CHANGED"
    CYCLE_APPROVED = "CYCLE_APPROVED"
    CYCLE_CLOSED = "CYCLE_CLOSED"
    CYCLE_ARCHIVED = "CYCLE_ARCHIVED"

    # Conflict resolution
    CONFLICT_RESOLVED = "CONFLICT_RESOLVED"
    CONFLICT_ASSIGNED = "CONFLICT_ASSIGNED"
    ANOMALY_ACKNOWLEDGED = "ANOMALY_ACKNOWLEDGED"

    # Financial actions
    PENALTY_APPLIED = "PENALTY_APPLIED"
    PENALTY_WAIVED = "PENALTY_WAIVED"
    PAYMENT_RECORDED = "PAYMENT_RECORDED"
    LEDGER_ADJUSTMENT = "LEDGER_ADJUSTMENT"

    # Meter management
    METER_ASSIGNED = "METER_ASSIGNED"
    METER_UNASSIGNED = "METER_UNASSIGNED"
    METER_CREATED = "METER_CREATED"

    # Client management
    CLIENT_CREATED = "CLIENT_CREATED"
    CLIENT_UPDATED = "CLIENT_UPDATED"
    CLIENT_DELETED = "CLIENT_DELETED"

    # System actions
    DATA_EXPORTED = "DATA_EXPORTED"
    BACKUP_CREATED = "BACKUP_CREATED"
    SETTINGS_CHANGED = "SETTINGS_CHANGED"


class AuditLog(Base):
    """
    Immutable audit log for all admin actions.

    CRITICAL: This table is append-only. NO DELETE or UPDATE operations allowed.
    Use for accountability, compliance, and debugging.
    """

    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)

    # Who performed the action
    admin_username = Column(String(100), nullable=False, index=True)
    admin_id = Column(String(100), nullable=True)  # For future user management

    # What action was performed
    action = Column(SQLEnum(AuditAction), nullable=False, index=True)

    # Which entity was affected
    entity_type = Column(
        String(50), nullable=False, index=True
    )  # "reading", "cycle", "penalty", etc.
    entity_id = Column(Integer, nullable=False, index=True)

    # Additional context
    description = Column(Text, nullable=False)  # Human-readable description
    metadata_json = Column(
        "metadata", Text, nullable=True
    )  # JSON string with additional context (rename attr to avoid reserved name)

    # IP address for security auditing
    ip_address = Column(String(45), nullable=True)  # IPv6 max length

    # When it happened
    timestamp = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    def __repr__(self):
        return f"<AuditLog(id={self.id}, action={self.action}, user={self.admin_username}, entity={self.entity_type}:{self.entity_id})>"
