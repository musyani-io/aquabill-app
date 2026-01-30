"""
Anomaly service - business logic for anomaly tracking and audit trail.
"""

from typing import List, Optional, Tuple
from decimal import Decimal
from sqlalchemy.orm import Session
from app.models.anomaly import Anomaly, AnomalyStatus, AnomalyType
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
        severity: str = "INFO",
    ) -> Anomaly:
        """Create and log an anomaly"""
        return self.repository.create(
            anomaly_type=anomaly_type,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity=severity,
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

    def acknowledge_anomaly(
        self, anomaly_id: int, acknowledged_by: str
    ) -> Tuple[Optional[Anomaly], Optional[str]]:
        """Acknowledge an anomaly"""
        anomaly = self.repository.get(anomaly_id)
        if not anomaly:
            return None, f"Anomaly {anomaly_id} not found"

        if anomaly.status != AnomalyStatus.DETECTED.value:
            return None, f"Anomaly {anomaly_id} is already {anomaly.status}"

        updated = self.repository.acknowledge(anomaly_id, acknowledged_by)
        return updated, None

    def resolve_anomaly(
        self, anomaly_id: int, resolved_by: str, resolution_notes: Optional[str] = None
    ) -> Tuple[Optional[Anomaly], Optional[str]]:
        """Resolve an anomaly"""
        anomaly = self.repository.get(anomaly_id)
        if not anomaly:
            return None, f"Anomaly {anomaly_id} not found"

        if anomaly.status == AnomalyStatus.RESOLVED.value:
            return None, f"Anomaly {anomaly_id} is already resolved"

        updated = self.repository.resolve(anomaly_id, resolved_by, resolution_notes)
        return updated, None

    def log_negative_consumption(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        reading_id: int,
        current_reading: Decimal,
        previous_reading: Decimal,
        consumption: Decimal,
    ) -> Anomaly:
        """
        Log negative consumption anomaly (potential rollover).
        Called automatically during consumption calculation.
        """
        description = (
            f"Negative consumption detected: {consumption:.2f} m³. "
            f"Current: {current_reading:.2f}, Previous: {previous_reading:.2f}. "
            f"Possible meter rollover."
        )
        return self.create_anomaly(
            anomaly_type=AnomalyType.NEGATIVE_CONSUMPTION.value,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity="WARNING",
        )

    def log_rollover_without_limit(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        reading_id: int,
        meter_serial: str,
    ) -> Anomaly:
        """
        Log rollover detected but meter max digits unknown.
        Admin needs to verify and update meter max_digits.
        """
        description = (
            f"Rollover detected for meter {meter_serial} but max_digits not configured. "
            f"Unable to calculate correct consumption. Admin verification required."
        )
        return self.create_anomaly(
            anomaly_type=AnomalyType.ROLLOVER_WITHOUT_LIMIT.value,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity="CRITICAL",
        )

    def log_double_submission(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        reading_id: int,
        existing_reading_id: int,
    ) -> Anomaly:
        """
        Log multiple reading submissions in same cycle.
        """
        description = (
            f"Multiple readings submitted for same cycle. "
            f"Existing: reading_id={existing_reading_id}, New: reading_id={reading_id}. "
            f"Review which reading is correct."
        )
        return self.create_anomaly(
            anomaly_type=AnomalyType.DOUBLE_SUBMISSION.value,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity="WARNING",
        )

    def log_late_submission(
        self, meter_assignment_id: int, cycle_id: int, reading_id: int, days_late: int
    ) -> Anomaly:
        """
        Log reading submitted after cycle deadline.
        """
        description = (
            f"Reading submitted {days_late} days after cycle deadline. "
            f"Late submission may affect billing accuracy."
        )
        return self.create_anomaly(
            anomaly_type=AnomalyType.LATE_SUBMISSION.value,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity="INFO",
        )

    def log_missing_baseline(
        self, meter_assignment_id: int, cycle_id: int, meter_serial: str
    ) -> Anomaly:
        """
        Log missing baseline reading for meter.
        """
        description = (
            f"No baseline reading found for meter {meter_serial}. "
            f"Cannot calculate consumption. Baseline reading required."
        )
        return self.create_anomaly(
            anomaly_type=AnomalyType.MISSING_BASELINE.value,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            severity="CRITICAL",
        )

    def log_meter_rollover_threshold(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        reading_id: int,
        meter_serial: str,
        absolute_value: Decimal,
    ) -> Anomaly:
        """
        Log meter reading approaching rollover threshold (>= 90,000).
        
        Alert persists until acknowledged by admin or meter is replaced.
        Admin acknowledgment indicates awareness and planning for meter replacement.
        
        Args:
            meter_assignment_id: Current meter assignment
            cycle_id: Cycle where threshold was reached
            reading_id: Reading that triggered the alert
            meter_serial: Meter serial number for identification
            absolute_value: Current meter reading value
        
        Returns:
            Created anomaly record with CRITICAL severity
        """
        description = (
            f"Meter {meter_serial} has reached rollover threshold alert at {absolute_value:.4f} m³ "
            f"(threshold: 90,000.0000). Meter approaching maximum capacity. "
            f"Admin acknowledgment required to confirm awareness and plan for meter replacement."
        )
        return self.create_anomaly(
            anomaly_type=AnomalyType.METER_ROLLOVER_THRESHOLD.value,
            description=description,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            severity="CRITICAL",
        )

    def check_and_log_rollover_threshold(
        self,
        meter_assignment_id: int,
        cycle_id: int,
        reading_id: int,
        meter_serial: str,
        absolute_value: Decimal,
        threshold: Decimal = Decimal("90000.0000"),
    ) -> Optional[Anomaly]:
        """
        Check if reading exceeds rollover threshold and log alert if needed.
        
        Only creates ONE alert per meter assignment until acknowledged.
        If an unacknowledged alert already exists, returns None (no duplicate).
        
        Args:
            meter_assignment_id: Current meter assignment
            cycle_id: Cycle where reading was submitted
            reading_id: Reading ID that triggered check
            meter_serial: Meter serial for identification
            absolute_value: Current meter reading value
            threshold: Rollover warning threshold (default: 90,000)
        
        Returns:
            Anomaly if alert was created, None if below threshold or alert already exists
        """
        # Check if reading exceeds threshold
        if absolute_value < threshold:
            return None

        # Check for existing unacknowledged alert
        existing_alert = self.repository.get_unacknowledged_threshold_alert(
            meter_assignment_id
        )
        if existing_alert:
            # Alert already exists, don't create duplicate
            return None

        # Create new alert
        return self.log_meter_rollover_threshold(
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id,
            reading_id=reading_id,
            meter_serial=meter_serial,
            absolute_value=absolute_value,
        )
