"""
Ledger service - business logic for ledger entries.
"""
from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.ledger_entry import LedgerEntry, LedgerEntryType
from app.repositories.ledger_entry import LedgerEntryRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.cycle import CycleRepository


class LedgerService:
    """Service layer for ledger entries with basic validation"""

    def __init__(self, db: Session):
        self.db = db
        self.repository = LedgerEntryRepository(db)
        self.assignment_repository = MeterAssignmentRepository(db)
        self.cycle_repository = CycleRepository(db)

    def create_entry(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        entry_type: LedgerEntryType,
        amount: Decimal,
        is_credit: bool,
        description: str,
        created_by: str,
    ) -> Tuple[Optional[LedgerEntry], Optional[str]]:
        """
        Create ledger entry after validating meter assignment and cycle.
        """
        assignment = self.assignment_repository.get(meter_assignment_id)
        if not assignment:
            return None, f"Meter assignment {meter_assignment_id} not found"

        cycle = self.cycle_repository.get(cycle_id)
        if not cycle:
            return None, f"Cycle {cycle_id} not found"

        entry = self.repository.create(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            entry_type=entry_type,
            amount=amount,
            is_credit=is_credit,
            description=description,
            created_by=created_by,
        )
        return entry, None

    def get_entry(self, entry_id: int) -> Optional[LedgerEntry]:
        return self.repository.get(entry_id)

    def list_entries(self, skip: int = 0, limit: int = 100) -> List[LedgerEntry]:
        return self.repository.list(skip, limit)

    def list_entries_by_assignment(self, meter_assignment_id: int) -> List[LedgerEntry]:
        return self.repository.list_by_assignment(meter_assignment_id)

    def list_entries_by_cycle(self, cycle_id: int) -> List[LedgerEntry]:
        return self.repository.list_by_cycle(cycle_id)

    def compute_balance(
        self,
        meter_assignment_id: int,
    ) -> Tuple[dict, Optional[str]]:
        """
        Compute net balance for a meter assignment.
        Balance = sum(debits) - sum(credits)
        Returns (balance_summary, error).
        """
        from decimal import Decimal

        assignment = self.assignment_repository.get(meter_assignment_id)
        if not assignment:
            return {}, f"Meter assignment {meter_assignment_id} not found"

        entries = self.repository.list_by_assignment(meter_assignment_id)

        total_debits = Decimal("0.00")
        total_credits = Decimal("0.00")

        charges = Decimal("0.00")
        penalties = Decimal("0.00")
        payments = Decimal("0.00")
        adjustments_debit = Decimal("0.00")
        adjustments_credit = Decimal("0.00")

        for entry in entries:
            amount = Decimal(str(entry.amount))
            if entry.is_credit:
                total_credits += amount
                if entry.entry_type == LedgerEntryType.PAYMENT.value:
                    payments += amount
                elif entry.entry_type == LedgerEntryType.ADJUSTMENT.value:
                    adjustments_credit += amount
            else:
                total_debits += amount
                if entry.entry_type == LedgerEntryType.CHARGE.value:
                    charges += amount
                elif entry.entry_type == LedgerEntryType.PENALTY.value:
                    penalties += amount
                elif entry.entry_type == LedgerEntryType.ADJUSTMENT.value:
                    adjustments_debit += amount

        net_balance = total_debits - total_credits

        return {
            "meter_assignment_id": meter_assignment_id,
            "total_debits": float(total_debits),
            "total_credits": float(total_credits),
            "net_balance": float(net_balance),
            "breakdown": {
                "charges": float(charges),
                "penalties": float(penalties),
                "payments": float(payments),
                "adjustments_debit": float(adjustments_debit),
                "adjustments_credit": float(adjustments_credit),
            }
        }, None
