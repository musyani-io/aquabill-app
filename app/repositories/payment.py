"""
Payment repository - data access for payments.
"""

from typing import List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from app.models.payment import Payment


class PaymentRepository:
    """Repository for payments"""

    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        client_id: int,
        meter_assignment_id: Optional[int],
        cycle_id: Optional[int],
        amount,
        reference: Optional[str],
        method: Optional[str],
        notes: Optional[str],
        recorded_by: str,
    ) -> Payment:
        payment = Payment(
            client_id=client_id,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            amount=amount,
            reference=reference,
            method=method,
            notes=notes,
            recorded_by=recorded_by,
        )
        self.db.add(payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def get(self, payment_id: int) -> Optional[Payment]:
        return self.db.query(Payment).filter(Payment.id == payment_id).first()

    def list(self, skip: int = 0, limit: int = 100) -> List[Payment]:
        return (
            self.db.query(Payment)
            .order_by(desc(Payment.received_at))
            .offset(skip)
            .limit(limit)
            .all()
        )

    def list_by_client(self, client_id: int) -> List[Payment]:
        return (
            self.db.query(Payment)
            .filter(Payment.client_id == client_id)
            .order_by(desc(Payment.received_at))
            .all()
        )

    def list_by_assignment(self, meter_assignment_id: int) -> List[Payment]:
        return (
            self.db.query(Payment)
            .filter(Payment.meter_assignment_id == meter_assignment_id)
            .order_by(desc(Payment.received_at))
            .all()
        )
