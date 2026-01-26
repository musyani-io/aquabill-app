from sqlalchemy.orm import Session

from app.models.meter import Meter
from app.schemas.meter import MeterCreate, MeterUpdate


class MeterRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, data: MeterCreate) -> Meter:
        obj = Meter(**data.model_dump())
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def get(self, meter_id: int) -> Meter | None:
        return self.db.get(Meter, meter_id)

    def get_by_serial(self, serial_number: str) -> Meter | None:
        return self.db.query(Meter).filter(Meter.serial_number == serial_number).first()

    def list(self, skip: int = 0, limit: int = 50) -> list[Meter]:
        return (
            self.db.query(Meter)
            .order_by(Meter.serial_number)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def update(self, meter: Meter, data: MeterUpdate) -> Meter:
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(meter, field, value)
        self.db.add(meter)
        self.db.commit()
        self.db.refresh(meter)
        return meter

    def delete(self, meter: Meter) -> None:
        self.db.delete(meter)
        self.db.commit()
