"""
Cycle service - business logic for billing cycle management.
"""
from datetime import date
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.cycle import Cycle, CycleStatus
from app.repositories.cycle import CycleRepository


class CycleService:
    """Service layer for cycle operations with business rule enforcement"""
    
    def __init__(self, db: Session):
        self.repository = CycleRepository(db)
    
    def create_cycle(
        self, 
        start_date: date, 
        end_date: date, 
        target_date: date,
        status: CycleStatus = CycleStatus.OPEN
    ) -> Tuple[Optional[Cycle], Optional[str]]:
        """
        Create a new cycle with non-overlap validation.
        
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
        """Get the currently open cycle"""
        return self.repository.get_open_cycle()
    
    def transition_status(
        self, 
        cycle_id: int, 
        new_status: CycleStatus
    ) -> Tuple[Optional[Cycle], Optional[str]]:
        """
        Transition cycle to a new status with state machine validation.
        
        Valid transitions:
        - OPEN → PENDING_REVIEW
        - PENDING_REVIEW → APPROVED
        - APPROVED → CLOSED
        - CLOSED → ARCHIVED
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
