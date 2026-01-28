"""
Penalty model - manual penalties with notes and waiver support.
"""

import enum
from sqlalchemy import (
    Column,
    Integer,
    String,
    Numeric,
    DateTime,
    ForeignKey,
    CheckConstraint,
    func,
)
from sqlalchemy.orm import relationship
from app.db.base import Base


class PenaltyStatus(str, enum.Enum):
    """Penalty lifecycle"""

    APPLIED = "APPLIED"
    WAIVED = "WAIVED"


class Penalty(Base):
    """Manual penalties tied to meter assignments and cycles"""

    __tablename__ = "penalties"

    id = Column(Integer, primary_key=True, index=True)
    meter_assignment_id = Column(
        Integer,
        ForeignKey("meter_assignments.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    cycle_id = Column(
        Integer, ForeignKey("cycles.id", ondelete="SET NULL"), nullable=True, index=True
    )
    amount = Column(Numeric(12, 2), nullable=False)
    reason = Column(String(200), nullable=False)
    notes = Column(String(500), nullable=True)
    status = Column(
        String(20), nullable=False, default=PenaltyStatus.APPLIED.value, index=True
    )
    imposed_by = Column(
        String(100), nullable=False, comment="Admin who imposed the penalty"
    )
    imposed_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    waived_at = Column(DateTime(timezone=True), nullable=True)
    waived_by = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    meter_assignment = relationship("MeterAssignment", back_populates="penalties")
    cycle = relationship("Cycle", back_populates="penalties")

    __table_args__ = (
        CheckConstraint("amount >= 0", name="ck_penalty_amount_non_negative"),
        CheckConstraint(
            "status IN ('APPLIED', 'WAIVED')", name="ck_penalty_status_valid"
        ),
        CheckConstraint(
            "(status = 'APPLIED' AND waived_at IS NULL AND waived_by IS NULL) OR "
            "(status = 'WAIVED' AND waived_at IS NOT NULL AND waived_by IS NOT NULL)",
            name="ck_penalty_waive_consistency",
        ),
    )
