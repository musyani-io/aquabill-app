"""
Payment service - business logic for payments.
"""
from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.payment import Payment
from app.repositories.payment import PaymentRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.cycle import CycleRepository


class PaymentService:
    """Service layer for payments with basic validation"""

    def __init__(self, db: Session):
        self.db = db
        self.repository = PaymentRepository(db)
        self.assignment_repository = MeterAssignmentRepository(db)
        self.cycle_repository = CycleRepository(db)

    def create_payment(
        self,
        meter_assignment_id: int,
        cycle_id: Optional[int],
        amount: Decimal,
        reference: Optional[str],
        method: Optional[str],
        notes: Optional[str],
        recorded_by: str,
    ) -> Tuple[Optional[Payment], Optional[str]]:
        """
        Create payment; ties client_id from meter assignment to avoid mismatch.
        """
        assignment = self.assignment_repository.get(meter_assignment_id)
        if not assignment:
            return None, f"Meter assignment {meter_assignment_id} not found"

        if cycle_id:
            cycle = self.cycle_repository.get(cycle_id)
            if not cycle:
                return None, f"Cycle {cycle_id} not found"

        payment = self.repository.create(
            client_id=assignment.client_id,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            amount=amount,
            reference=reference,
            method=method,
            notes=notes,
            recorded_by=recorded_by,
        )
        return payment, None

    def get_payment(self, payment_id: int) -> Optional[Payment]:
        return self.repository.get(payment_id)

    def list_payments(self, skip: int = 0, limit: int = 100) -> List[Payment]:
        return self.repository.list(skip, limit)

    def list_payments_by_assignment(self, meter_assignment_id: int) -> List[Payment]:
        return self.repository.list_by_assignment(meter_assignment_id)

    def list_payments_by_client(self, client_id: int) -> List[Payment]:
        return self.repository.list_by_client(client_id)
