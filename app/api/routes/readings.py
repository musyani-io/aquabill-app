"""
Reading API routes - meter reading submission and approval endpoints.
"""
from typing import List
from decimal import Decimal
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.services.reading_service import ReadingService
from app.schemas.reading import ReadingCreate, ReadingRead, ReadingApprove


# Request schemas
class SubmitReadingRequest(BaseModel):
    """Request body for submitting a meter reading"""
    meter_assignment_id: int = Field(..., description="Meter assignment ID")
    cycle_id: int = Field(..., description="Billing cycle ID")
    absolute_value: Decimal = Field(..., ge=0, decimal_places=4, description="Meter reading in m³")
    submitted_by: str = Field(..., min_length=1, max_length=100, description="User submitting reading")
    submission_notes: str = Field(None, max_length=500, description="Optional notes about submission")


class ApproveReadingRequest(BaseModel):
    """Request body for approving a reading"""
    approved_by: str = Field(..., min_length=1, max_length=100, description="Admin username")
    approval_notes: str = Field(None, max_length=500, description="Notes about approval")
    admin_consumption_override: Decimal = Field(None, description="Override calculated consumption (optional)")


class RejectReadingRequest(BaseModel):
    """Request body for rejecting a reading"""
    rejected_by: str = Field(..., min_length=1, max_length=100, description="Admin username")
    rejection_reason: str = Field(..., min_length=1, max_length=500, description="Reason for rejection")


class VerifyRolloverRequest(BaseModel):
    """Request body for verifying a rollover reading"""
    max_meter_value: Decimal = Field(..., gt=0, decimal_places=4, description="Meter's max value (e.g., 999999.9999)")
    verified_by: str = Field(..., min_length=1, max_length=100, description="Admin username verifying rollover")
    verification_notes: str = Field(None, max_length=500, description="Notes about rollover verification")


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
    
    Returns:
    - 201: Reading created successfully
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


@router.get("/pending", response_model=List[ReadingRead])
def get_pending_readings(db: Session = Depends(get_db)):
    """
    Get all unapproved readings waiting for admin review.
    
    Returns:
    - List of readings with is_approved=False, ready for approval/rejection
    """
    service = ReadingService(db)
    return service.get_pending_readings()


@router.get("/{reading_id}", response_model=ReadingRead)
def get_reading(reading_id: int, db: Session = Depends(get_db)):
    """Get a specific reading by ID"""
    service = ReadingService(db)
    reading = service.get_reading(reading_id)
    
    if not reading:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Reading {reading_id} not found")
    
    return reading


@router.get("/assignment/{meter_assignment_id}", response_model=List[ReadingRead])
def get_readings_by_assignment(meter_assignment_id: int, db: Session = Depends(get_db)):
    """Get all readings for a specific meter assignment"""
    service = ReadingService(db)
    return service.get_readings_by_assignment(meter_assignment_id)


@router.get("/cycle/{cycle_id}", response_model=List[ReadingRead])
def get_readings_by_cycle(cycle_id: int, db: Session = Depends(get_db)):
    """Get all readings submitted for a specific billing cycle"""
    service = ReadingService(db)
    return service.get_readings_by_cycle(cycle_id)


@router.get("/{reading_id}/consumption")
def get_consumption(reading_id: int, db: Session = Depends(get_db)):
    """
    Calculate consumption for a reading (current - previous approved).
    
    Returns:
    - consumption: m³ consumed in this period
    - warning: "ROLLOVER" message if meter rolled over
    """
    service = ReadingService(db)
    consumption, warning = service.calculate_consumption(reading_id)
    
    if consumption is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=warning)
    
    return {
        "reading_id": reading_id,
        "consumption": float(consumption),
        "warning": warning
    }


@router.post("/{reading_id}/approve", response_model=ReadingRead, status_code=status.HTTP_200_OK)
def approve_reading(
    reading_id: int,
    approved_by: str = Query(..., description="Admin username"),
    approval_notes: str = Query(None, description="Notes about approval"),
    admin_consumption_override: Decimal = Query(None, description="Override calculated consumption (optional)"),
    db: Session = Depends(get_db)
):
    """
    Approve a reading and calculate consumption.
    
    WORKFLOW:
    1. Validate reading not already approved
    2. BASELINE readings: no consumption, no charges generated
    3. NORMAL readings: consumption = current_value - previous_reading_value
    4. Rollover detection: if negative, flag for admin
    5. Admin can override consumption if needed
    
    Returns approved reading with consumption calculated.
    """
    service = ReadingService(db)
    reading, error = service.approve_reading(
        reading_id=reading_id,
        approved_by=approved_by,
        approval_notes=approval_notes,
        admin_consumption_override=admin_consumption_override
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return reading


@router.post("/{reading_id}/reject", status_code=status.HTTP_200_OK)
def reject_reading(
    reading_id: int,
    rejected_by: str = Query(..., description="Admin username"),
    rejection_reason: str = Query(..., description="Reason for rejection"),
    db: Session = Depends(get_db)
):
    """
    Reject a submitted reading (admin action).
    
    Allows user to submit a corrected reading.
    
    Returns:
    - status: "rejected"
    - notes: Rejection reason stored for audit trail
    """
    service = ReadingService(db)
    reading, error = service.reject_reading(
        reading_id=reading_id,
        rejected_by=rejected_by,
        rejection_reason=rejection_reason
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return {
        "id": reading.id,
        "status": "rejected",
        "notes": reading.notes,
        "message": f"Reading {reading_id} rejected. User can submit corrected reading."
    }


@router.get("/", response_model=List[ReadingRead])
def list_all_readings(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """List all readings with pagination (newest first)"""
    service = ReadingService(db)
    return service.list_readings(skip=skip, limit=limit)


@router.post("/{reading_id}/verify-rollover", response_model=ReadingRead, status_code=status.HTTP_200_OK)
def verify_rollover(
    reading_id: int,
    max_meter_value: Decimal = Query(..., gt=0, description="Meter max value"),
    verified_by: str = Query(..., description="Admin username"),
    verification_notes: str = Query(None, description="Notes about rollover"),
    db: Session = Depends(get_db)
):
    """
    Verify and resolve a rollover reading.
    
    Admin confirms that meter rolled over and provides the maximum meter value.
    
    Recalculates consumption:
    - consumption = (max_meter_value - previous_reading) + current_reading
    - Example: previous=99800, current=200, max=99999
    - consumption = (99999 - 99800) + 200 = 399
    
    Returns:
    - Reading with corrected consumption and has_rollover=False
    """
    service = ReadingService(db)
    reading, error = service.verify_rollover(
        reading_id=reading_id,
        max_meter_value=max_meter_value,
        verified_by=verified_by,
        verification_notes=verification_notes
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return reading


@router.post("/{reading_id}/reject-rollover", status_code=status.HTTP_200_OK)
def reject_rollover(
    reading_id: int,
    rejected_by: str = Query(..., description="Admin username"),
    reason: str = Query(..., description="Reason for rejecting rollover claim"),
    db: Session = Depends(get_db)
):
    """
    Reject a rollover claim (mark as false positive).
    
    Admin determines the reading is not actually a rollover.
    User must resubmit corrected reading.
    """
    service = ReadingService(db)
    reading, error = service.reject_rollover_as_error(
        reading_id=reading_id,
        rejected_by=rejected_by,
        reason=reason
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return {
        "id": reading.id,
        "status": "rollover_rejected",
        "notes": reading.notes,
        "message": f"Rollover for reading {reading_id} rejected as error. User can resubmit corrected reading."
    }
