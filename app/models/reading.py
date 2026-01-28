"""
Reading model - meter readings with baseline tracking and consumption calculation.
"""

import enum
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import (
    Column,
    Integer,
    Numeric,
    Date,
    DateTime,
    String,
    Boolean,
    ForeignKey,
    CheckConstraint,
    func,
)
from sqlalchemy.orm import relationship
from app.db.base import Base


class ReadingType(str, enum.Enum):
    """Reading classification"""

    BASELINE = "BASELINE"  # First reading for a meter assignment
    NORMAL = "NORMAL"  # Subsequent readings


class Reading(Base):
    """
    Meter reading with precision tracking and baseline enforcement.

    Business Rules:
    - NUMERIC(9,4) precision: up to 99,999.9999 (supports 5-digit meter values + decimals)
    - First reading in a meter_assignment must be type BASELINE
    - BASELINE readings generate no consumption/charges
    - Subsequent readings are NORMAL and calculate consumption from previous NORMAL reading
    - Rollover: if absolute_value < previous normal reading, meter has reset
    - Submission window: must be submitted on or before cycle.target_date
    - Approval flow: submitted → admin approves → consumption calculated
    """

    __tablename__ = "readings"

    id = Column(Integer, primary_key=True, index=True)

    # Foreign keys
    meter_assignment_id = Column(
        Integer,
        ForeignKey("meter_assignments.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    cycle_id = Column(
        Integer,
        ForeignKey("cycles.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    # Reading value with NUMERIC(9,4) precision
    absolute_value = Column(Numeric(9, 4), nullable=False)

    # Reading classification
    type = Column(String(20), nullable=False, default=ReadingType.BASELINE.value)

    # Consumption calculation (NULL for baseline, calculated on approval)
    consumption = Column(
        Numeric(9, 4),
        nullable=True,
        comment="Difference from previous reading. NULL for BASELINE",
    )

    # Rollover detection
    has_rollover = Column(
        Boolean, default=False, comment="True if meter value wrapped/reset"
    )

    # Submission tracking
    submitted_at = Column(DateTime, nullable=False, server_default=func.now())
    submitted_by = Column(
        String(100), nullable=False, comment="User/operator ID who submitted"
    )
    submission_notes = Column(String(500), nullable=True)

    # Approval tracking
    approved = Column(Boolean, default=False, index=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
    approved_by = Column(String(100), nullable=True, comment="Admin ID who approved")
    approval_notes = Column(String(500), nullable=True)

    # Timestamps
    created_at = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # Relationships
    meter_assignment = relationship("MeterAssignment", back_populates="readings")
    cycle = relationship("Cycle", back_populates="readings")

    __table_args__ = (
        CheckConstraint("absolute_value >= 0", name="ck_reading_value_non_negative"),
        CheckConstraint(
            "consumption >= 0 OR consumption IS NULL",
            name="ck_reading_consumption_non_negative",
        ),
        CheckConstraint("type IN ('BASELINE', 'NORMAL')", name="ck_reading_type_valid"),
        CheckConstraint(
            "(approved = true AND approved_at IS NOT NULL AND approved_by IS NOT NULL) OR "
            "(approved = false AND approved_at IS NULL AND approved_by IS NULL)",
            name="ck_reading_approval_consistency",
        ),
    )
