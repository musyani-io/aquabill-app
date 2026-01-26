"""
Reading service - business logic for meter readings and consumption calculation.
"""
from datetime import datetime, date
from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.reading import Reading, ReadingType
from app.models.meter_assignment import MeterAssignment
from app.models.cycle import Cycle
from app.repositories.reading import ReadingRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.cycle import CycleRepository


class ReadingService:
    """Service layer for reading operations with business rule enforcement"""
    
    def __init__(self, db: Session):
        self.db = db
        self.repository = ReadingRepository(db)
        self.assignment_repository = MeterAssignmentRepository(db)
        self.cycle_repository = CycleRepository(db)
    
    def submit_reading(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        absolute_value: Decimal,
        submitted_by: str,
        submission_notes: Optional[str] = None
    ) -> Tuple[Optional[Reading], Optional[str]]:
        """
        Submit a meter reading with baseline enforcement.
        
        Business Rules:
        - First reading for a meter_assignment must be BASELINE
        - Subsequent readings must be NORMAL
        - Submission must be within cycle.target_date
        
        Returns:
            (Reading, None) if successful
            (None, error_message) if validation fails
        """
        # Validate meter assignment exists and is active
        assignment = self.assignment_repository.get(meter_assignment_id)
        if not assignment:
            return None, f"Meter assignment {meter_assignment_id} not found"
        
        if assignment.status != "ACTIVE":
            return None, f"Meter assignment {meter_assignment_id} is not active"
        
        # Validate cycle exists
        cycle = self.cycle_repository.get(cycle_id)
        if not cycle:
            return None, f"Cycle {cycle_id} not found"
        
        # Check submission window (before or on target_date)
        today = date.today()
        if today > cycle.target_date:
            return None, f"Submission window closed on {cycle.target_date}. Today is {today}"
        
        # Determine reading type (baseline or normal)
        existing_baseline = self.repository.get_baseline_reading(meter_assignment_id)
        
        if not existing_baseline:
            # First reading must be BASELINE
            reading_type = ReadingType.BASELINE
        else:
            # Subsequent readings are NORMAL
            reading_type = ReadingType.NORMAL
        
        # Create reading
        reading = self.repository.create(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            absolute_value=absolute_value,
            reading_type=reading_type,
            submitted_by=submitted_by,
            submission_notes=submission_notes
        )
        
        return reading, None
    
    def approve_reading(
        self,
        reading_id: int,
        approved_by: str,
        approval_notes: Optional[str] = None
    ) -> Tuple[Optional[Reading], Optional[str]]:
        """
        Approve a reading and calculate consumption.
        
        Logic:
        - BASELINE readings: consumption = NULL, no charges generated
        - NORMAL readings: consumption = absolute_value - previous_reading.absolute_value
        - Rollover detection: if consumption would be negative, set has_rollover = True
        
        Returns:
            (Reading, None) if successful
            (None, error_message) if validation fails
        """
        reading = self.repository.get(reading_id)
        if not reading:
            return None, f"Reading {reading_id} not found"
        
        if reading.approved:
            return None, f"Reading {reading_id} is already approved"
        
        # BASELINE readings generate no consumption
        if reading.type == ReadingType.BASELINE.value:
            approved = self.repository.approve(
                reading_id=reading_id,
                approved_by=approved_by,
                consumption=None,
                has_rollover=False,
                approval_notes=approval_notes
            )
            return approved, None
        
        # NORMAL readings: calculate consumption from previous reading
        previous = self.repository.get_previous_reading(reading.meter_assignment_id)
        
        if not previous:
            # No previous normal reading (shouldn't happen if baseline exists)
            return None, f"No previous baseline reading found for meter assignment {reading.meter_assignment_id}"
        
        # Calculate consumption
        consumption = reading.absolute_value - previous.absolute_value
        has_rollover = False
        
        if consumption < 0:
            # Meter has rolled over (reset)
            has_rollover = True
            # Rollover consumption = (max_meter_value - previous) + current_value
            # For now, we record as-is and flag for admin review
            # In a real system, admin would specify meter max value
        
        # Approve reading with calculated consumption
        approved = self.repository.approve(
            reading_id=reading_id,
            approved_by=approved_by,
            consumption=abs(consumption) if has_rollover else consumption,  # Absolute for rollover
            has_rollover=has_rollover,
            approval_notes=approval_notes
        )
        
        return approved, None
    
    def get_reading(self, reading_id: int) -> Optional[Reading]:
        """Get reading by ID"""
        return self.repository.get(reading_id)
    
    def list_readings(self, skip: int = 0, limit: int = 100) -> List[Reading]:
        """List all readings"""
        return self.repository.list(skip, limit)
    
    def list_readings_by_assignment(self, meter_assignment_id: int, approved_only: bool = False) -> List[Reading]:
        """Get readings for a specific meter assignment"""
        return self.repository.list_by_assignment(meter_assignment_id, approved_only)
    
    def list_readings_by_cycle(self, cycle_id: int, approved_only: bool = False) -> List[Reading]:
        """Get readings for a specific cycle"""
        return self.repository.list_by_cycle(cycle_id, approved_only)
    
    def list_unapproved_readings(self, skip: int = 0, limit: int = 100) -> List[Reading]:
        """Get unapproved readings for admin review"""
        return self.repository.list_unapproved(skip, limit)
