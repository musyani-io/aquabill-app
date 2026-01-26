"""
Anomaly service - business logic for anomaly tracking and audit trail.
"""
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.anomaly import Anomaly, AnomalyStatus
from app.repositories.anomaly import AnomalyRepository


class AnomalyService:
    """Service layer for anomaly operations"""
    
    def __init__(self, db: Session):
        self.repository = AnomalyRepository(db)
    
    def create_anomaly(
        self,
        anomaly_type: str,
        description: str,
        meter_assignment_id: int,
        cycle_id: int,
        reading_id: Optional[int] = None,
        severity: str = "INFO"
    ) -> Anomaly:
        """Create and log an anomaly"""
        return self.repository.create(
            anomaly_type=anomaly_type,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity=severity
        )
    
    def get_anomaly(self, anomaly_id: int) -> Optional[Anomaly]:
        """Get anomaly by ID"""
        return self.repository.get(anomaly_id)
    
    def list_anomalies(self, skip: int = 0, limit: int = 100) -> List[Anomaly]:
        """List all anomalies"""
        return self.repository.list(skip, limit)
    
    def list_anomalies_by_status(self, status: AnomalyStatus) -> List[Anomaly]:
        """Get anomalies with specific status"""
        return self.repository.list_by_status(status)
    
    def list_anomalies_by_assignment(self, meter_assignment_id: int) -> List[Anomaly]:
        """Get anomalies for a meter assignment"""
        return self.repository.list_by_assignment(meter_assignment_id)
    
    def list_anomalies_by_cycle(self, cycle_id: int) -> List[Anomaly]:
        """Get anomalies for a cycle"""
        return self.repository.list_by_cycle(cycle_id)
    
    def acknowledge_anomaly(self, anomaly_id: int, acknowledged_by: str) -> Tuple[Optional[Anomaly], Optional[str]]:
        """Acknowledge an anomaly"""
        anomaly = self.repository.get(anomaly_id)
        if not anomaly:
            return None, f"Anomaly {anomaly_id} not found"
        
        if anomaly.status != AnomalyStatus.DETECTED.value:
            return None, f"Anomaly {anomaly_id} is already {anomaly.status}"
        
        updated = self.repository.acknowledge(anomaly_id, acknowledged_by)
        return updated, None
    
    def resolve_anomaly(
        self,
        anomaly_id: int,
        resolved_by: str,
        resolution_notes: Optional[str] = None
    ) -> Tuple[Optional[Anomaly], Optional[str]]:
        """Resolve an anomaly"""
        anomaly = self.repository.get(anomaly_id)
        if not anomaly:
            return None, f"Anomaly {anomaly_id} not found"
        
        if anomaly.status == AnomalyStatus.RESOLVED.value:
            return None, f"Anomaly {anomaly_id} is already resolved"
        
        updated = self.repository.resolve(anomaly_id, resolved_by, resolution_notes)
        return updated, None
