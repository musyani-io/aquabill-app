"""Audit log service"""

from typing import List, Optional
from sqlalchemy.orm import Session
from app.repositories.audit_log import AuditLogRepository
from app.schemas.audit_log import AuditLogCreate, AuditLogResponse
from app.models.audit_log import AuditAction


class AuditLogService:
    """Service for audit log operations"""

    def __init__(self, db: Session):
        self.repository = AuditLogRepository(db)

    def log_action(self, audit_log: AuditLogCreate) -> AuditLogResponse:
        """
        Log an admin action.
        This should be called after every significant admin operation.
        """
        db_audit_log = self.repository.create(audit_log)
        return AuditLogResponse.model_validate(db_audit_log)

    def get_audit_log(self, audit_log_id: int) -> Optional[AuditLogResponse]:
        """Get audit log by ID"""
        db_audit_log = self.repository.get_by_id(audit_log_id)
        if db_audit_log:
            return AuditLogResponse.model_validate(db_audit_log)
        return None

    def get_all_logs(self, skip: int = 0, limit: int = 100) -> List[AuditLogResponse]:
        """Get all audit logs with pagination"""
        db_audit_logs = self.repository.get_all(skip, limit)
        return [AuditLogResponse.model_validate(log) for log in db_audit_logs]

    def get_logs_by_admin(
        self, admin_username: str, skip: int = 0, limit: int = 100
    ) -> List[AuditLogResponse]:
        """Get audit logs for specific admin"""
        db_audit_logs = self.repository.get_by_admin(admin_username, skip, limit)
        return [AuditLogResponse.model_validate(log) for log in db_audit_logs]

    def get_logs_by_action(
        self, action: AuditAction, skip: int = 0, limit: int = 100
    ) -> List[AuditLogResponse]:
        """Get audit logs by action type"""
        db_audit_logs = self.repository.get_by_action(action, skip, limit)
        return [AuditLogResponse.model_validate(log) for log in db_audit_logs]

    def get_logs_by_entity(
        self, entity_type: str, entity_id: int, skip: int = 0, limit: int = 100
    ) -> List[AuditLogResponse]:
        """Get audit logs for specific entity (e.g., all logs for reading #123)"""
        db_audit_logs = self.repository.get_by_entity(
            entity_type, entity_id, skip, limit
        )
        return [AuditLogResponse.model_validate(log) for log in db_audit_logs]
