"""
Ledger entry repository - data access for financial ledger.
"""
from typing import List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from app.models.ledger_entry import LedgerEntry, LedgerEntryType


class LedgerEntryRepository:
    """Repository for ledger entries"""

    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        entry_type: LedgerEntryType,
        amount,
        is_credit: bool,
        description: str,
        created_by: str,
    ) -> LedgerEntry:
        entry = LedgerEntry(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            entry_type=entry_type.value,
            amount=amount,
            is_credit=is_credit,
            description=description,
            created_by=created_by,
        )
        self.db.add(entry)
        self.db.commit()
        self.db.refresh(entry)
        return entry

    def get(self, entry_id: int) -> Optional[LedgerEntry]:
        return self.db.query(LedgerEntry).filter(LedgerEntry.id == entry_id).first()

    def list(self, skip: int = 0, limit: int = 100) -> List[LedgerEntry]:
        return self.db.query(LedgerEntry).order_by(desc(LedgerEntry.created_at)).offset(skip).limit(limit).all()

    def list_by_assignment(self, meter_assignment_id: int) -> List[LedgerEntry]:
        return (
            self.db.query(LedgerEntry)
            .filter(LedgerEntry.meter_assignment_id == meter_assignment_id)
            .order_by(desc(LedgerEntry.created_at))
            .all()
        )

    def list_by_cycle(self, cycle_id: int) -> List[LedgerEntry]:
        return (
            self.db.query(LedgerEntry)
            .filter(LedgerEntry.cycle_id == cycle_id)
            .order_by(desc(LedgerEntry.created_at))
            .all()
        )

    def get_charge_for_assignment_cycle(self, meter_assignment_id: int, cycle_id: int) -> Optional[LedgerEntry]:
        """Return existing CHARGE entry for assignment+cycle if any (idempotency)."""
        return (
            self.db.query(LedgerEntry)
            .filter(
                LedgerEntry.meter_assignment_id == meter_assignment_id,
                LedgerEntry.cycle_id == cycle_id,
                LedgerEntry.entry_type == LedgerEntryType.CHARGE.value
            )
            .first()
        )
