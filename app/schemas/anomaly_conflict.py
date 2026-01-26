"""
Anomaly and Conflict schemas for API request/response validation.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from app.models.anomaly import AnomalyType, AnomalyStatus
from app.models.conflict import ConflictType, ConflictStatus, ConflictSeverity


# ============================================================================
# ANOMALY SCHEMAS
# ============================================================================


class AnomalyBase(BaseModel):
    """Base anomaly attributes"""

    anomaly_type: AnomalyType
    description: str = Field(min_length=1, max_length=500)
    severity: str = Field(default="INFO")  # INFO, WARNING, CRITICAL


class AnomalyCreate(AnomalyBase):
    """Schema for creating an anomaly"""

    meter_assignment_id: int
    cycle_id: int
    reading_id: Optional[int] = None


class AnomalyAcknowledge(BaseModel):
    """Schema for acknowledging an anomaly"""

    acknowledged_by: str = Field(min_length=1, max_length=100)


class AnomalyResolve(BaseModel):
    """Schema for resolving an anomaly"""

    resolved_by: str = Field(min_length=1, max_length=100)
    resolution_notes: Optional[str] = Field(None, max_length=500)


class AnomalyRead(AnomalyBase):
    """Schema for reading anomaly data"""

    id: int
    meter_assignment_id: int
    cycle_id: int
    reading_id: Optional[int] = None
    status: AnomalyStatus
    created_at: datetime
    acknowledged_at: Optional[datetime] = None
    acknowledged_by: Optional[str] = None
    resolved_at: Optional[datetime] = None
    resolved_by: Optional[str] = None
    resolution_notes: Optional[str] = None
    updated_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# CONFLICT SCHEMAS
# ============================================================================


class ConflictBase(BaseModel):
    """Base conflict attributes"""

    conflict_type: ConflictType
    description: str = Field(min_length=1, max_length=500)
    severity: ConflictSeverity = ConflictSeverity.MEDIUM


class ConflictCreate(ConflictBase):
    """Schema for creating a conflict"""

    meter_assignment_id: int
    cycle_id: Optional[int] = None
    reading_id: Optional[int] = None


class ConflictAssign(BaseModel):
    """Schema for assigning a conflict to admin"""

    assigned_to: str = Field(
        min_length=1, max_length=100, description="Admin email or ID"
    )


class ConflictResolve(BaseModel):
    """Schema for resolving a conflict"""

    resolved_by: str = Field(min_length=1, max_length=100)
    resolution_notes: Optional[str] = Field(None, max_length=500)


class ConflictRead(ConflictBase):
    """Schema for reading conflict data"""

    id: int
    meter_assignment_id: int
    cycle_id: Optional[int] = None
    reading_id: Optional[int] = None
    status: ConflictStatus
    created_at: datetime
    assigned_to: Optional[str] = None
    assigned_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    resolved_by: Optional[str] = None
    resolution_notes: Optional[str] = None
    updated_at: datetime

    class Config:
        from_attributes = True
