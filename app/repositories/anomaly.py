"""
Anomaly repository - data access layer for billing anomalies.
"""

from datetime import datetime
from typing import List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from app.models.anomaly import Anomaly, AnomalyType, AnomalyStatus


class AnomalyRepository:
    """Repository for anomaly database operations"""

    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        anomaly_type: str,
        description: str,
        meter_assignment_id: int,
        cycle_id: int,
        reading_id: Optional[int] = None,
        severity: str = "INFO",
    ) -> Anomaly:
        """Create a new anomaly record"""
        anomaly = Anomaly(
            anomaly_type=anomaly_type,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity=severity,
        )
        self.db.add(anomaly)
        self.db.commit()
        self.db.refresh(anomaly)
        return anomaly

    def get(self, anomaly_id: int) -> Optional[Anomaly]:
        """Get anomaly by ID"""
        return self.db.query(Anomaly).filter(Anomaly.id == anomaly_id).first()

    def list(self, skip: int = 0, limit: int = 100) -> List[Anomaly]:
        """List all anomalies (newest first)"""
        return (
            self.db.query(Anomaly)
            .order_by(desc(Anomaly.created_at))
            .offset(skip)
            .limit(limit)
            .all()
        )

    def list_by_status(self, status: AnomalyStatus) -> List[Anomaly]:
        """Get anomalies with specific status"""
        return (
            self.db.query(Anomaly)
            .filter(Anomaly.status == status.value)
            .order_by(desc(Anomaly.created_at))
            .all()
        )

    def list_by_assignment(self, meter_assignment_id: int) -> List[Anomaly]:
        """Get all anomalies for a meter assignment"""
        return (
            self.db.query(Anomaly)
            .filter(Anomaly.meter_assignment_id == meter_assignment_id)
            .order_by(desc(Anomaly.created_at))
            .all()
        )

    def list_by_cycle(self, cycle_id: int) -> List[Anomaly]:
        """Get all anomalies for a cycle"""
        return (
            self.db.query(Anomaly)
            .filter(Anomaly.cycle_id == cycle_id)
            .order_by(desc(Anomaly.created_at))
            .all()
        )

    def acknowledge(self, anomaly_id: int, acknowledged_by: str) -> Optional[Anomaly]:
        """Acknowledge an anomaly"""
        anomaly = self.get(anomaly_id)
        if anomaly:
            anomaly.status = AnomalyStatus.ACKNOWLEDGED.value
            anomaly.acknowledged_at = datetime.utcnow()
            anomaly.acknowledged_by = acknowledged_by
            self.db.commit()
            self.db.refresh(anomaly)
        return anomaly

    def resolve(
        self, anomaly_id: int, resolved_by: str, resolution_notes: Optional[str] = None
    ) -> Optional[Anomaly]:
        """Resolve an anomaly"""
        anomaly = self.get(anomaly_id)
        if anomaly:
            anomaly.status = AnomalyStatus.RESOLVED.value
            anomaly.resolved_at = datetime.utcnow()
            anomaly.resolved_by = resolved_by
            anomaly.resolution_notes = resolution_notes
            self.db.commit()
            self.db.refresh(anomaly)
        return anomaly
