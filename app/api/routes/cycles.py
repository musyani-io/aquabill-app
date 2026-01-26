"""
Cycle API routes - billing cycle management endpoints.
"""
from typing import List
from datetime import date
from decimal import Decimal
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.schemas.cycle import CycleCreate, CycleRead, CycleUpdate
from app.services.cycle_service import CycleService
from app.models.cycle import CycleStatus


class ScheduleCyclesRequest(BaseModel):
    """Request to batch create cycles on schedule"""
    start_date: date
    num_cycles: int = Query(..., ge=1, le=24, description="Number of cycles to create (max 24)")
    cycle_length_days: int = Query(30, ge=1, le=365, description="Days per cycle")
    submission_window_days: int = Query(5, ge=0, le=30, description="Days after cycle end for reading submission")


class AutoTransitionRequest(BaseModel):
    """Request to auto-transition OPEN cycles"""
    cycle_id: int


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


@router.post("/schedule", response_model=List[CycleRead], status_code=status.HTTP_201_CREATED)
def schedule_cycles(
    request: ScheduleCyclesRequest,
    db: Session = Depends(get_db)
):
    """
    Batch create multiple billing cycles on schedule.
    
    SCHEDULER: Use this to create a series of cycles for the year.
    
    Example:
        POST /schedule
        {
            "start_date": "2026-01-01",
            "num_cycles": 12,
            "cycle_length_days": 30,
            "submission_window_days": 5
        }
    """
    service = CycleService(db)
    cycles, error = service.schedule_cycles(
        start_date=request.start_date,
        num_cycles=request.num_cycles,
        cycle_length_days=request.cycle_length_days,
        submission_window_days=request.submission_window_days
    )
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return cycles


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
    """Get the currently open cycle for reading submissions"""
    service = CycleService(db)
    cycle = service.get_open_cycle()
    
    if not cycle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No open cycle currently")
    
    return cycle


@router.get("/date/{check_date}", response_model=CycleRead)
def get_cycle_for_date(check_date: date, db: Session = Depends(get_db)):
    """Get the cycle that contains a given date"""
    service = CycleService(db)
    cycle = service.get_cycle_for_date(check_date)
    
    if not cycle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"No cycle found for date {check_date}")
    
    return cycle


@router.post("/{cycle_id}/auto-transition")
def auto_transition_on_deadline(cycle_id: int, db: Session = Depends(get_db)):
    """
    Auto-transition cycle from OPEN to PENDING_REVIEW when deadline passes.
    
    SCHEDULER: Call this for OPEN cycles where target_date has passed.
    This closes the reading submission window.
    """
    service = CycleService(db)
    cycle, error = service.auto_transition_on_deadline(cycle_id)
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return {
        "id": cycle.id,
        "status": cycle.status,
        "message": f"Cycle transitioned to {cycle.status}"
    }


@router.post("/auto-transition/overdue")
def auto_transition_overdue(db: Session = Depends(get_db)):
    """
    Auto-transition all OPEN cycles whose target_date has passed.
    Intended for a scheduled job (cron/k8s CronJob/etc.).
    """
    service = CycleService(db)
    transitioned, count = service.auto_transition_overdue()
    return {
        "updated_count": count,
        "updated_ids": [c.id for c in transitioned],
        "message": f"Auto-transitioned {count} overdue cycles to PENDING_REVIEW"
    }


@router.post("/{cycle_id}/charges")
def generate_cycle_charges(
    cycle_id: int,
    rate_per_m3: float = Query(..., gt=0, description="Tariff per m3"),
    created_by: str = Query("system", description="Username recording charges"),
    db: Session = Depends(get_db)
):
    """
    Generate CHARGE ledger entries for all approved readings in a cycle.
    Idempotent per meter_assignment+cycle (skips if a charge already exists).
    """
    service = CycleService(db)
    entries, summary_or_error = service.generate_cycle_charges(
        cycle_id=cycle_id,
        rate_per_m3=Decimal(str(rate_per_m3)),
        created_by=created_by
    )

    if "error" in summary_or_error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=summary_or_error["error"])

    return {
        "created_count": summary_or_error["created"],
        "skipped_existing": summary_or_error["skipped_existing"],
        "skipped_zero_amount": summary_or_error["skipped_zero_amount"],
        "entry_ids": [e.id for e in entries]
    }


@router.post("/{cycle_id}/transition", response_model=CycleRead)
def transition_cycle_status(cycle_id: int, cycle_update: CycleUpdate, db: Session = Depends(get_db)):
    """
    Manually transition cycle to a new status.
    
    Valid transitions:
    - OPEN → PENDING_REVIEW
    - PENDING_REVIEW → APPROVED
    - APPROVED → CLOSED
    - CLOSED → ARCHIVED
    
    Note: For auto-transition on deadline, use /{cycle_id}/auto-transition
    """
    if not cycle_update.status:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Status is required")
    
    service = CycleService(db)
    cycle, error = service.transition_status(cycle_id, cycle_update.status)
    
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    
    return cycle
