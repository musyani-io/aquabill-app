from datetime import date, datetime
from sqlalchemy.orm import Session

from app.models.meter_assignment import MeterAssignment
from app.models.reading import Reading, ReadingType
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.reading import ReadingRepository
from app.schemas.meter_assignment import MeterAssignmentCreate, MeterAssignmentUpdate


class MeterAssignmentService:
    """
    Service for meter assignment workflow with baseline enforcement.
    
    CRITICAL SPEC: Every meter assignment MUST have a baseline reading
    before any NORMAL readings can be submitted. The baseline is the
    starting meter reading when assignment begins.
    """
    
    def __init__(self, db: Session):
        self.db = db
        self.repo = MeterAssignmentRepository(db)
        self.reading_repo = ReadingRepository(db)

    def assign_meter_to_client(
        self, 
        meter_id: int,
        client_id: int,
        start_date: date,
        baseline_reading: float
    ) -> tuple[MeterAssignment | None, str | None]:
        """
        Assign a meter to a client and create baseline reading.
        
        WORKFLOW:
        1. Check if meter already has active assignment (must not)
        2. Create new ACTIVE assignment
        3. Create baseline reading for this assignment
        4. Return assignment or error
        
        Args:
            meter_id: Meter to assign
            client_id: Client receiving meter
            start_date: Assignment start date
            baseline_reading: Initial meter reading (baseline value in m³)
        
        Returns:
            (assignment, error_message) - either assignment is created or error is set
        """
        # Check if meter is already assigned
        existing = self.repo.get_active_by_meter(meter_id)
        if existing:
            return None, f"Meter {meter_id} already assigned to client {existing.client_id}. End that assignment first."
        
        # Create assignment
        create_data = MeterAssignmentCreate(
            meter_id=meter_id,
            client_id=client_id,
            start_date=start_date
        )
        assignment = self.repo.create(create_data)
        
        try:
            # Create baseline reading
            baseline = Reading(
                meter_assignment_id=assignment.id,
                cycle_id=None,  # Baseline is not part of any cycle
                reading_type=ReadingType.BASELINE,
                reading_value=baseline_reading,
                is_approved=True,  # Admin baseline is auto-approved
                approved_at=datetime.utcnow(),
                notes=f"Baseline reading on meter assignment start"
            )
            self.db.add(baseline)
            self.db.commit()
            self.db.refresh(assignment)
            
            return assignment, None
        except Exception as e:
            self.db.rollback()
            return None, f"Failed to create baseline reading: {str(e)}"

    def get_baseline_for_assignment(self, assignment_id: int) -> Reading | None:
        """Get the baseline reading for an assignment"""
        return (
            self.db.query(Reading)
            .filter(
                Reading.meter_assignment_id == assignment_id,
                Reading.reading_type == ReadingType.BASELINE
            )
            .first()
        )

    def ensure_baseline_exists(self, assignment_id: int) -> tuple[bool, str | None]:
        """
        Check if assignment has baseline. Used before allowing normal readings.
        
        Returns:
            (has_baseline, error_message)
        """
        baseline = self.get_baseline_for_assignment(assignment_id)
        if not baseline:
            return False, f"Assignment {assignment_id} has no baseline reading. Cannot submit normal readings."
        return True, None

    def get(self, assignment_id: int) -> MeterAssignment | None:
        return self.repo.get(assignment_id)

    def get_active_by_meter(self, meter_id: int) -> MeterAssignment | None:
        return self.repo.get_active_by_meter(meter_id)

    def list_by_client(self, client_id: int) -> list[MeterAssignment]:
        return self.repo.list_by_client(client_id)

    def list_active(self, skip: int = 0, limit: int = 50) -> list[MeterAssignment]:
        return self.repo.list_active(skip=skip, limit=limit)

    def close_assignment(self, assignment_id: int, end_date: date) -> MeterAssignment | None:
        """Close an active assignment (deactivate)"""
        assignment = self.repo.get(assignment_id)
        if assignment is None:
            return None
        return self.repo.close_assignment(assignment, end_date)

    def update(self, assignment_id: int, data: MeterAssignmentUpdate) -> MeterAssignment | None:
        assignment = self.repo.get(assignment_id)
        if assignment is None:
            return None
        return self.repo.update(assignment, data)
