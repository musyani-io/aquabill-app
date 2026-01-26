"""
Conflict repository - data access layer for billing conflicts.
"""

from datetime import datetime
from typing import List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from app.models.conflict import Conflict, ConflictType, ConflictStatus


class ConflictRepository:
    """Repository for conflict database operations"""

    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        conflict_type: str,
        description: str,
        meter_assignment_id: int,
        cycle_id: Optional[int] = None,
        reading_id: Optional[int] = None,
        severity: str = "MEDIUM",
    ) -> Conflict:
        """Create a new conflict record"""
        conflict = Conflict(
            conflict_type=conflict_type,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity=severity,
        )
        self.db.add(conflict)
        self.db.commit()
        self.db.refresh(conflict)
        return conflict

    def get(self, conflict_id: int) -> Optional[Conflict]:
        """Get conflict by ID"""
        return self.db.query(Conflict).filter(Conflict.id == conflict_id).first()

    def list(self, skip: int = 0, limit: int = 100) -> List[Conflict]:
        """List all conflicts (newest first)"""
        return (
            self.db.query(Conflict)
            .order_by(desc(Conflict.created_at))
            .offset(skip)
            .limit(limit)
            .all()
        )

    def list_by_status(self, status: ConflictStatus) -> List[Conflict]:
        """Get conflicts with specific status"""
        return (
            self.db.query(Conflict)
            .filter(Conflict.status == status.value)
            .order_by(desc(Conflict.created_at))
            .all()
        )

    def list_by_assignment(self, meter_assignment_id: int) -> List[Conflict]:
        """Get all conflicts for a meter assignment"""
        return (
            self.db.query(Conflict)
            .filter(Conflict.meter_assignment_id == meter_assignment_id)
            .order_by(desc(Conflict.created_at))
            .all()
        )

    def list_by_admin(self, admin_id: str) -> List[Conflict]:
        """Get conflicts assigned to a specific admin"""
        return (
            self.db.query(Conflict)
            .filter(Conflict.assigned_to == admin_id)
            .order_by(Conflict.severity.desc())
            .all()
        )

    def assign(self, conflict_id: int, assigned_to: str) -> Optional[Conflict]:
        """Assign conflict to admin for resolution"""
        conflict = self.get(conflict_id)
        if conflict:
            conflict.status = ConflictStatus.ASSIGNED_TO_ADMIN.value
            conflict.assigned_to = assigned_to
            conflict.assigned_at = datetime.utcnow()
            self.db.commit()
            self.db.refresh(conflict)
        return conflict

    def resolve(
        self, conflict_id: int, resolved_by: str, resolution_notes: Optional[str] = None
    ) -> Optional[Conflict]:
        """Resolve a conflict"""
        conflict = self.get(conflict_id)
        if conflict:
            conflict.status = ConflictStatus.RESOLVED.value
            conflict.resolved_at = datetime.utcnow()
            conflict.resolved_by = resolved_by
            conflict.resolution_notes = resolution_notes
            self.db.commit()
            self.db.refresh(conflict)
        return conflict

    def archive(self, conflict_id: int) -> Optional[Conflict]:
        """Archive a resolved conflict"""
        conflict = self.get(conflict_id)
        if conflict:
            conflict.status = ConflictStatus.ARCHIVED.value
            self.db.commit()
            self.db.refresh(conflict)
        return conflict
