"""
Anomaly and Conflict API routes.
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.schemas.anomaly_conflict import (
    AnomalyRead, AnomalyCreate, AnomalyAcknowledge, AnomalyResolve,
    ConflictRead, ConflictCreate, ConflictAssign, ConflictResolve
)
from app.services.anomaly_service import AnomalyService
from app.services.conflict_service import ConflictService
from app.models.anomaly import AnomalyStatus
from app.models.conflict import ConflictStatus

router = APIRouter(prefix="/issues", tags=["issues"])


# ============================================================================
# ANOMALY ENDPOINTS
# ============================================================================

@router.post("/anomalies", response_model=AnomalyRead, status_code=status.HTTP_201_CREATED)
def create_anomaly(anomaly_data: AnomalyCreate, db: Session = Depends(get_db)):
    """Log an anomaly (system use or manual)"""
    service = AnomalyService(db)
    anomaly = service.create_anomaly(
        anomaly_type=anomaly_data.anomaly_type.value,
        description=anomaly_data.description,
        meter_assignment_id=anomaly_data.meter_assignment_id,
        cycle_id=anomaly_data.cycle_id,
        reading_id=anomaly_data.reading_id,
        severity=anomaly_data.severity
    )
    return anomaly


@router.get("/anomalies/{anomaly_id}", response_model=AnomalyRead)
def get_anomaly(anomaly_id: int, db: Session = Depends(get_db)):
    """Get anomaly by ID"""
    service = AnomalyService(db)
    anomaly = service.get_anomaly(anomaly_id)
    if not anomaly:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Anomaly {anomaly_id} not found")
    return anomaly


@router.get("/anomalies", response_model=List[AnomalyRead])
def list_anomalies(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """List all anomalies (newest first)"""
    service = AnomalyService(db)
    return service.list_anomalies(skip, limit)


@router.get("/anomalies/status/{status}", response_model=List[AnomalyRead])
def get_anomalies_by_status(status: AnomalyStatus, db: Session = Depends(get_db)):
    """Get anomalies filtered by status"""
    service = AnomalyService(db)
    return service.list_anomalies_by_status(status)


@router.get("/anomalies/assignment/{meter_assignment_id}", response_model=List[AnomalyRead])
def get_anomalies_by_assignment(meter_assignment_id: int, db: Session = Depends(get_db)):
    """Get anomalies for a meter assignment"""
    service = AnomalyService(db)
    return service.list_anomalies_by_assignment(meter_assignment_id)


@router.post("/anomalies/{anomaly_id}/acknowledge", response_model=AnomalyRead)
def acknowledge_anomaly(anomaly_id: int, ack_data: AnomalyAcknowledge, db: Session = Depends(get_db)):
    """Admin acknowledges an anomaly"""
    service = AnomalyService(db)
    anomaly, error = service.acknowledge_anomaly(anomaly_id, ack_data.acknowledged_by)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return anomaly


@router.post("/anomalies/{anomaly_id}/resolve", response_model=AnomalyRead)
def resolve_anomaly(anomaly_id: int, resolve_data: AnomalyResolve, db: Session = Depends(get_db)):
    """Admin resolves an anomaly"""
    service = AnomalyService(db)
    anomaly, error = service.resolve_anomaly(anomaly_id, resolve_data.resolved_by, resolve_data.resolution_notes)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return anomaly


# ============================================================================
# CONFLICT ENDPOINTS
# ============================================================================

@router.post("/conflicts", response_model=ConflictRead, status_code=status.HTTP_201_CREATED)
def create_conflict(conflict_data: ConflictCreate, db: Session = Depends(get_db)):
    """Create a conflict requiring admin resolution"""
    service = ConflictService(db)
    conflict = service.create_conflict(
        conflict_type=conflict_data.conflict_type.value,
        description=conflict_data.description,
        meter_assignment_id=conflict_data.meter_assignment_id,
        cycle_id=conflict_data.cycle_id,
        reading_id=conflict_data.reading_id,
        severity=conflict_data.severity.value
    )
    return conflict


@router.get("/conflicts/{conflict_id}", response_model=ConflictRead)
def get_conflict(conflict_id: int, db: Session = Depends(get_db)):
    """Get conflict by ID"""
    service = ConflictService(db)
    conflict = service.get_conflict(conflict_id)
    if not conflict:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Conflict {conflict_id} not found")
    return conflict


@router.get("/conflicts", response_model=List[ConflictRead])
def list_conflicts(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """List all conflicts (newest first)"""
    service = ConflictService(db)
    return service.list_conflicts(skip, limit)


@router.get("/conflicts/status/{status}", response_model=List[ConflictRead])
def get_conflicts_by_status(status: ConflictStatus, db: Session = Depends(get_db)):
    """Get conflicts filtered by status"""
    service = ConflictService(db)
    return service.list_conflicts_by_status(status)


@router.get("/conflicts/assignment/{meter_assignment_id}", response_model=List[ConflictRead])
def get_conflicts_by_assignment(meter_assignment_id: int, db: Session = Depends(get_db)):
    """Get conflicts for a meter assignment"""
    service = ConflictService(db)
    return service.list_conflicts_by_assignment(meter_assignment_id)


@router.get("/conflicts/admin/{admin_id}", response_model=List[ConflictRead])
def get_conflicts_by_admin(admin_id: str, db: Session = Depends(get_db)):
    """Get conflicts assigned to an admin"""
    service = ConflictService(db)
    return service.list_conflicts_by_admin(admin_id)


@router.post("/conflicts/{conflict_id}/assign", response_model=ConflictRead)
def assign_conflict(conflict_id: int, assign_data: ConflictAssign, db: Session = Depends(get_db)):
    """Assign a conflict to an admin for resolution"""
    service = ConflictService(db)
    conflict, error = service.assign_conflict(conflict_id, assign_data.assigned_to)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return conflict


@router.post("/conflicts/{conflict_id}/resolve", response_model=ConflictRead)
def resolve_conflict(conflict_id: int, resolve_data: ConflictResolve, db: Session = Depends(get_db)):
    """Admin resolves a conflict"""
    service = ConflictService(db)
    conflict, error = service.resolve_conflict(conflict_id, resolve_data.resolved_by, resolve_data.resolution_notes)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return conflict


@router.post("/conflicts/{conflict_id}/archive", response_model=ConflictRead)
def archive_conflict(conflict_id: int, db: Session = Depends(get_db)):
    """Archive a resolved conflict"""
    service = ConflictService(db)
    conflict, error = service.archive_conflict(conflict_id)
    if error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return conflict
