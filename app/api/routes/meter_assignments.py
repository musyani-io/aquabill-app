from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.deps import get_db
from app.schemas.meter_assignment import (
    MeterAssignmentCreate,
    MeterAssignmentRead,
    MeterAssignmentUpdate,
)
from app.services.meter_assignment_service import MeterAssignmentService


class AssignMeterRequest(BaseModel):
    """Request to assign meter with baseline"""

    meter_id: int
    client_id: int
    start_date: date
    baseline_reading: float


router = APIRouter(prefix="/meter-assignments", tags=["meter-assignments"])


@router.post(
    "/assign", response_model=MeterAssignmentRead, status_code=status.HTTP_201_CREATED
)
def assign_meter_to_client(payload: AssignMeterRequest, db: Session = Depends(get_db)):
    """
    Assign a meter to a client with baseline reading.

    CRITICAL: This creates both the assignment and baseline reading.
    No normal readings can be submitted until baseline is set.
    """
    service = MeterAssignmentService(db)
    assignment, error = service.assign_meter_to_client(
        meter_id=payload.meter_id,
        client_id=payload.client_id,
        start_date=payload.start_date,
        baseline_reading=payload.baseline_reading,
    )
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return assignment


@router.get("/{assignment_id}", response_model=MeterAssignmentRead)
def get_assignment(assignment_id: int, db: Session = Depends(get_db)):
    service = MeterAssignmentService(db)
    assignment = service.get(assignment_id)
    if assignment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found"
        )
    return assignment


@router.get("/{assignment_id}/baseline")
def get_baseline_reading(assignment_id: int, db: Session = Depends(get_db)):
    """Get baseline reading for assignment (required before normal readings)"""
    service = MeterAssignmentService(db)
    baseline = service.get_baseline_for_assignment(assignment_id)
    if baseline is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="No baseline reading found"
        )
    return {
        "id": baseline.id,
        "reading_type": baseline.reading_type,
        "reading_value": baseline.reading_value,
        "is_approved": baseline.is_approved,
        "approved_at": baseline.approved_at,
    }


@router.get("/", response_model=list[MeterAssignmentRead])
def list_active_assignments(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    service = MeterAssignmentService(db)
    return service.list_active(skip=skip, limit=limit)


@router.get("/client/{client_id}", response_model=list[MeterAssignmentRead])
def list_client_assignments(client_id: int, db: Session = Depends(get_db)):
    service = MeterAssignmentService(db)
    return service.list_by_client(client_id)


@router.get("/meter/{meter_id}/active", response_model=MeterAssignmentRead | None)
def get_active_assignment_by_meter(meter_id: int, db: Session = Depends(get_db)):
    service = MeterAssignmentService(db)
    return service.get_active_by_meter(meter_id)


@router.post("/{assignment_id}/close", response_model=MeterAssignmentRead)
def close_assignment(assignment_id: int, end_date: date, db: Session = Depends(get_db)):
    service = MeterAssignmentService(db)
    assignment = service.close_assignment(assignment_id, end_date)
    if assignment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found"
        )
    return assignment


@router.patch("/{assignment_id}", response_model=MeterAssignmentRead)
def update_assignment(
    assignment_id: int, payload: MeterAssignmentUpdate, db: Session = Depends(get_db)
):
    service = MeterAssignmentService(db)
    assignment = service.update(assignment_id, payload)
    if assignment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found"
        )
    return assignment
