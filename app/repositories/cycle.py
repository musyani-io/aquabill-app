"""
Cycle repository - data access layer for billing cycles.
"""

from datetime import date
from typing import List, Optional
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session
from app.models.cycle import Cycle, CycleStatus


class CycleRepository:
    """Repository for cycle database operations"""

    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        start_date: date,
        end_date: date,
        target_date: date,
        status: CycleStatus = CycleStatus.OPEN,
        proposed_target_date: Optional[date] = None,
    ) -> Cycle:
        """Create a new cycle"""
        cycle = Cycle(
            start_date=start_date,
            end_date=end_date,
            target_date=target_date,
            proposed_target_date=proposed_target_date,
            status=status.value,
        )
        self.db.add(cycle)
        self.db.commit()
        self.db.refresh(cycle)
        return cycle

    def get(self, cycle_id: int) -> Optional[Cycle]:
        """Get cycle by ID"""
        return self.db.query(Cycle).filter(Cycle.id == cycle_id).first()

    def list(self, skip: int = 0, limit: int = 100) -> List[Cycle]:
        """List all cycles ordered by start_date descending"""
        return (
            self.db.query(Cycle)
            .order_by(Cycle.start_date.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_by_status(self, status: CycleStatus) -> List[Cycle]:
        """Get all cycles with a specific status"""
        return self.db.query(Cycle).filter(Cycle.status == status.value).all()

    def get_open_cycle(self) -> Optional[Cycle]:
        """Get the currently open cycle (should be at most one)"""
        return (
            self.db.query(Cycle).filter(Cycle.status == CycleStatus.OPEN.value).first()
        )

    def get_by_date(self, check_date: date) -> Optional[Cycle]:
        """Get the cycle that contains a given date"""
        return (
            self.db.query(Cycle)
            .filter(Cycle.start_date <= check_date, Cycle.end_date >= check_date)
            .first()
        )

    def get_overlapping(
        self, start_date: date, end_date: date, exclude_id: Optional[int] = None
    ) -> List[Cycle]:
        """
        Find cycles that overlap with the given date range.
        Excludes cycle with exclude_id if provided (for updates).
        """
        query = self.db.query(Cycle).filter(
            or_(
                and_(Cycle.start_date <= start_date, Cycle.end_date > start_date),
                and_(Cycle.start_date < end_date, Cycle.end_date >= end_date),
                and_(Cycle.start_date >= start_date, Cycle.end_date <= end_date),
            )
        )

        if exclude_id:
            query = query.filter(Cycle.id != exclude_id)

        return query.all()

    def get_open_past_deadline(self, today: date) -> List[Cycle]:
        """Get OPEN cycles whose submission deadline (target_date) has passed."""
        return (
            self.db.query(Cycle)
            .filter(Cycle.status == CycleStatus.OPEN.value, Cycle.target_date < today)
            .order_by(Cycle.target_date.asc())
            .all()
        )

    def update_status(self, cycle_id: int, new_status: CycleStatus) -> Optional[Cycle]:
        """Update cycle status"""
        cycle = self.get(cycle_id)
        if cycle:
            cycle.status = new_status.value
            self.db.commit()
            self.db.refresh(cycle)
        return cycle

    def update(self, cycle_id: int, **kwargs) -> Optional[Cycle]:
        """Update cycle attributes"""
        cycle = self.get(cycle_id)
        if cycle:
            for key, value in kwargs.items():
                if hasattr(cycle, key):
                    setattr(cycle, key, value)
            self.db.commit()
            self.db.refresh(cycle)
        return cycle
