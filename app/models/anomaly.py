"""
Anomaly model - issues detected during billing (logged for audit trail).
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


class AnomalyType(str, enum.Enum):
    """Types of anomalies detected during billing"""

    NEGATIVE_CONSUMPTION = (
        "NEGATIVE_CONSUMPTION"  # Consumption calculated as negative (rollover)
    )
    DOUBLE_SUBMISSION = "DOUBLE_SUBMISSION"  # Multiple readings in same cycle/window
    LATE_SUBMISSION = "LATE_SUBMISSION"  # Reading submitted after cycle.target_date
    MISSING_BASELINE = "MISSING_BASELINE"  # No baseline reading found for meter
    MISSING_READING = "MISSING_READING"  # Expected reading not submitted in cycle
    ROLLOVER_WITHOUT_LIMIT = (
        "ROLLOVER_WITHOUT_LIMIT"  # Rollover detected but meter max unknown
    )


class AnomalyStatus(str, enum.Enum):
    """Anomaly lifecycle states"""

    DETECTED = "DETECTED"  # System found the issue
    ACKNOWLEDGED = "ACKNOWLEDGED"  # Admin reviewed
    RESOLVED = "RESOLVED"  # Admin took action


class Anomaly(Base):
    """
    Audit trail for billing anomalies.

    Purpose: Track issues detected during billing for human review and audit compliance.
    Used by: Reading approval, consumption calculation, cycle processing.
    """

    __tablename__ = "anomalies"

    id = Column(Integer, primary_key=True, index=True)

    # Anomaly type and description
    anomaly_type = Column(String(50), nullable=False)
    description = Column(String(500), nullable=False)
    severity = Column(
        String(20), nullable=False, default="INFO"
    )  # INFO, WARNING, CRITICAL

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
    reading_id = Column(
        Integer, ForeignKey("readings.id", ondelete="SET NULL"), nullable=True
    )

    # Lifecycle
    status = Column(
        String(20), nullable=False, default=AnomalyStatus.DETECTED.value, index=True
    )

    # Detection tracking
    created_at = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    # Acknowledgement tracking
    acknowledged_at = Column(DateTime(timezone=True), nullable=True)
    acknowledged_by = Column(
        String(100), nullable=True, comment="Admin ID who acknowledged"
    )

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
    meter_assignment = relationship("MeterAssignment", back_populates="anomalies")
    cycle = relationship("Cycle", back_populates="anomalies")
    reading = relationship("Reading")

    __table_args__ = (
        CheckConstraint(
            "anomaly_type IN ('NEGATIVE_CONSUMPTION', 'DOUBLE_SUBMISSION', 'LATE_SUBMISSION', "
            "'MISSING_BASELINE', 'MISSING_READING', 'ROLLOVER_WITHOUT_LIMIT')",
            name="ck_anomaly_type_valid",
        ),
        CheckConstraint(
            "severity IN ('INFO', 'WARNING', 'CRITICAL')",
            name="ck_anomaly_severity_valid",
        ),
        CheckConstraint(
            "status IN ('DETECTED', 'ACKNOWLEDGED', 'RESOLVED')",
            name="ck_anomaly_status_valid",
        ),
        CheckConstraint(
            "(status = 'DETECTED' AND acknowledged_at IS NULL AND acknowledged_by IS NULL) OR "
            "(status IN ('ACKNOWLEDGED', 'RESOLVED') AND acknowledged_at IS NOT NULL AND acknowledged_by IS NOT NULL)",
            name="ck_anomaly_ack_consistency",
        ),
        CheckConstraint(
            "(status != 'RESOLVED') OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL)",
            name="ck_anomaly_resolution_consistency",
        ),
    )
