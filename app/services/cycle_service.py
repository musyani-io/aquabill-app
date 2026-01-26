"""
Cycle service - business logic for billing cycle management.
"""
from datetime import date, datetime, timedelta
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.cycle import Cycle, CycleStatus
from app.repositories.cycle import CycleRepository


class CycleService:
    """
    Service layer for cycle operations with business rule enforcement.
    
    SPEC: Handles billing cycle lifecycle:
    1. Create OPEN cycles on schedule
    2. Transition through states: OPEN → PENDING_REVIEW → APPROVED → CLOSED → ARCHIVED
    3. Enforce one-OPEN-cycle rule (can't have multiple OPEN at same time)
    4. Generate charges on APPROVAL
    5. Auto-transition to PENDING_REVIEW when reading window closes
    """
    
    def __init__(self, db: Session):
        self.repository = CycleRepository(db)
        self.db = db
    
    def create_cycle(
        self, 
        start_date: date, 
        end_date: date, 
        target_date: date,
        status: CycleStatus = CycleStatus.OPEN
    ) -> Tuple[Optional[Cycle], Optional[str]]:
        """
        Create a new cycle with non-overlap validation.
        
        WORKFLOW:
        1. Check for overlapping cycles (dates cannot overlap)
        2. Check for existing OPEN cycle (only one OPEN allowed)
        3. Create cycle in OPEN state
        
        Returns:
            (Cycle, None) if successful
            (None, error_message) if validation fails
        """
        # Check for overlapping cycles
        overlapping = self.repository.get_overlapping(start_date, end_date)
        if overlapping:
            cycle_ids = [str(c.id) for c in overlapping]
            return None, f"Date range overlaps with existing cycle(s): {', '.join(cycle_ids)}"
        
        # Check for only one OPEN cycle at a time
        if status == CycleStatus.OPEN:
            open_cycle = self.repository.get_open_cycle()
            if open_cycle:
                return None, f"Cycle {open_cycle.id} is already OPEN. Close it before opening a new cycle."
        
        cycle = self.repository.create(start_date, end_date, target_date, status)
        return cycle, None
    
    def get_cycle(self, cycle_id: int) -> Optional[Cycle]:
        """Get cycle by ID"""
        return self.repository.get(cycle_id)
    
    def list_cycles(self, skip: int = 0, limit: int = 100) -> List[Cycle]:
        """List all cycles"""
        return self.repository.list(skip, limit)
    
    def get_cycles_by_status(self, status: CycleStatus) -> List[Cycle]:
        """Get cycles filtered by status"""
        return self.repository.get_by_status(status)
    
    def get_open_cycle(self) -> Optional[Cycle]:
        """Get the currently open cycle for reading submissions"""
        return self.repository.get_open_cycle()
    
    def get_cycle_for_date(self, check_date: date) -> Optional[Cycle]:
        """Get the cycle that contains a given date"""
        return self.repository.get_by_date(check_date)
    
    def schedule_cycles(
        self,
        start_date: date,
        num_cycles: int,
        cycle_length_days: int,
        submission_window_days: int
    ) -> Tuple[List[Cycle], Optional[str]]:
        """
        Batch create multiple cycles on schedule.
        
        SCHEDULER: Call this to create a series of billing cycles.
        
        Args:
            start_date: First cycle starts on this date
            num_cycles: How many cycles to create
            cycle_length_days: Each cycle is this many days (e.g., 30 for monthly)
            submission_window_days: Days after cycle end for reading submission
        
        Example:
            Jan 1-30 (cycle 1), Feb 1-28 (cycle 2), Mar 1-31 (cycle 3), etc.
            submission_window_days=5 means readings due 5 days after cycle end
        
        Returns:
            (list of created cycles, error message if any failed)
        """
        created_cycles = []
        errors = []
        
        current_start = start_date
        
        for i in range(num_cycles):
            # Calculate dates for this cycle
            cycle_start = current_start
            cycle_end = current_start + timedelta(days=cycle_length_days - 1)
            submission_deadline = cycle_end + timedelta(days=submission_window_days)
            
            # Create cycle (all scheduled cycles start in OPEN state)
            cycle, error = self.create_cycle(
                start_date=cycle_start,
                end_date=cycle_end,
                target_date=submission_deadline,
                status=CycleStatus.OPEN
            )
            
            if error:
                errors.append(f"Cycle {i+1}: {error}")
            else:
                created_cycles.append(cycle)
            
            # Move to next cycle start date
            current_start = cycle_end + timedelta(days=1)
        
        error_message = " | ".join(errors) if errors else None
        return created_cycles, error_message
    
    def auto_transition_on_deadline(self, cycle_id: int) -> Tuple[Optional[Cycle], Optional[str]]:
        """
        Auto-transition cycle from OPEN to PENDING_REVIEW when deadline passes.
        
        SCHEDULER: Call this for OPEN cycles where target_date has passed.
        
        Business logic:
        - If target_date < today and cycle is OPEN → transition to PENDING_REVIEW
        - This closes the reading submission window
        
        Returns:
            (updated cycle, error message)
        """
        cycle = self.repository.get(cycle_id)
        if not cycle:
            return None, f"Cycle {cycle_id} not found"
        
        if cycle.status != CycleStatus.OPEN:
            return None, f"Cycle {cycle_id} is not OPEN (current: {cycle.status})"
        
        if cycle.target_date >= date.today():
            return None, f"Cycle {cycle_id} submission deadline has not passed yet"
        
        # Transition to PENDING_REVIEW
        updated = self.repository.update_status(cycle_id, CycleStatus.PENDING_REVIEW)
        return updated, None
    
    def transition_status(
        self, 
        cycle_id: int, 
        new_status: CycleStatus
    ) -> Tuple[Optional[Cycle], Optional[str]]:
        """
        Manually transition cycle to a new status with state machine validation.
        
        Valid transitions:
        - OPEN → PENDING_REVIEW
        - PENDING_REVIEW → APPROVED
        - APPROVED → CLOSED
        - CLOSED → ARCHIVED
        
        Note: For deadline-triggered OPEN→PENDING_REVIEW, use auto_transition_on_deadline()
        """
        cycle = self.repository.get(cycle_id)
        if not cycle:
            return None, f"Cycle {cycle_id} not found"
        
        current_status = CycleStatus(cycle.status)
        
        # Define valid transitions
        valid_transitions = {
            CycleStatus.OPEN: [CycleStatus.PENDING_REVIEW],
            CycleStatus.PENDING_REVIEW: [CycleStatus.APPROVED],
            CycleStatus.APPROVED: [CycleStatus.CLOSED],
            CycleStatus.CLOSED: [CycleStatus.ARCHIVED],
            CycleStatus.ARCHIVED: []  # Terminal state
        }
        
        if new_status not in valid_transitions.get(current_status, []):
            return None, f"Invalid transition from {current_status.value} to {new_status.value}"
        
        updated_cycle = self.repository.update_status(cycle_id, new_status)
        return updated_cycle, None
