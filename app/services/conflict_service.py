"""
Conflict service - business logic for conflict resolution.
"""

from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.conflict import Conflict, ConflictStatus
from app.repositories.conflict import ConflictRepository


class ConflictService:
    """Service layer for conflict operations"""

    def __init__(self, db: Session):
        self.repository = ConflictRepository(db)

    def create_conflict(
        self,
        conflict_type: str,
        description: str,
        meter_assignment_id: int,
        cycle_id: Optional[int] = None,
        reading_id: Optional[int] = None,
        severity: str = "MEDIUM",
    ) -> Conflict:
        """Create and log a conflict"""
        return self.repository.create(
            conflict_type=conflict_type,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity=severity,
        )

    def get_conflict(self, conflict_id: int) -> Optional[Conflict]:
        """Get conflict by ID"""
        return self.repository.get(conflict_id)

    def list_conflicts(self, skip: int = 0, limit: int = 100) -> List[Conflict]:
        """List all conflicts"""
        return self.repository.list(skip, limit)

    def list_conflicts_by_status(self, status: ConflictStatus) -> List[Conflict]:
        """Get conflicts with specific status"""
        return self.repository.list_by_status(status)

    def list_conflicts_by_assignment(self, meter_assignment_id: int) -> List[Conflict]:
        """Get conflicts for a meter assignment"""
        return self.repository.list_by_assignment(meter_assignment_id)

    def list_conflicts_by_admin(self, admin_id: str) -> List[Conflict]:
        """Get conflicts assigned to a specific admin"""
        return self.repository.list_by_admin(admin_id)

    def assign_conflict(
        self, conflict_id: int, assigned_to: str
    ) -> Tuple[Optional[Conflict], Optional[str]]:
        """Assign conflict to admin for resolution"""
        conflict = self.repository.get(conflict_id)
        if not conflict:
            return None, f"Conflict {conflict_id} not found"

        if conflict.status in [
            ConflictStatus.RESOLVED.value,
            ConflictStatus.ARCHIVED.value,
        ]:
            return None, f"Cannot assign {conflict.status} conflict"

        updated = self.repository.assign(conflict_id, assigned_to)
        return updated, None

    def resolve_conflict(
        self, conflict_id: int, resolved_by: str, resolution_notes: Optional[str] = None
    ) -> Tuple[Optional[Conflict], Optional[str]]:
        """Resolve a conflict"""
        conflict = self.repository.get(conflict_id)
        if not conflict:
            return None, f"Conflict {conflict_id} not found"

        if conflict.status == ConflictStatus.RESOLVED.value:
            return None, f"Conflict {conflict_id} is already resolved"

        if conflict.status == ConflictStatus.OPEN.value:
            return None, "Conflict must be assigned before resolution"

        updated = self.repository.resolve(conflict_id, resolved_by, resolution_notes)
        return updated, None

    def archive_conflict(
        self, conflict_id: int
    ) -> Tuple[Optional[Conflict], Optional[str]]:
        """Archive a resolved conflict"""
        conflict = self.repository.get(conflict_id)
        if not conflict:
            return None, f"Conflict {conflict_id} not found"

        if conflict.status != ConflictStatus.RESOLVED.value:
            return None, "Only resolved conflicts can be archived"

        updated = self.repository.archive(conflict_id)
        return updated, None
