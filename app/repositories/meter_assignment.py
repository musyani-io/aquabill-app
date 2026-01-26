from datetime import date
from sqlalchemy.orm import Session

from app.models.meter_assignment import MeterAssignment, AssignmentStatus
from app.schemas.meter_assignment import MeterAssignmentCreate, MeterAssignmentUpdate


class MeterAssignmentRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, data: MeterAssignmentCreate) -> MeterAssignment:
        obj = MeterAssignment(
            meter_id=data.meter_id,
            client_id=data.client_id,
            start_date=data.start_date,
            status=AssignmentStatus.ACTIVE
        )
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def get(self, assignment_id: int) -> MeterAssignment | None:
        return self.db.get(MeterAssignment, assignment_id)

    def get_active_by_meter(self, meter_id: int) -> MeterAssignment | None:
        return (
            self.db.query(MeterAssignment)
            .filter(
                MeterAssignment.meter_id == meter_id,
                MeterAssignment.status == AssignmentStatus.ACTIVE
            )
            .first()
        )

    def list_by_client(self, client_id: int) -> list[MeterAssignment]:
        return (
            self.db.query(MeterAssignment)
            .filter(MeterAssignment.client_id == client_id)
            .order_by(MeterAssignment.start_date.desc())
            .all()
        )

    def list_active(self, skip: int = 0, limit: int = 50) -> list[MeterAssignment]:
        return (
            self.db.query(MeterAssignment)
            .filter(MeterAssignment.status == AssignmentStatus.ACTIVE)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def close_assignment(self, assignment: MeterAssignment, end_date: date) -> MeterAssignment:
        assignment.end_date = end_date
        assignment.status = AssignmentStatus.INACTIVE
        self.db.add(assignment)
        self.db.commit()
        self.db.refresh(assignment)
        return assignment

    def update(self, assignment: MeterAssignment, data: MeterAssignmentUpdate) -> MeterAssignment:
        for field, value in data.model_dump(exclude_unset=True).items():
            if field == "status" and value:
                value = AssignmentStatus[value]
            setattr(assignment, field, value)
        self.db.add(assignment)
        self.db.commit()
        self.db.refresh(assignment)
        return assignment
