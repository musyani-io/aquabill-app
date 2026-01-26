"""
Billing API routes - ledger entries, payments, and penalties.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.schemas.ledger_payment import (
    LedgerEntryCreate,
    LedgerEntryRead,
    PaymentCreate,
    PaymentRead,
    PenaltyCreate,
    PenaltyWaive,
    PenaltyRead,
)
from app.services.ledger_service import LedgerService
from app.services.payment_service import PaymentService
from app.services.penalty_service import PenaltyService
from app.models.ledger_entry import LedgerEntryType

router = APIRouter(prefix="/billing", tags=["billing"])


# ---------------------------------------------------------------------------
# Ledger endpoints
# ---------------------------------------------------------------------------

@router.post("/ledger", response_model=LedgerEntryRead, status_code=status.HTTP_201_CREATED)
def create_ledger_entry(entry_data: LedgerEntryCreate, db: Session = Depends(get_db)):
    service = LedgerService(db)
    entry, error = service.create_entry(
        meter_assignment_id=entry_data.meter_assignment_id,
        cycle_id=entry_data.cycle_id,
        entry_type=entry_data.entry_type,
        amount=entry_data.amount,
        is_credit=entry_data.is_credit,
        description=entry_data.description,
        created_by=entry_data.created_by,
    )
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return entry


@router.get("/ledger/{entry_id}", response_model=LedgerEntryRead)
def get_ledger_entry(entry_id: int, db: Session = Depends(get_db)):
    service = LedgerService(db)
    entry = service.get_entry(entry_id)
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Ledger entry {entry_id} not found")
    return entry


@router.get("/ledger", response_model=List[LedgerEntryRead])
def list_ledger_entries(
    skip: int = 0,
    limit: int = 100,
    meter_assignment_id: Optional[int] = None,
    cycle_id: Optional[int] = None,
    db: Session = Depends(get_db),
):
    service = LedgerService(db)
    if meter_assignment_id is not None:
        return service.list_entries_by_assignment(meter_assignment_id)
    if cycle_id is not None:
        return service.list_entries_by_cycle(cycle_id)
    return service.list_entries(skip, limit)


# ---------------------------------------------------------------------------
# Payment endpoints
# ---------------------------------------------------------------------------

@router.post("/payments", response_model=PaymentRead, status_code=status.HTTP_201_CREATED)
def create_payment(payment_data: PaymentCreate, db: Session = Depends(get_db)):
    service = PaymentService(db)
    payment, error = service.create_payment(
        meter_assignment_id=payment_data.meter_assignment_id,
        cycle_id=payment_data.cycle_id,
        amount=payment_data.amount,
        reference=payment_data.reference,
        method=payment_data.method,
        notes=payment_data.notes,
        recorded_by=payment_data.recorded_by,
    )
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return payment


@router.get("/payments/{payment_id}", response_model=PaymentRead)
def get_payment(payment_id: int, db: Session = Depends(get_db)):
    service = PaymentService(db)
    payment = service.get_payment(payment_id)
    if not payment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Payment {payment_id} not found")
    return payment


@router.get("/payments", response_model=List[PaymentRead])
def list_payments(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    service = PaymentService(db)
    return service.list_payments(skip, limit)


@router.get("/payments/assignment/{meter_assignment_id}", response_model=List[PaymentRead])
def list_payments_by_assignment(meter_assignment_id: int, db: Session = Depends(get_db)):
    service = PaymentService(db)
    return service.list_payments_by_assignment(meter_assignment_id)


@router.get("/payments/client/{client_id}", response_model=List[PaymentRead])
def list_payments_by_client(client_id: int, db: Session = Depends(get_db)):
    service = PaymentService(db)
    return service.list_payments_by_client(client_id)


# ---------------------------------------------------------------------------
# Penalty endpoints
# ---------------------------------------------------------------------------

@router.post("/penalties", response_model=PenaltyRead, status_code=status.HTTP_201_CREATED)
def create_penalty(penalty_data: PenaltyCreate, db: Session = Depends(get_db)):
    service = PenaltyService(db)
    penalty, error = service.create_penalty(
        meter_assignment_id=penalty_data.meter_assignment_id,
        cycle_id=penalty_data.cycle_id,
        amount=penalty_data.amount,
        reason=penalty_data.reason,
        notes=penalty_data.notes,
        imposed_by=penalty_data.imposed_by,
    )
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return penalty


@router.get("/penalties/{penalty_id}", response_model=PenaltyRead)
def get_penalty(penalty_id: int, db: Session = Depends(get_db)):
    service = PenaltyService(db)
    penalty = service.get_penalty(penalty_id)
    if not penalty:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Penalty {penalty_id} not found")
    return penalty


@router.get("/penalties", response_model=List[PenaltyRead])
def list_penalties(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    service = PenaltyService(db)
    return service.list_penalties(skip, limit)


@router.get("/penalties/assignment/{meter_assignment_id}", response_model=List[PenaltyRead])
def list_penalties_by_assignment(meter_assignment_id: int, db: Session = Depends(get_db)):
    service = PenaltyService(db)
    return service.list_penalties_by_assignment(meter_assignment_id)


@router.post("/penalties/{penalty_id}/waive", response_model=PenaltyRead)
def waive_penalty(penalty_id: int, waiver: PenaltyWaive, db: Session = Depends(get_db)):
    service = PenaltyService(db)
    penalty, error = service.waive_penalty(penalty_id, waiver.waived_by, waiver.notes)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return penalty
