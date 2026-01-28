"""
Mobile service - handles bootstrap, incremental updates, and mobile reading submission.
"""

from datetime import datetime, date, timedelta
from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import desc, or_, and_

from app.models.cycle import Cycle, CycleStatus
from app.models.meter_assignment import MeterAssignment, AssignmentStatus
from app.models.reading import Reading, ReadingType
from app.models.client import Client
from app.models.meter import Meter
from app.repositories.cycle import CycleRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.reading import ReadingRepository
from app.services.reading_service import ReadingService
from app.schemas.mobile import (
    MobileBootstrapResponse,
    MobileUpdatesResponse,
    TombstoneRecord,
    MobileReadingSubmit,
)


class MobileService:
    """Service for mobile app sync and reading submission"""

    def __init__(self, db: Session):
        self.db = db
        self.cycle_repo = CycleRepository(db)
        self.assignment_repo = MeterAssignmentRepository(db)
        self.reading_repo = ReadingRepository(db)
        self.reading_service = ReadingService(db)

    def get_bootstrap(self) -> MobileBootstrapResponse:
        """
        Get full snapshot for mobile app initial sync.
        Returns last 12 cycles + active assignments + latest approved readings.
        """
        # Get last 12 cycles (ordered newest first)
        all_cycles = (
            self.db.query(Cycle).order_by(desc(Cycle.start_date)).limit(12).all()
        )
        cycle_ids = [c.id for c in all_cycles]

        # Get all active assignments
        assignments = self.assignment_repo.list_active(skip=0, limit=10000)
        assignment_ids = [a.id for a in assignments]

        # Get latest approved readings for each assignment+cycle pair
        # (only for cycles in our 12-cycle window)
        readings = (
            self.db.query(Reading)
            .filter(
                and_(
                    Reading.meter_assignment_id.in_(assignment_ids),
                    Reading.cycle_id.in_(cycle_ids),
                    Reading.approved == True,
                )
            )
            .order_by(desc(Reading.submitted_at))
            .all()
        )

        # Get all clients and meters referenced by active assignments
        client_ids = list({a.client_id for a in assignments})
        meter_ids = list({a.meter_id for a in assignments})

        clients = self.db.query(Client).filter(Client.id.in_(client_ids)).all()
        meters = self.db.query(Meter).filter(Meter.id.in_(meter_ids)).all()

        return MobileBootstrapResponse(
            assignments=assignments,
            cycles=all_cycles,
            readings=readings,
            clients=clients,
            meters=meters,
            last_sync=datetime.utcnow(),
        )

    def get_updates(self, since: datetime) -> MobileUpdatesResponse:
        """
        Get incremental updates since last sync.
        Returns changed entities + tombstones for closed/archived cycles.
        """
        # Get cycles updated since timestamp (within last 12 cycles window)
        all_cycles = (
            self.db.query(Cycle).order_by(desc(Cycle.start_date)).limit(12).all()
        )
        cycle_ids = [c.id for c in all_cycles]

        updated_cycles = (
            self.db.query(Cycle)
            .filter(
                and_(
                    Cycle.id.in_(cycle_ids),
                    Cycle.updated_at >= since,
                )
            )
            .all()
        )

        # Get assignments updated since timestamp
        updated_assignments = (
            self.db.query(MeterAssignment)
            .filter(MeterAssignment.updated_at >= since)
            .all()
        )

        assignment_ids = [a.id for a in updated_assignments]

        # Get readings updated since timestamp (approved only, in 12-cycle window)
        updated_readings = (
            self.db.query(Reading)
            .filter(
                and_(
                    Reading.cycle_id.in_(cycle_ids),
                    Reading.updated_at >= since,
                    Reading.approved == True,
                )
            )
            .all()
        )

        # Get clients and meters that may have changed
        client_ids = list({a.client_id for a in updated_assignments})
        meter_ids = list({a.meter_id for a in updated_assignments})

        updated_clients = (
            self.db.query(Client)
            .filter(
                and_(
                    Client.id.in_(client_ids),
                    Client.updated_at >= since,
                )
            )
            .all()
            if client_ids
            else []
        )

        updated_meters = (
            self.db.query(Meter)
            .filter(
                and_(
                    Meter.id.in_(meter_ids),
                    Meter.updated_at >= since,
                )
            )
            .all()
            if meter_ids
            else []
        )

        # Generate tombstones for cycles closed/archived since last sync
        tombstones = []
        closed_cycles = (
            self.db.query(Cycle)
            .filter(
                and_(
                    Cycle.updated_at >= since,
                    Cycle.status.in_(
                        [CycleStatus.CLOSED.value, CycleStatus.ARCHIVED.value]
                    ),
                )
            )
            .all()
        )

        for cycle in closed_cycles:
            tombstones.append(
                TombstoneRecord(
                    entity_type="cycle",
                    entity_id=cycle.id,
                    action=cycle.status,
                    timestamp=cycle.updated_at,
                )
            )

        # Tombstones for deactivated assignments
        deactivated_assignments = (
            self.db.query(MeterAssignment)
            .filter(
                and_(
                    MeterAssignment.updated_at >= since,
                    MeterAssignment.status == AssignmentStatus.INACTIVE,
                )
            )
            .all()
        )

        for assignment in deactivated_assignments:
            tombstones.append(
                TombstoneRecord(
                    entity_type="assignment",
                    entity_id=assignment.id,
                    action="DEACTIVATED",
                    timestamp=assignment.updated_at,
                )
            )

        return MobileUpdatesResponse(
            assignments=updated_assignments,
            cycles=updated_cycles,
            readings=updated_readings,
            clients=updated_clients,
            meters=updated_meters,
            tombstones=tombstones,
            last_sync=datetime.utcnow(),
        )

    def submit_mobile_reading(
        self, payload: MobileReadingSubmit
    ) -> Tuple[Optional[Reading], Optional[str]]:
        """
        Submit reading from mobile app.
        Delegates to existing ReadingService with mobile-specific metadata.
        """
        # Use existing reading service for validation and submission
        reading, error = self.reading_service.submit_reading(
            meter_assignment_id=payload.meter_assignment_id,
            cycle_id=payload.cycle_id,
            absolute_value=payload.absolute_value,
            submitted_by=payload.submitted_by,
            submission_notes=payload.submission_notes,
        )

        # If successful and we have mobile metadata, we could store it
        # in a separate mobile_metadata JSON column or audit log
        # For now, we just return the reading

        return reading, error
