import enum
from sqlalchemy import Column, DateTime, Enum, ForeignKey, Integer, Date, CheckConstraint, func, Index
from sqlalchemy.orm import relationship

from app.db.base import Base


class AssignmentStatus(enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"


class MeterAssignment(Base):
    __tablename__ = "meter_assignments"
    __table_args__ = (
        CheckConstraint("start_date IS NOT NULL", name="ck_assignment_start_date"),
        CheckConstraint(
            "(end_date IS NULL AND status = 'ACTIVE') OR (end_date IS NOT NULL AND status = 'INACTIVE')",
            name="ck_assignment_active_no_end_date"
        ),
        Index("ix_meter_assignments_active", "meter_id", "status", unique=True, 
              postgresql_where="status = 'ACTIVE'"),
    )

    id = Column(Integer, primary_key=True, index=True)
    meter_id = Column(Integer, ForeignKey("meters.id", ondelete="RESTRICT"), nullable=False, index=True)
    client_id = Column(Integer, ForeignKey("clients.id", ondelete="RESTRICT"), nullable=False, index=True)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    status = Column(Enum(AssignmentStatus), nullable=False, default=AssignmentStatus.ACTIVE)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    meter = relationship("Meter", backref="assignments")
    client = relationship("Client", backref="meter_assignments")
