"""
Cycle schemas for API request/response validation.
"""

from datetime import date
from typing import Optional
from pydantic import BaseModel, Field, field_validator
from app.models.cycle import CycleStatus


class CycleBase(BaseModel):
    """Base cycle attributes"""

    start_date: date
    end_date: date
    target_date: date

    @field_validator("end_date")
    @classmethod
    def validate_end_after_start(cls, v, info):
        if "start_date" in info.data and v <= info.data["start_date"]:
            raise ValueError("end_date must be after start_date")
        return v

    @field_validator("target_date")
    @classmethod
    def validate_target_in_range(cls, v, info):
        if "start_date" in info.data and v < info.data["start_date"]:
            raise ValueError("target_date must be on or after start_date")
        if "end_date" in info.data and v > info.data["end_date"]:
            raise ValueError("target_date must be on or before end_date")
        return v


class CycleCreate(CycleBase):
    """Schema for creating a new cycle"""

    status: Optional[CycleStatus] = Field(default=CycleStatus.OPEN)


class CycleUpdate(BaseModel):
    """Schema for updating a cycle (primarily status transitions)"""

    status: Optional[CycleStatus] = None


class CycleRead(CycleBase):
    """Schema for reading cycle data"""

    id: int
    status: CycleStatus
    created_at: date
    updated_at: date

    class Config:
        from_attributes = True
