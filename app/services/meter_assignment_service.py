from datetime import date
from sqlalchemy.orm import Session

from app.models.meter_assignment import MeterAssignment
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.schemas.meter_assignment import MeterAssignmentCreate, MeterAssignmentUpdate


class MeterAssignmentService:
    def __init__(self, db: Session):
        self.repo = MeterAssignmentRepository(db)

    def create(self, data: MeterAssignmentCreate) -> tuple[MeterAssignment | None, str | None]:
        """Create new assignment. Returns (assignment, error_message)."""
        # Check if meter already has active assignment
        existing = self.repo.get_active_by_meter(data.meter_id)
        if existing:
            return None, f"Meter {data.meter_id} is already assigned to client {existing.client_id}"
        
        assignment = self.repo.create(data)
        return assignment, None

    def get(self, assignment_id: int) -> MeterAssignment | None:
        return self.repo.get(assignment_id)

    def get_active_by_meter(self, meter_id: int) -> MeterAssignment | None:
        return self.repo.get_active_by_meter(meter_id)

    def list_by_client(self, client_id: int) -> list[MeterAssignment]:
        return self.repo.list_by_client(client_id)

    def list_active(self, skip: int = 0, limit: int = 50) -> list[MeterAssignment]:
        return self.repo.list_active(skip=skip, limit=limit)

    def close_assignment(self, assignment_id: int, end_date: date) -> MeterAssignment | None:
        assignment = self.repo.get(assignment_id)
        if assignment is None:
            return None
        return self.repo.close_assignment(assignment, end_date)

    def update(self, assignment_id: int, data: MeterAssignmentUpdate) -> MeterAssignment | None:
        assignment = self.repo.get(assignment_id)
        if assignment is None:
            return None
        return self.repo.update(assignment, data)
