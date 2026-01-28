"""
Payment model - records received payments tied to meter assignments and clients.
"""

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


class Payment(Base):
    """Customer payment record (applied via FIFO later)"""

    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    client_id = Column(
        Integer,
        ForeignKey("clients.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    meter_assignment_id = Column(
        Integer,
        ForeignKey("meter_assignments.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    cycle_id = Column(
        Integer, ForeignKey("cycles.id", ondelete="SET NULL"), nullable=True, index=True
    )
    amount = Column(Numeric(12, 2), nullable=False)
    reference = Column(String(100), nullable=True, index=True)
    method = Column(
        String(50), nullable=True, comment="cash, mobile money, bank transfer"
    )
    notes = Column(String(500), nullable=True)
    recorded_by = Column(
        String(100), nullable=False, comment="User who recorded the payment"
    )
    received_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    meter_assignment = relationship("MeterAssignment", back_populates="payments")

    __table_args__ = (
        CheckConstraint("amount >= 0", name="ck_payment_amount_non_negative"),
    )
