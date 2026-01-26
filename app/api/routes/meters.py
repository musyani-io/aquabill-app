from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.deps import get_db
from app.schemas.meter import MeterCreate, MeterRead, MeterUpdate
from app.services.meter_service import MeterService


router = APIRouter(prefix="/meters", tags=["meters"])


@router.post("/", response_model=MeterRead, status_code=status.HTTP_201_CREATED)
def create_meter(payload: MeterCreate, db: Session = Depends(get_db)):
    service = MeterService(db)
    return service.create(payload)


@router.get("/{meter_id}", response_model=MeterRead)
def get_meter(meter_id: int, db: Session = Depends(get_db)):
    service = MeterService(db)
    meter = service.get(meter_id)
    if meter is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Meter not found"
        )
    return meter


@router.get("/", response_model=list[MeterRead])
def list_meters(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    service = MeterService(db)
    return service.list(skip=skip, limit=limit)


@router.patch("/{meter_id}", response_model=MeterRead)
def update_meter(meter_id: int, payload: MeterUpdate, db: Session = Depends(get_db)):
    service = MeterService(db)
    meter = service.update(meter_id, payload)
    if meter is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Meter not found"
        )
    return meter


@router.delete("/{meter_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_meter(meter_id: int, db: Session = Depends(get_db)):
    service = MeterService(db)
    deleted = service.delete(meter_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Meter not found"
        )
    return None
