"""
Reading API routes - meter reading submission and approval endpoints.
"""
from typing import List
from decimal import Decimal
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.schemas.reading import ReadingCreate, ReadingRead, ReadingApprove, ReadingUpdate
from app.services.reading_service import ReadingService


class SubmitReadingRequest(BaseModel):
    """Reading submission with window checks"""
    meter_assignment_id: int
    cycle_id: int
    absolute_value: Decimal = BaseModel.model_fields['absolute_value'].__class__(description="Meter reading in m³")
    submitted_by: str
    submission_notes: str = None


router = APIRouter(prefix="/readings", tags=["readings"])


@router.post("/submit", response_model=ReadingRead, status_code=status.HTTP_201_CREATED)
def submit_reading(request: SubmitReadingRequest, db: Session = Depends(get_db)):
    """
    Submit a meter reading with full window and baseline validation.
    
    CRITICAL VALIDATION:
    - Meter assignment must be ACTIVE
    - Cycle must be OPEN
    - Today must be <= cycle.target_date (submission window)
    - Baseline reading must exist (created during meter assignment)
    - Detects late submissions and rollovers as anomalies
    
    Errors:
    - 400: Validation fails (closed cycle, missing baseline, late submission)
    - 404: Assignment or cycle not found
    """
    service = ReadingService(db)
    reading, error = service.submit_reading(
        meter_assignment_id=request.meter_assignment_id,
        cycle_id=request.cycle_id,
        absolute_value=request.absolute_value,
        submitted_by=request.submitted_by,
        submission_notes=request.submission_notes
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return reading


@router.get("/{reading_id}", response_model=ReadingRead)
def get_reading(reading_id: int, db: Session = Depends(get_db)):
    """Get reading by ID"""
    service = ReadingService(db)
    reading = service.get_reading(reading_id)
    
    if not reading:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Reading {reading_id} not found")
    
    return reading


@router.get("/", response_model=List[ReadingRead])
def list_readings(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """List all readings (newest first)"""
    service = ReadingService(db)
    return service.list_readings(skip, limit)


@router.get("/assignment/{meter_assignment_id}", response_model=List[ReadingRead])
def get_readings_by_assignment(meter_assignment_id: int, db: Session = Depends(get_db)):
    """Get all readings for a meter assignment"""
    service = ReadingService(db)
    return service.get_readings_by_assignment(meter_assignment_id)


@router.get("/cycle/{cycle_id}", response_model=List[ReadingRead])
def get_readings_by_cycle(cycle_id: int, db: Session = Depends(get_db)):
    """Get all readings for a cycle"""
    service = ReadingService(db)
    return service.get_readings_by_cycle(cycle_id)


@router.get("/pending", response_model=List[ReadingRead])
def get_pending_readings(db: Session = Depends(get_db)):
    """Get all unapproved readings waiting for admin review"""
    service = ReadingService(db)
    return service.get_pending_readings()


@router.get("/{reading_id}/consumption")
def get_consumption(reading_id: int, db: Session = Depends(get_db)):
    """Calculate consumption for a reading (current - previous approved)"""
    service = ReadingService(db)
    consumption, warning = service.calculate_consumption(reading_id)
    
    if consumption is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=warning)
    
    return {
        "reading_id": reading_id,
        "consumption": float(consumption),
        "warning": warning
    }


@router.get("/", response_model=List[ReadingRead])
def list_readings(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """List all readings (newest first)"""
    service = ReadingService(db)
    return service.list_readings(skip=skip, limit=limit)


@router.get("/assignment/{meter_assignment_id}", response_model=List[ReadingRead])
def get_readings_by_assignment(
    meter_assignment_id: int,
    approved_only: bool = False,
    db: Session = Depends(get_db)
):
    """Get readings for a meter assignment"""
    service = ReadingService(db)
    return service.list_readings_by_assignment(meter_assignment_id, approved_only)


@router.get("/cycle/{cycle_id}", response_model=List[ReadingRead])
def get_readings_by_cycle(
    cycle_id: int,
    approved_only: bool = False,
    db: Session = Depends(get_db)
):
    """Get readings for a cycle"""
    service = ReadingService(db)
    return service.list_readings_by_cycle(cycle_id, approved_only)


@router.get("/pending/unapproved", response_model=List[ReadingRead])
def list_unapproved_readings(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Get unapproved readings for admin review"""
    service = ReadingService(db)
    return service.list_unapproved_readings(skip, limit)


@router.post("/{reading_id}/approve", response_model=ReadingRead)
def approve_reading(
    reading_id: int,
    approve_data: ReadingApprove,
    db: Session = Depends(get_db)
):
    """
    Approve a reading and calculate consumption.
    
    Logic:
    - BASELINE: no consumption, no charges
    - NORMAL: consumption = current_value - previous_reading_value
    - Rollover: detected if result is negative
    """
    service = ReadingService(db)
    reading, error = service.approve_reading(
        reading_id=reading_id,
        approved_by=approve_data.approved_by,
        approval_notes=approve_data.approval_notes
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return reading
