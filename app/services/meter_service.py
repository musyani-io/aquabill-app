from sqlalchemy.orm import Session

from app.models.meter import Meter
from app.repositories.meter import MeterRepository
from app.schemas.meter import MeterCreate, MeterUpdate


class MeterService:
    def __init__(self, db: Session):
        self.repo = MeterRepository(db)

    def create(self, data: MeterCreate) -> Meter:
        return self.repo.create(data)

    def get(self, meter_id: int) -> Meter | None:
        return self.repo.get(meter_id)

    def get_by_serial(self, serial_number: str) -> Meter | None:
        return self.repo.get_by_serial(serial_number)

    def list(self, skip: int = 0, limit: int = 50) -> list[Meter]:
        return self.repo.list(skip=skip, limit=limit)

    def update(self, meter_id: int, data: MeterUpdate) -> Meter | None:
        meter = self.repo.get(meter_id)
        if meter is None:
            return None
        return self.repo.update(meter, data)

    def delete(self, meter_id: int) -> bool:
        meter = self.repo.get(meter_id)
        if meter is None:
            return False
        self.repo.delete(meter)
        return True
