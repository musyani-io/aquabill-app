"""
Cycle model - represents billing periods with state machine.
"""

import enum
from datetime import date
from sqlalchemy import Column, Integer, Date, String, CheckConstraint, func
from sqlalchemy.orm import relationship
from app.db.base import Base


class CycleStatus(str, enum.Enum):
    """Cycle lifecycle states"""

    OPEN = "OPEN"  # Accepting reading submissions
    PENDING_REVIEW = "PENDING_REVIEW"  # Window closed, awaiting admin review
    APPROVED = "APPROVED"  # Admin approved, charges generated
    CLOSED = "CLOSED"  # Billing complete, payments processed
    ARCHIVED = "ARCHIVED"  # Historical data (≥36 months old)


class Cycle(Base):
    """
    Billing cycle with temporal constraints.

    Business Rules:
    - Cycles must not overlap or have gaps
    - start_date < end_date
    - target_date is the deadline for reading submissions
    - State machine: OPEN → PENDING_REVIEW → APPROVED → CLOSED → ARCHIVED
    - Only one OPEN cycle allowed at a time (enforced at service layer)
    """

    __tablename__ = "cycles"

    id = Column(Integer, primary_key=True, index=True)
    start_date = Column(Date, nullable=False, index=True)
    end_date = Column(Date, nullable=False, index=True)
    target_date = Column(
        Date, nullable=False, comment="Deadline for reading submissions (final/effective date)"
    )
    proposed_target_date = Column(
        Date,
        nullable=True,
        comment="Original proposed target date before admin override (NULL if no override)"
    )
    overridden_by = Column(
        String(100),
        nullable=True,
        comment="Admin username who overrode the target date (NULL if no override)"
    )
    override_reason = Column(
        String(500),
        nullable=True,
        comment="Reason for target date override (NULL if no override)"
    )
    status = Column(
        String(20), nullable=False, default=CycleStatus.OPEN.value, index=True
    )

    # Timestamps
    created_at = Column(Date, nullable=False, server_default=func.current_date())
    updated_at = Column(
        Date,
        nullable=False,
        server_default=func.current_date(),
        onupdate=func.current_date(),
    )

    # Relationships
    readings = relationship(
        "Reading", back_populates="cycle", cascade="all, delete-orphan"
    )
    anomalies = relationship(
        "Anomaly", back_populates="cycle", cascade="all, delete-orphan"
    )
    conflicts = relationship(
        "Conflict", back_populates="cycle", cascade="all, delete-orphan"
    )
    ledger_entries = relationship(
        "LedgerEntry", back_populates="cycle", cascade="all, delete-orphan"
    )
    penalties = relationship(
        "Penalty", back_populates="cycle", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint("start_date < end_date", name="ck_cycle_dates_valid"),
        CheckConstraint(
            "target_date >= start_date", name="ck_cycle_target_after_start"
        ),
        CheckConstraint("target_date <= end_date", name="ck_cycle_target_before_end"),
        CheckConstraint(
            "status IN ('OPEN', 'PENDING_REVIEW', 'APPROVED', 'CLOSED', 'ARCHIVED')",
            name="ck_cycle_status_valid",
        ),
    )
