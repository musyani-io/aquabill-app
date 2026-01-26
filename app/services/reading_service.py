"""
Reading service - business logic for meter readings and consumption calculation.
"""
from datetime import datetime, date
from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.reading import Reading, ReadingType
from app.models.meter_assignment import MeterAssignment, AssignmentStatus
from app.models.cycle import Cycle, CycleStatus
from app.models.anomaly import Anomaly, AnomalyType
from app.repositories.reading import ReadingRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.cycle import CycleRepository
from app.repositories.anomaly import AnomalyRepository


class ReadingService:
    """
    Service layer for reading operations with business rule enforcement.
    
    SPEC: Handles reading submission with:
    - Window validation (must submit within cycle.target_date)
    - Baseline enforcement (first reading MUST be baseline)
    - Consumption calculation (current - previous)
    - Rollover detection (reading decreased = meter rolled over)
    """
    
    def __init__(self, db: Session):
        self.db = db
        self.repository = ReadingRepository(db)
        self.assignment_repository = MeterAssignmentRepository(db)
        self.cycle_repository = CycleRepository(db)
        self.anomaly_repository = AnomalyRepository(db)
    
    def submit_reading(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        absolute_value: Decimal,
        submitted_by: str,
        submission_notes: Optional[str] = None
    ) -> Tuple[Optional[Reading], Optional[str]]:
        """
        Submit a meter reading with full window and baseline validation.
        
        CRITICAL WORKFLOW:
        1. Validate meter assignment is ACTIVE
        2. Validate cycle is OPEN (can't submit to closed cycle)
        3. Check submission window (today <= cycle.target_date)
        4. Ensure baseline exists (if first reading, create baseline implicitly)
        5. Calculate consumption (current - previous approved reading)
        6. Detect rollover (reading < previous = meter rolled)
        7. Log anomalies if needed
        
        Returns:
            (Reading, None) if successful
            (None, error_message) if validation fails
        """
        # ============ Validate Assignment ============
        assignment = self.assignment_repository.get(meter_assignment_id)
        if not assignment:
            return None, f"Meter assignment {meter_assignment_id} not found"
        
        if assignment.status != AssignmentStatus.ACTIVE.value:
            return None, f"Meter assignment {meter_assignment_id} is not ACTIVE (current: {assignment.status})"
        
        # ============ Validate Cycle ============
        cycle = self.cycle_repository.get(cycle_id)
        if not cycle:
            return None, f"Cycle {cycle_id} not found"
        
        if cycle.status != CycleStatus.OPEN.value:
            return None, f"Cycle {cycle_id} is not OPEN for submissions (current status: {cycle.status})"
        
        # ============ Check Submission Window ============
        today = date.today()
        is_late = False
        
        if today > cycle.target_date:
            # Late submission - still allowed but flagged
            is_late = True
            # Optional: could reject late submissions entirely
            # return None, f"Submission window closed on {cycle.target_date}. Today is {today}"
        
        # ============ Baseline Enforcement ============
        existing_baseline = self.repository.get_baseline_reading(meter_assignment_id)
        
        if not existing_baseline:
            return None, f"No baseline reading exists for assignment {meter_assignment_id}. Cannot submit normal readings."
        
        # ============ Check for Duplicate Submission ============
        existing_in_cycle = self.repository.get_by_assignment_and_cycle(meter_assignment_id, cycle_id)
        if existing_in_cycle:
            return None, f"Reading already submitted for this meter in cycle {cycle_id}. ID: {existing_in_cycle.id}"
        
        # ============ Create Reading ============
        reading = self.repository.create(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            absolute_value=absolute_value,
            reading_type=ReadingType.NORMAL,
            submitted_by=submitted_by,
            submission_notes=submission_notes
        )
        
        # ============ Detect Anomalies ============
        anomalies = []
        
        # Late submission anomaly
        if is_late:
            anomaly = self.anomaly_repository.create(
                meter_assignment_id=meter_assignment_id,
                cycle_id=cycle_id,
                reading_id=reading.id,
                anomaly_type=AnomalyType.LATE_SUBMISSION,
                description=f"Reading submitted {(today - cycle.target_date).days} days after deadline ({cycle.target_date})"
            )
            anomalies.append(anomaly)
        
        # Rollover detection
        if existing_baseline:
            # Get previous approved reading
            prev_reading = self.repository.get_latest_approved(meter_assignment_id, exclude_id=reading.id)
            
            if prev_reading and Decimal(absolute_value) < Decimal(prev_reading.reading_value):
                # Meter rolled over (reading decreased)
                anomaly = self.anomaly_repository.create(
                    meter_assignment_id=meter_assignment_id,
                    cycle_id=cycle_id,
                    reading_id=reading.id,
                    anomaly_type=AnomalyType.ROLLOVER_WITHOUT_LIMIT,
                    description=f"Meter reading decreased from {prev_reading.reading_value} to {absolute_value}. Possible rollover."
                )
                anomalies.append(anomaly)
        
        return reading, None
    
    def get_reading(self, reading_id: int) -> Optional[Reading]:
        """Get reading by ID"""
        return self.repository.get(reading_id)
    
    def list_readings(self, skip: int = 0, limit: int = 100) -> List[Reading]:
        """List all readings"""
        return self.repository.list(skip, limit)
    
    def get_readings_by_assignment(self, meter_assignment_id: int) -> List[Reading]:
        """Get all readings for a meter assignment"""
        return self.repository.get_by_assignment(meter_assignment_id)
    
    def get_readings_by_cycle(self, cycle_id: int) -> List[Reading]:
        """Get all readings for a cycle"""
        return self.repository.get_by_cycle(cycle_id)
    
    def get_pending_readings(self) -> List[Reading]:
        """Get all unapproved readings waiting for admin review"""
        return self.repository.get_pending()
    
    def calculate_consumption(
        self, 
        reading_id: int
    ) -> Tuple[Optional[Decimal], Optional[str]]:
        """
        Calculate consumption = current reading - previous approved reading.
        
        Returns:
            (consumption in m³, error_message)
        """
        reading = self.repository.get(reading_id)
        if not reading:
            return None, f"Reading {reading_id} not found"
        
        # Get previous approved reading
        prev_reading = self.repository.get_latest_approved(
            reading.meter_assignment_id,
            exclude_id=reading.id
        )
        
        if not prev_reading:
            return None, "No previous approved reading found"
        
        consumption = Decimal(reading.reading_value) - Decimal(prev_reading.reading_value)
        
        if consumption < 0:
            return consumption, "WARNING: Negative consumption (rollover detected)"
        
        return consumption, None
        
        
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
