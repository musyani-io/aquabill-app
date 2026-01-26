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

    def allocate_payment_fifo(
        self,
        payment_id: int,
        recorded_by: str,
    ) -> Tuple[List, Optional[str]]:
        """
        Allocate payment to oldest unpaid charges (FIFO) via PAYMENT ledger entries.
        Returns (list of created ledger entries, error).
        """
        from decimal import Decimal, ROUND_HALF_UP
        from app.repositories.ledger_entry import LedgerEntryRepository
        from app.models.ledger_entry import LedgerEntryType

        payment = self.repository.get(payment_id)
        if not payment:
            return [], f"Payment {payment_id} not found"

        if not payment.meter_assignment_id:
            return [], f"Payment {payment_id} has no meter_assignment_id"

        ledger_repo = LedgerEntryRepository(self.db)

        # Get all charges (debits) for this assignment ordered FIFO
        charges = ledger_repo.get_unpaid_charges_by_assignment(
            payment.meter_assignment_id
        )

        # Get all existing payments (credits) for this assignment
        existing_payments = [
            e
            for e in ledger_repo.list_by_assignment(payment.meter_assignment_id)
            if e.entry_type == LedgerEntryType.PAYMENT.value and e.is_credit
        ]

        # Calculate remaining balance on each charge (charge.amount - sum of allocated payments)
        # For simplicity, we'll just create PAYMENT entries; actual allocation tracking
        # would require a payment_allocations table. Here we do simple FIFO credit.

        remaining_payment = Decimal(str(payment.amount))
        created_entries = []

        for charge in charges:
            if remaining_payment <= 0:
                break

            # For now, we create one PAYMENT entry per charge until payment exhausted
            # In production, track allocation separately
            allocation = min(remaining_payment, Decimal(str(charge.amount)))

            entry = ledger_repo.create(
                meter_assignment_id=payment.meter_assignment_id,
                cycle_id=charge.cycle_id,  # tie to same cycle as charge
                entry_type=LedgerEntryType.PAYMENT,
                amount=allocation.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP),
                is_credit=True,
                description=f"Payment allocation (payment_id={payment_id}, charge_id={charge.id})",
                created_by=recorded_by,
            )
            created_entries.append(entry)
            remaining_payment -= allocation

        # If payment exceeds charges, remaining is credit balance
        credit_balance = remaining_payment

        return created_entries, (
            None
            if remaining_payment == 0
            else f"Credit balance remaining: {credit_balance}"
        )
