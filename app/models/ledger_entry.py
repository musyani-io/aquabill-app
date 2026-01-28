"""
LedgerEntry model - records financial movements per meter assignment and cycle.
"""

import enum
from sqlalchemy import (
    Column,
    Integer,
    String,
    Numeric,
    Boolean,
    DateTime,
    ForeignKey,
    CheckConstraint,
    func,
)
from sqlalchemy.orm import relationship
from app.db.base import Base


class LedgerEntryType(str, enum.Enum):
    """Types of ledger entries"""

    CHARGE = "CHARGE"  # Debit for consumption/fees
    ADJUSTMENT = "ADJUSTMENT"  # Manual adjustment (credit or debit via is_credit flag)
    PAYMENT = "PAYMENT"  # Credit from payment
    PENALTY = "PENALTY"  # Debit from penalty


class LedgerEntry(Base):
    """
    Financial ledger per meter assignment and cycle.
    amount is always positive; is_credit indicates sign (credit decreases balance).
    """

    __tablename__ = "ledger_entries"

    id = Column(Integer, primary_key=True, index=True)
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
    entry_type = Column(
        String(20), nullable=False, default=LedgerEntryType.CHARGE.value, index=True
    )
    amount = Column(Numeric(12, 2), nullable=False)
    is_credit = Column(
        Boolean,
        nullable=False,
        default=False,
        comment="True for credits (payments/adjustments)",
    )
    description = Column(String(500), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    created_by = Column(
        String(100), nullable=False, comment="Admin/user who recorded this entry"
    )

    # Relationships
    meter_assignment = relationship("MeterAssignment", back_populates="ledger_entries")
    cycle = relationship("Cycle", back_populates="ledger_entries")

    __table_args__ = (
        CheckConstraint("amount >= 0", name="ck_ledger_amount_non_negative"),
        CheckConstraint(
            "entry_type IN ('CHARGE', 'ADJUSTMENT', 'PAYMENT', 'PENALTY')",
            name="ck_ledger_type_valid",
        ),
    )
