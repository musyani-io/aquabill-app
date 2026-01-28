"""
Conflict model - discrepancies requiring admin resolution.
"""

import enum
from datetime import datetime
from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    ForeignKey,
    CheckConstraint,
    func,
)
from sqlalchemy.orm import relationship
from app.db.base import Base


class ConflictType(str, enum.Enum):
    """Types of conflicts requiring resolution"""

    READING_ROLLOVER = (
        "READING_ROLLOVER"  # Meter rollover detected, needs limit confirmation
    )
    MISSING_BASELINE = (
        "MISSING_BASELINE"  # Baseline reading missing for active assignment
    )
    DUPLICATE_READING = "DUPLICATE_READING"  # Multiple readings in same cycle window
    OUT_OF_WINDOW = "OUT_OF_WINDOW"  # Reading submitted after target_date


class ConflictStatus(str, enum.Enum):
    """Conflict lifecycle states"""

    OPEN = "OPEN"  # Needs admin action
    ASSIGNED_TO_ADMIN = "ASSIGNED_TO_ADMIN"  # Owner assigned
    RESOLVED = "RESOLVED"  # Admin took action
    ARCHIVED = "ARCHIVED"  # Historical, no further action


class ConflictSeverity(str, enum.Enum):
    """Conflict impact level"""

    LOW = "LOW"  # Can be deferred
    MEDIUM = "MEDIUM"  # Should resolve soon
    HIGH = "HIGH"  # Must resolve before billing


class Conflict(Base):
    """
    Conflict tracking for issues that require human intervention.

    Purpose: Track discrepancies that block billing or require admin decision.
    Examples: Rollover without meter limit, missing baseline for assignment, duplicate readings.
    Enforces: "Human authority over penalties" principle from spec.
    """

    __tablename__ = "conflicts"

    id = Column(Integer, primary_key=True, index=True)

    # Conflict type and description
    conflict_type = Column(String(50), nullable=False)
    description = Column(String(500), nullable=False)
    severity = Column(String(20), nullable=False, default=ConflictSeverity.MEDIUM.value)

    # Foreign keys
    meter_assignment_id = Column(
        Integer,
        ForeignKey("meter_assignments.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    cycle_id = Column(
        Integer, ForeignKey("cycles.id", ondelete="SET NULL"), nullable=True
    )
    reading_id = Column(
        Integer, ForeignKey("readings.id", ondelete="SET NULL"), nullable=True
    )

    # Lifecycle
    status = Column(
        String(20), nullable=False, default=ConflictStatus.OPEN.value, index=True
    )

    # Detection
    created_at = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    # Assignment tracking
    assigned_to = Column(
        String(100), nullable=True, comment="Admin email/ID assigned to resolve"
    )
    assigned_at = Column(DateTime(timezone=True), nullable=True)

    # Resolution tracking
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    resolved_by = Column(String(100), nullable=True, comment="Admin ID who resolved")
    resolution_notes = Column(String(500), nullable=True)

    # Timestamps
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # Relationships
    meter_assignment = relationship("MeterAssignment", back_populates="conflicts")
    cycle = relationship("Cycle", back_populates="conflicts")
    reading = relationship("Reading")

    __table_args__ = (
        CheckConstraint(
            "conflict_type IN ('READING_ROLLOVER', 'MISSING_BASELINE', 'DUPLICATE_READING', 'OUT_OF_WINDOW')",
            name="ck_conflict_type_valid",
        ),
        CheckConstraint(
            "severity IN ('LOW', 'MEDIUM', 'HIGH')", name="ck_conflict_severity_valid"
        ),
        CheckConstraint(
            "status IN ('OPEN', 'ASSIGNED_TO_ADMIN', 'RESOLVED', 'ARCHIVED')",
            name="ck_conflict_status_valid",
        ),
        CheckConstraint(
            "(status = 'OPEN' AND assigned_to IS NULL AND assigned_at IS NULL) OR "
            "(status IN ('ASSIGNED_TO_ADMIN', 'RESOLVED', 'ARCHIVED') AND assigned_to IS NOT NULL AND assigned_at IS NOT NULL)",
            name="ck_conflict_assignment_consistency",
        ),
        CheckConstraint(
            "(status != 'RESOLVED') OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL)",
            name="ck_conflict_resolution_consistency",
        ),
    )
