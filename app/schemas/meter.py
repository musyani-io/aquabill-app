from pydantic import BaseModel, Field


class MeterBase(BaseModel):
    serial_number: str = Field(min_length=1, max_length=50)


class MeterCreate(MeterBase):
    pass


class MeterUpdate(BaseModel):
    serial_number: str | None = Field(default=None, max_length=50)


class MeterRead(MeterBase):
    id: int

    class Config:
        from_attributes = True
