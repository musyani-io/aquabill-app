"""Audit log schemas"""

from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from typing import Optional
from app.models.audit_log import AuditAction


class AuditLogBase(BaseModel):
    """Base schema for audit log"""

    admin_username: str = Field(
        ..., max_length=100, description="Username of admin who performed action"
    )
    admin_id: Optional[str] = Field(None, max_length=100, description="Admin user ID")
    action: AuditAction = Field(..., description="Type of action performed")
    entity_type: str = Field(..., max_length=50, description="Type of entity affected")
    entity_id: int = Field(..., description="ID of affected entity")
    description: str = Field(..., description="Human-readable description of action")
    metadata: Optional[str] = Field(
        None, description="JSON metadata with additional context"
    )
    ip_address: Optional[str] = Field(
        None, max_length=45, description="IP address of admin"
    )


class AuditLogCreate(AuditLogBase):
    """Schema for creating audit log entries"""

    pass


class AuditLogResponse(AuditLogBase):
    """Schema for audit log responses"""

    id: int
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)
