"""Audit log repository - read-only operations (append-only table)"""
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.models.audit_log import AuditLog, AuditAction
from app.schemas.audit_log import AuditLogCreate


class AuditLogRepository:
    """
    Repository for audit log operations.
    
    CRITICAL: Only provides create() and read operations.
    NO update() or delete() methods - audit logs are immutable.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def create(self, audit_log: AuditLogCreate) -> AuditLog:
        """
        Create a new audit log entry.
        This is the ONLY write operation allowed on audit logs.
        """
        db_audit_log = AuditLog(**audit_log.model_dump())
        self.db.add(db_audit_log)
        self.db.commit()
        self.db.refresh(db_audit_log)
        return db_audit_log
    
    def get_by_id(self, audit_log_id: int) -> Optional[AuditLog]:
        """Get audit log by ID"""
        return self.db.query(AuditLog).filter(AuditLog.id == audit_log_id).first()
    
    def get_all(self, skip: int = 0, limit: int = 100) -> List[AuditLog]:
        """Get all audit logs with pagination, newest first"""
        return (
            self.db.query(AuditLog)
            .order_by(desc(AuditLog.timestamp))
            .offset(skip)
            .limit(limit)
            .all()
        )
    
    def get_by_admin(self, admin_username: str, skip: int = 0, limit: int = 100) -> List[AuditLog]:
        """Get audit logs for specific admin"""
        return (
            self.db.query(AuditLog)
            .filter(AuditLog.admin_username == admin_username)
            .order_by(desc(AuditLog.timestamp))
            .offset(skip)
            .limit(limit)
            .all()
        )
    
    def get_by_action(self, action: AuditAction, skip: int = 0, limit: int = 100) -> List[AuditLog]:
        """Get audit logs by action type"""
        return (
            self.db.query(AuditLog)
            .filter(AuditLog.action == action)
            .order_by(desc(AuditLog.timestamp))
            .offset(skip)
            .limit(limit)
            .all()
        )
    
    def get_by_entity(
        self, 
        entity_type: str, 
        entity_id: int, 
        skip: int = 0, 
        limit: int = 100
    ) -> List[AuditLog]:
        """Get audit logs for specific entity"""
        return (
            self.db.query(AuditLog)
            .filter(
                AuditLog.entity_type == entity_type,
                AuditLog.entity_id == entity_id
            )
            .order_by(desc(AuditLog.timestamp))
            .offset(skip)
            .limit(limit)
            .all()
        )
