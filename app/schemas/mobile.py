"""
Mobile API schemas for bootstrap, updates, and reading submission.
"""

from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List
from pydantic import BaseModel, Field
from app.schemas.client import ClientRead
from app.schemas.meter import MeterRead
from app.schemas.meter_assignment import MeterAssignmentRead
from app.schemas.cycle import CycleRead
from app.schemas.reading import ReadingRead


class MobileReadingSubmit(BaseModel):
    """Mobile reading submission with additional metadata"""

    meter_assignment_id: int = Field(..., description="Meter assignment ID")
    cycle_id: int = Field(..., description="Billing cycle ID")
    absolute_value: Decimal = Field(
        ..., ge=0, decimal_places=4, description="Meter reading in m³"
    )
    submitted_by: str = Field(
        ..., min_length=1, max_length=100, description="Collector ID/username"
    )
    submitted_at: datetime = Field(
        ..., description="Client-side timestamp (ISO8601 with timezone)"
    )
    client_tz: Optional[str] = Field(
        None, description="Client timezone (e.g., 'Africa/Dar_es_Salaam')"
    )
    source: str = Field(default="mobile", description="Source identifier")
    previous_approved_reading: Optional[Decimal] = Field(
        None, description="Previous approved reading displayed to collector"
    )
    device_id: Optional[str] = Field(None, description="Device/collector identifier")
    app_version: Optional[str] = Field(None, description="Mobile app version")
    conflict_id: Optional[int] = Field(
        None, description="Conflict ID if resubmitting after conflict"
    )
    submission_notes: Optional[str] = Field(
        None, max_length=500, description="Notes from collector"
    )


class MobileReadingResponse(BaseModel):
    """Response after mobile reading submission"""

    id: int
    meter_assignment_id: int
    cycle_id: int
    absolute_value: Decimal
    submitted_at: datetime
    submitted_by: str
    status: str = Field(description="PENDING, ACCEPTED, REJECTED, CONFLICT")
    message: Optional[str] = None

    class Config:
        from_attributes = True


class MobileConflictDetail(BaseModel):
    """Conflict response with server reading snapshot"""

    conflict_reason: str
    server_reading: Optional[ReadingRead] = None
    local_reading: MobileReadingSubmit


class TombstoneRecord(BaseModel):
    """Marker for deleted/closed entities"""

    entity_type: str = Field(description="cycle, assignment, etc.")
    entity_id: int
    action: str = Field(description="CLOSED, ARCHIVED, DEACTIVATED")
    timestamp: datetime


class MobileBootstrapResponse(BaseModel):
    """Full data snapshot for initial mobile sync"""

    assignments: List[MeterAssignmentRead]
    cycles: List[CycleRead]
    readings: List[ReadingRead]
    clients: List[ClientRead]
    meters: List[MeterRead]
    last_sync: datetime = Field(description="Server timestamp for this snapshot")


class MobileUpdatesResponse(BaseModel):
    """Incremental updates since last sync"""

    assignments: List[MeterAssignmentRead] = []
    cycles: List[CycleRead] = []
    readings: List[ReadingRead] = []
    clients: List[ClientRead] = []
    meters: List[MeterRead] = []
    tombstones: List[TombstoneRecord] = []
    last_sync: datetime = Field(description="Server timestamp for this delta")
