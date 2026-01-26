"""
Penalty repository - data access for penalties.
"""

from datetime import datetime
from typing import List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from app.models.penalty import Penalty, PenaltyStatus


class PenaltyRepository:
    """Repository for penalties"""

    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        meter_assignment_id: int,
        cycle_id: Optional[int],
        amount,
        reason: str,
        notes: Optional[str],
        imposed_by: str,
    ) -> Penalty:
        penalty = Penalty(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            amount=amount,
            reason=reason,
            notes=notes,
            imposed_by=imposed_by,
        )
        self.db.add(penalty)
        self.db.commit()
        self.db.refresh(penalty)
        return penalty

    def get(self, penalty_id: int) -> Optional[Penalty]:
        return self.db.query(Penalty).filter(Penalty.id == penalty_id).first()

    def list(self, skip: int = 0, limit: int = 100) -> List[Penalty]:
        return (
            self.db.query(Penalty)
            .order_by(desc(Penalty.created_at))
            .offset(skip)
            .limit(limit)
            .all()
        )

    def list_by_assignment(self, meter_assignment_id: int) -> List[Penalty]:
        return (
            self.db.query(Penalty)
            .filter(Penalty.meter_assignment_id == meter_assignment_id)
            .order_by(desc(Penalty.created_at))
            .all()
        )

    def list_applied_by_assignment(self, meter_assignment_id: int) -> List[Penalty]:
        """Get only APPLIED (not waived) penalties for an assignment."""
        return (
            self.db.query(Penalty)
            .filter(
                Penalty.meter_assignment_id == meter_assignment_id,
                Penalty.status == PenaltyStatus.APPLIED.value,
            )
            .order_by(desc(Penalty.imposed_at))
            .all()
        )

    def waive(
        self, penalty_id: int, waived_by: str, notes: Optional[str] = None
    ) -> Optional[Penalty]:
        penalty = self.get(penalty_id)
        if penalty:
            penalty.status = PenaltyStatus.WAIVED.value
            penalty.waived_at = datetime.utcnow()
            penalty.waived_by = waived_by
            penalty.notes = notes or penalty.notes
            self.db.commit()
            self.db.refresh(penalty)
        return penalty
