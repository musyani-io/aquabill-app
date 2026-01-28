from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint, func, Index, Numeric, ForeignKey
from sqlalchemy.orm import relationship

from app.db.base import Base


class Client(Base):
    __tablename__ = "clients"
    __table_args__ = (
        UniqueConstraint("phone_number", name="uq_clients_phone_number"),
        UniqueConstraint("client_code", name="uq_clients_client_code"),
        UniqueConstraint("meter_serial_number", name="uq_clients_meter_serial"),
        Index("ix_clients_name", "first_name", "surname"),
    )

    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(100), nullable=False)
    other_names = Column(String(100), nullable=True)
    surname = Column(String(100), nullable=False)
    phone_number = Column(String(20), nullable=False)
    client_code = Column(String(50), nullable=True)
    meter_serial_number = Column(String(50), nullable=False, unique=True)
    initial_meter_reading = Column(Numeric(precision=10, scale=4), nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
