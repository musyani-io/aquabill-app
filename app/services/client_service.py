"""
Client service - business logic for client management and meter assignment.

SPEC: Client creation automatically creates:
1. Meter record (from meter_serial_number)
2. MeterAssignment linking client to meter
3. BASELINE Reading for the assignment (awaiting admin approval)

This enforces:
- One active assignment per meter at a time
- BASELINE readings for all new assignments
- Baseline generates no consumption/charges
"""

from datetime import date
from sqlalchemy.orm import Session

from app.models.client import Client
from app.models.meter import Meter
from app.models.meter_assignment import MeterAssignment, AssignmentStatus
from app.models.reading import Reading, ReadingType
from app.repositories.client import ClientRepository
from app.schemas.client import ClientCreate, ClientUpdate
from app.services.cycle_service import CycleService


class ClientService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ClientRepository(db)

    def create(self, data: ClientCreate) -> Client:
        """
        Create a new client with automatic Meter and MeterAssignment setup.

        Workflow:
        1. Create Client record
        2. Create Meter record (or reuse if serial exists)
        3. Create MeterAssignment (ACTIVE) linking client to meter
        4. Create BASELINE Reading in the current OPEN cycle (if exists)

        Baseline Reading:
        - Type: BASELINE (no consumption calculated)
        - Value: initial_meter_reading
        - Status: Pending admin approval
        - assigned to current OPEN cycle (if one exists)

        Returns:
            Client record with created relationships
        """
        # Create client
        client = self.repo.create(data)

        try:
            # Create or get Meter
            meter = self.db.query(Meter).filter(
                Meter.serial_number == data.meter_serial_number
            ).first()

            if not meter:
                meter = Meter(serial_number=data.meter_serial_number)
                self.db.add(meter)
                self.db.flush()  # Get meter.id without committing

            # Create MeterAssignment (ACTIVE)
            # Deactivate any existing active assignment for this meter (enforce one-active rule)
            existing_active = self.db.query(MeterAssignment).filter(
                MeterAssignment.meter_id == meter.id,
                MeterAssignment.status == AssignmentStatus.ACTIVE,
            ).first()

            if existing_active:
                # Close the previous assignment
                existing_active.end_date = date.today()
                existing_active.status = AssignmentStatus.INACTIVE
                self.db.add(existing_active)
                self.db.flush()

            # Create new active assignment
            assignment = MeterAssignment(
                meter_id=meter.id,
                client_id=client.id,
                start_date=date.today(),
                status=AssignmentStatus.ACTIVE,
            )
            self.db.add(assignment)
            self.db.flush()  # Get assignment.id

            # Create BASELINE Reading in current OPEN cycle
            cycle_service = CycleService(self.db)
            open_cycle = cycle_service.get_open_cycle()

            if open_cycle:
                baseline_reading = Reading(
                    meter_assignment_id=assignment.id,
                    cycle_id=open_cycle.id,
                    absolute_value=data.initial_meter_reading,
                    type=ReadingType.BASELINE,
                    submitted_by="SYSTEM",  # Admin created during client creation
                    submitted_at=date.today(),
                    consumption=None,  # Baseline has no consumption
                    has_rollover=False,
                    approved=False,  # Awaits admin approval
                )
                self.db.add(baseline_reading)

            # Commit all changes atomically
            self.db.commit()
            self.db.refresh(client)

        except Exception as e:
            self.db.rollback()
            # Re-raise to be caught by API route handler
            raise

        return client

    def get(self, client_id: int) -> Client | None:
        return self.repo.get(client_id)

    def list(self, skip: int = 0, limit: int = 50) -> list[Client]:
        return self.repo.list(skip=skip, limit=limit)

    def update(self, client_id: int, data: ClientUpdate) -> Client | None:
        client = self.repo.get(client_id)
        if client is None:
            return None
        return self.repo.update(client, data)

    def delete(self, client_id: int) -> bool:
        client = self.repo.get(client_id)
        if client is None:
            return False
        self.repo.delete(client)
        return True
