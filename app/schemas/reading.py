"""
Reading schemas for API request/response validation.
"""

from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, field_validator
from app.models.reading import ReadingType


class ReadingBase(BaseModel):
    """Base reading attributes"""

    absolute_value: Decimal = Field(ge=0, decimal_places=4, max_digits=9)
    type: ReadingType = ReadingType.NORMAL
    submitted_by: str = Field(min_length=1, max_length=100)
    submission_notes: Optional[str] = Field(None, max_length=500)


class ReadingCreate(ReadingBase):
    """Schema for submitting a new reading"""

    meter_assignment_id: int
    cycle_id: int


class ReadingApprove(BaseModel):
    """Schema for approving a reading and recording consumption"""

    approved_by: str = Field(min_length=1, max_length=100)
    approval_notes: Optional[str] = Field(None, max_length=500)


class ReadingUpdate(BaseModel):
    """Schema for updating reading (primarily approval)"""

    approved: Optional[bool] = None
    approval_notes: Optional[str] = Field(None, max_length=500)


class ReadingRead(ReadingBase):
    """Schema for reading reading data"""

    id: int
    meter_assignment_id: int
    cycle_id: int
    consumption: Optional[Decimal] = None
    has_rollover: bool
    approved: bool
    submitted_at: datetime
    approved_at: Optional[datetime] = None
    approved_by: Optional[str] = None
    approval_notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
