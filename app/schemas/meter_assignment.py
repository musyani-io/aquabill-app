from datetime import date
from pydantic import BaseModel, Field


class MeterAssignmentBase(BaseModel):
    meter_id: int
    client_id: int
    start_date: date
    end_date: date | None = None
    status: str = Field(default="ACTIVE", pattern="^(ACTIVE|INACTIVE)$")


class MeterAssignmentCreate(BaseModel):
    meter_id: int
    client_id: int
    start_date: date


class MeterAssignmentUpdate(BaseModel):
    end_date: date | None = None
    status: str | None = Field(default=None, pattern="^(ACTIVE|INACTIVE)$")


class MeterAssignmentRead(MeterAssignmentBase):
    id: int

    class Config:
        from_attributes = True
