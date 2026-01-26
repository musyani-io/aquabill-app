"""Audit log API routes - read-only endpoints"""

from typing import List
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.services.audit_log_service import AuditLogService
from app.schemas.audit_log import AuditLogResponse
from app.models.audit_log import AuditAction

router = APIRouter()


@router.get("/", response_model=List[AuditLogResponse])
def get_audit_logs(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Max records to return"),
    db: Session = Depends(get_db),
):
    """
    Get all audit logs with pagination.
    Sorted by timestamp descending (newest first).
    """
    service = AuditLogService(db)
    return service.get_all_logs(skip, limit)


@router.get("/{audit_log_id}", response_model=AuditLogResponse)
def get_audit_log(audit_log_id: int, db: Session = Depends(get_db)):
    """Get specific audit log by ID"""
    service = AuditLogService(db)
    audit_log = service.get_audit_log(audit_log_id)
    if not audit_log:
        raise HTTPException(status_code=404, detail="Audit log not found")
    return audit_log


@router.get("/admin/{admin_username}", response_model=List[AuditLogResponse])
def get_logs_by_admin(
    admin_username: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    """Get all audit logs for specific admin user"""
    service = AuditLogService(db)
    return service.get_logs_by_admin(admin_username, skip, limit)


@router.get("/action/{action}", response_model=List[AuditLogResponse])
def get_logs_by_action(
    action: AuditAction,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    """Get all audit logs for specific action type"""
    service = AuditLogService(db)
    return service.get_logs_by_action(action, skip, limit)


@router.get("/entity/{entity_type}/{entity_id}", response_model=List[AuditLogResponse])
def get_logs_by_entity(
    entity_type: str,
    entity_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    """
    Get all audit logs for specific entity.
    Example: /entity/reading/123 returns all logs for reading #123
    """
    service = AuditLogService(db)
    return service.get_logs_by_entity(entity_type, entity_id, skip, limit)
