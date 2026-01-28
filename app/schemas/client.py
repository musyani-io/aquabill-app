from pydantic import BaseModel, Field
from datetime import datetime
from decimal import Decimal


class ClientBase(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    other_names: str | None = Field(default=None, max_length=100)
    surname: str = Field(min_length=1, max_length=100)
    phone_number: str = Field(min_length=1, max_length=20)
    client_code: str | None = Field(default=None, max_length=50)
    meter_serial_number: str = Field(min_length=1, max_length=50)
    initial_meter_reading: Decimal = Field(decimal_places=4)


class ClientCreate(ClientBase):
    pass


class ClientUpdate(BaseModel):
    first_name: str | None = Field(default=None, max_length=100)
    other_names: str | None = Field(default=None, max_length=100)
    surname: str | None = Field(default=None, max_length=100)
    phone_number: str | None = Field(default=None, max_length=20)
    client_code: str | None = Field(default=None, max_length=50)
    meter_serial_number: str | None = Field(default=None, max_length=50)
    initial_meter_reading: float | None = Field(default=None, ge=0)


class ClientRead(ClientBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
