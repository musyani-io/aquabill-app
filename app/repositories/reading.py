"""
Reading repository - data access layer for meter readings.
"""
from datetime import datetime
from decimal import Decimal
from typing import List, Optional
from sqlalchemy import and_, desc
from sqlalchemy.orm import Session
from app.models.reading import Reading, ReadingType


class ReadingRepository:
    """Repository for reading database operations"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def create(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        absolute_value: Decimal,
        reading_type: ReadingType,
        submitted_by: str,
        submission_notes: Optional[str] = None
    ) -> Reading:
        """Create a new reading submission"""
        reading = Reading(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            absolute_value=absolute_value,
            type=reading_type.value,
            submitted_by=submitted_by,
            submission_notes=submission_notes
        )
        self.db.add(reading)
        self.db.commit()
        self.db.refresh(reading)
        return reading
    
    def get(self, reading_id: int) -> Optional[Reading]:
        """Get reading by ID"""
        return self.db.query(Reading).filter(Reading.id == reading_id).first()
    
    def list(self, skip: int = 0, limit: int = 100) -> List[Reading]:
        """List all readings (newest first)"""
        return self.db.query(Reading).order_by(desc(Reading.created_at)).offset(skip).limit(limit).all()
    
    def get_by_assignment(self, meter_assignment_id: int, approved_only: bool = False) -> List[Reading]:
        """Get all readings for a meter assignment, ordered by submitted_at"""
        query = self.db.query(Reading).filter(Reading.meter_assignment_id == meter_assignment_id)
        
        if approved_only:
            query = query.filter(Reading.is_approved == True)
        
        return query.order_by(Reading.submitted_at).all()
    
    def get_by_cycle(self, cycle_id: int, approved_only: bool = False) -> List[Reading]:
        """Get all readings for a cycle"""
        query = self.db.query(Reading).filter(Reading.cycle_id == cycle_id)
        
        if approved_only:
            query = query.filter(Reading.is_approved == True)
        
        return query.order_by(Reading.submitted_at).all()
    
    def get_by_assignment_and_cycle(
        self,
        meter_assignment_id: int,
        cycle_id: int
    ) -> Optional[Reading]:
        """Get reading for specific assignment and cycle (should be at most 1)"""
        return self.db.query(Reading).filter(
            and_(
                Reading.meter_assignment_id == meter_assignment_id,
                Reading.cycle_id == cycle_id
            )
        ).first()
    
    def get_baseline_reading(self, meter_assignment_id: int) -> Optional[Reading]:
        """Get the baseline reading for a meter assignment"""
        return self.db.query(Reading).filter(
            and_(
                Reading.meter_assignment_id == meter_assignment_id,
                Reading.reading_type == ReadingType.BASELINE.value
            )
        ).first()
    
    def get_latest_approved(
        self,
        meter_assignment_id: int,
        exclude_id: Optional[int] = None
    ) -> Optional[Reading]:
        """
        Get the most recent approved reading for a meter assignment.
        Excludes the specified reading if provided.
        """
        query = self.db.query(Reading).filter(
            and_(
                Reading.meter_assignment_id == meter_assignment_id,
                Reading.approved == True
            )
        )
        
        if exclude_id:
            query = query.filter(Reading.id != exclude_id)
        
        return query.order_by(desc(Reading.submitted_at)).first()
    
    def get_pending(self) -> List[Reading]:
        """Get all unapproved readings (for admin review)"""
        return self.db.query(Reading).filter(Reading.approved == False).order_by(Reading.submitted_at).all()
        
        if approved_only:
            query = query.filter(Reading.approved == True)
        
        return query.order_by(desc(Reading.submitted_at)).all()
    
    def get_baseline_reading(self, meter_assignment_id: int) -> Optional[Reading]:
        """Get the baseline reading for a meter assignment (should be at most one)"""
        return self.db.query(Reading).filter(
            and_(
                Reading.meter_assignment_id == meter_assignment_id,
                Reading.type == ReadingType.BASELINE.value
            )
        ).first()
    
    def get_previous_reading(self, meter_assignment_id: int, exclude_reading_id: Optional[int] = None) -> Optional[Reading]:
        """
        Get the most recent approved NORMAL reading for a meter assignment.
        Excludes the specified reading if provided.
        """
        query = self.db.query(Reading).filter(
            and_(
                Reading.meter_assignment_id == meter_assignment_id,
                Reading.type == ReadingType.NORMAL.value,
                Reading.approved == True
            )
        )
        
        if exclude_reading_id:
            query = query.filter(Reading.id != exclude_reading_id)
        
        return query.order_by(desc(Reading.submitted_at)).first()

    def get_approved_by_cycle(self, cycle_id: int) -> List[Reading]:
        """Get all approved readings for a given cycle."""
        return (
            self.db.query(Reading)
            .filter(
                Reading.cycle_id == cycle_id,
                Reading.approved == True
            )
            .all()
        )
    
    def approve(
        self,
        reading_id: int,
        approved_by: str,
        consumption: Optional[Decimal] = None,
        has_rollover: bool = False,
        approval_notes: Optional[str] = None
    ) -> Optional[Reading]:
        """Approve a reading and record consumption/rollover"""
        reading = self.get(reading_id)
        if reading:
            reading.approved = True
            reading.approved_at = datetime.utcnow()
            reading.approved_by = approved_by
            reading.consumption = consumption
            reading.has_rollover = has_rollover
            reading.approval_notes = approval_notes
            self.db.commit()
            self.db.refresh(reading)
        return reading
    
    def list_unapproved(self, skip: int = 0, limit: int = 100) -> List[Reading]:
        """Get unapproved readings (for admin review)"""
        return self.db.query(Reading).filter(Reading.approved == False).order_by(Reading.submitted_at).offset(skip).limit(limit).all()
