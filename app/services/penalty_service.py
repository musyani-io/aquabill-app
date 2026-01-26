"""
Penalty service - business logic for manual penalties.
"""

from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.penalty import Penalty, PenaltyStatus
from app.models.ledger_entry import LedgerEntry
from app.repositories.penalty import PenaltyRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.cycle import CycleRepository


class PenaltyService:
    """Service layer for penalties with validation"""

    def __init__(self, db: Session):
        self.db = db
        self.repository = PenaltyRepository(db)
        self.assignment_repository = MeterAssignmentRepository(db)
        self.cycle_repository = CycleRepository(db)

    def create_penalty(
        self,
        meter_assignment_id: int,
        cycle_id: Optional[int],
        amount: Decimal,
        reason: str,
        notes: Optional[str],
        imposed_by: str,
    ) -> Tuple[Optional[Penalty], Optional[str]]:
        """Create a penalty after validating references"""
        assignment = self.assignment_repository.get(meter_assignment_id)
        if not assignment:
            return None, f"Meter assignment {meter_assignment_id} not found"

        if cycle_id:
            cycle = self.cycle_repository.get(cycle_id)
            if not cycle:
                return None, f"Cycle {cycle_id} not found"

        penalty = self.repository.create(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            amount=amount,
            reason=reason,
            notes=notes,
            imposed_by=imposed_by,
        )
        return penalty, None

    def get_penalty(self, penalty_id: int) -> Optional[Penalty]:
        return self.repository.get(penalty_id)

    def list_penalties(self, skip: int = 0, limit: int = 100) -> List[Penalty]:
        return self.repository.list(skip, limit)

    def list_penalties_by_assignment(self, meter_assignment_id: int) -> List[Penalty]:
        return self.repository.list_by_assignment(meter_assignment_id)

    def waive_penalty(
        self,
        penalty_id: int,
        waived_by: str,
        notes: Optional[str] = None,
    ) -> Tuple[Optional[Penalty], Optional[str]]:
        """Waive a penalty (manual override)"""
        penalty = self.repository.get(penalty_id)
        if not penalty:
            return None, f"Penalty {penalty_id} not found"

        if penalty.status == PenaltyStatus.WAIVED.value:
            return None, f"Penalty {penalty_id} already waived"

        updated = self.repository.waive(penalty_id, waived_by, notes)
        return updated, None

    def apply_penalty_to_ledger(
        self,
        penalty_id: int,
        created_by: str,
    ) -> Tuple[Optional[LedgerEntry], Optional[str]]:
        """
        Apply an APPLIED penalty to the ledger as a PENALTY entry.
        Idempotent: skips if already applied.
        Returns (ledger_entry, error).
        """
        from decimal import Decimal, ROUND_HALF_UP
        from app.repositories.ledger_entry import LedgerEntryRepository
        from app.models.ledger_entry import LedgerEntryType

        penalty = self.repository.get(penalty_id)
        if not penalty:
            return None, f"Penalty {penalty_id} not found"

        if penalty.status != PenaltyStatus.APPLIED.value:
            return (
                None,
                f"Penalty {penalty_id} is not APPLIED (status={penalty.status})",
            )

        ledger_repo = LedgerEntryRepository(self.db)

        # Check idempotency
        if ledger_repo.check_penalty_applied(penalty_id):
            return None, f"Penalty {penalty_id} already applied to ledger"

        # Create PENALTY ledger entry
        entry = ledger_repo.create(
            meter_assignment_id=penalty.meter_assignment_id,
            cycle_id=penalty.cycle_id,
            entry_type=LedgerEntryType.PENALTY,
            amount=Decimal(str(penalty.amount)).quantize(
                Decimal("0.01"), rounding=ROUND_HALF_UP
            ),
            is_credit=False,  # penalty is a debit
            description=f"{penalty.reason} (penalty_id={penalty_id})",
            created_by=created_by,
        )
        return entry, None
