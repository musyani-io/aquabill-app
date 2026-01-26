from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.deps import get_db
from app.schemas.meter_assignment import MeterAssignmentCreate, MeterAssignmentRead, MeterAssignmentUpdate
from app.services.meter_assignment_service import MeterAssignmentService


router = APIRouter(prefix="/meter-assignments", tags=["meter-assignments"])


@router.post("/", response_model=MeterAssignmentRead, status_code=status.HTTP_201_CREATED)
def create_assignment(payload: MeterAssignmentCreate, db: Session = Depends(get_db)):
    service = MeterAssignmentService(db)
    assignment, error = service.create(payload)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return assignment


@router.get("/{assignment_id}", response_model=MeterAssignmentRead)
def get_assignment(assignment_id: int, db: Session = Depends(get_db)):
    service = MeterAssignmentService(db)
    assignment = service.get(assignment_id)
    if assignment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
    return assignment


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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
    return assignment


@router.patch("/{assignment_id}", response_model=MeterAssignmentRead)
def update_assignment(assignment_id: int, payload: MeterAssignmentUpdate, db: Session = Depends(get_db)):
    service = MeterAssignmentService(db)
    assignment = service.update(assignment_id, payload)
    if assignment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
    return assignment
