"""
Cycle API routes - billing cycle management endpoints.
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.schemas.cycle import CycleCreate, CycleRead, CycleUpdate
from app.services.cycle_service import CycleService
from app.models.cycle import CycleStatus

router = APIRouter(prefix="/cycles", tags=["cycles"])


@router.post("/", response_model=CycleRead, status_code=status.HTTP_201_CREATED)
def create_cycle(cycle_data: CycleCreate, db: Session = Depends(get_db)):
    """Create a new billing cycle with non-overlap validation"""
    service = CycleService(db)
    cycle, error = service.create_cycle(
        start_date=cycle_data.start_date,
        end_date=cycle_data.end_date,
        target_date=cycle_data.target_date,
        status=cycle_data.status
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return cycle


@router.get("/{cycle_id}", response_model=CycleRead)
def get_cycle(cycle_id: int, db: Session = Depends(get_db)):
    """Get cycle by ID"""
    service = CycleService(db)
    cycle = service.get_cycle(cycle_id)
    
    if not cycle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Cycle {cycle_id} not found")
    
    return cycle


@router.get("/", response_model=List[CycleRead])
def list_cycles(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """List all cycles (ordered by start_date descending)"""
    service = CycleService(db)
    return service.list_cycles(skip=skip, limit=limit)


@router.get("/status/{status}", response_model=List[CycleRead])
def get_cycles_by_status(status: CycleStatus, db: Session = Depends(get_db)):
    """Get cycles filtered by status"""
    service = CycleService(db)
    return service.get_cycles_by_status(status)


@router.get("/open/current", response_model=CycleRead)
def get_open_cycle(db: Session = Depends(get_db)):
    """Get the currently open cycle"""
    service = CycleService(db)
    cycle = service.get_open_cycle()
    
    if not cycle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No open cycle found")
    
    return cycle


@router.post("/{cycle_id}/transition", response_model=CycleRead)
def transition_cycle_status(cycle_id: int, cycle_update: CycleUpdate, db: Session = Depends(get_db)):
    """
    Transition cycle to a new status.
    
    Valid transitions:
    - OPEN → PENDING_REVIEW
    - PENDING_REVIEW → APPROVED
    - APPROVED → CLOSED
    - CLOSED → ARCHIVED
    """
    if not cycle_update.status:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Status is required")
    
    service = CycleService(db)
    cycle, error = service.transition_status(cycle_id, cycle_update.status)
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return cycle
