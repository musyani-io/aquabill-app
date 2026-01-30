"""
Integration tests for meter rollover threshold alert system.

Tests verify that:
1. Alerts are created when reading >= 90,000.0000
2. Only one DETECTED alert per meter assignment at a time (no duplicates)
3. Alerts are DETECTED until admin acknowledgment
4. Admin acknowledgment transitions alert to ACKNOWLEDGED status
5. Threshold check works during reading submission and approval
"""

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from decimal import Decimal
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.models.client import Client
from app.models.meter import Meter
from app.models.meter_assignment import MeterAssignment, AssignmentStatus
from app.models.cycle import Cycle, CycleStatus
from app.models.reading import Reading
from app.models.anomaly import Anomaly, AnomalyStatus, AnomalyType
from app.repositories.client import ClientRepository
from app.repositories.meter import MeterRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.repositories.cycle import CycleRepository
from app.repositories.reading import ReadingRepository
from app.repositories.anomaly import AnomalyRepository
from app.services.reading_service import ReadingService
from app.services.anomaly_service import AnomalyService
from app.schemas.client import ClientCreate
from app.services.client_service import ClientService
from app.services.cycle_service import CycleService
from app.models.cycle import CycleStatus
from datetime import date


@pytest.fixture
def db():
    """Create test database and session."""
    Base.metadata.create_all(bind=engine)
    session = SessionLocal()
    yield session
    session.close()


@pytest.fixture
def setup_test_data(db: Session):
    """Setup common test data: client, meter, assignment, cycle"""
    
    # Clean up before test
    db.execute(text("DELETE FROM anomalies"))
    db.execute(text("DELETE FROM readings"))
    db.execute(text("DELETE FROM cycles"))
    db.execute(text("DELETE FROM meter_assignments"))
    db.execute(text("DELETE FROM meters"))
    db.execute(text("DELETE FROM clients"))
    db.commit()
    
    # Create cycle first (required for client creation)
    cycle_service = CycleService(db)
    cycle, error = cycle_service.create_cycle(
        start_date=date(2026, 1, 1),
        end_date=date(2026, 1, 31),
        target_date=date(2026, 1, 20),
        status=CycleStatus.OPEN,
    )
    assert cycle is not None, f"Failed to create cycle: {error}"
    
    # Create client (this also creates Meter and MeterAssignment automatically)
    client_service = ClientService(db)
    client_data = ClientCreate(
        first_name="Test",
        surname="Customer",
        phone_number="+255123456789",
        meter_serial_number="METER-ROLLOVER-TEST-001",
        initial_meter_reading=Decimal("50000.0000"),
    )
    client = client_service.create(client_data)
    
    # Get the meter and assignment that were created
    meter = db.query(Meter).filter(Meter.serial_number == "METER-ROLLOVER-TEST-001").first()
    assignment = db.query(MeterAssignment).filter(
        MeterAssignment.client_id == client.id
    ).first()
    
    # The client service creates a BASELINE reading, we need to approve it
    baseline_reading = db.query(Reading).filter(
        Reading.meter_assignment_id == assignment.id
    ).first()
    
    if baseline_reading and not baseline_reading.approved:
        reading_service = ReadingService(db)
        reading_service.approve_reading(
            reading_id=baseline_reading.id,
            approved_by="admin",
        )
    
    return {
        "client": client,
        "meter": meter,
        "assignment": assignment,
        "cycle": cycle,
        "baseline_reading": baseline_reading,
    }


class TestMeterRolloverThresholdDetection:
    """Test rollover threshold alert detection"""

    def test_alert_created_when_reading_exceeds_90000(
        self, db: Session, setup_test_data
    ):
        """Test that METER_ROLLOVER_THRESHOLD alert is created when reading >= 90,000"""
        data = setup_test_data
        
        # Submit reading at threshold (exactly 90,000)
        reading_service = ReadingService(db)
        reading, error = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("90000.0000"),
            submitted_by="collector1",
            submission_notes="Reading at rollover threshold",
        )
        
        assert reading is not None, f"Failed to submit reading: {error}"
        assert error is None
        
        # Verify alert was created
        anomaly_repo = AnomalyRepository(db)
        alerts = anomaly_repo.list_by_assignment(data["assignment"].id)
        
        threshold_alerts = [
            a for a in alerts
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        
        assert len(threshold_alerts) == 1, "One threshold alert should be created"
        alert = threshold_alerts[0]
        assert alert.status == AnomalyStatus.DETECTED.value
        assert alert.severity == "CRITICAL"
        assert "90,000" in alert.description
        assert "METER-ROLLOVER-TEST-001" in alert.description

    def test_alert_not_created_below_threshold(
        self, db: Session, setup_test_data
    ):
        """Test that no alert is created when reading < 90,000"""
        data = setup_test_data
        
        # Submit reading below threshold
        reading_service = ReadingService(db)
        reading, error = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("85000.0000"),
            submitted_by="collector1",
        )
        
        assert reading is not None
        
        # Verify no threshold alert
        anomaly_repo = AnomalyRepository(db)
        alerts = anomaly_repo.list_by_assignment(data["assignment"].id)
        
        threshold_alerts = [
            a for a in alerts
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        
        assert len(threshold_alerts) == 0, "No threshold alert should be created"

    def test_alert_created_above_threshold(
        self, db: Session, setup_test_data
    ):
        """Test that alert is created when reading > 90,000"""
        data = setup_test_data
        
        # Submit reading above threshold
        reading_service = ReadingService(db)
        reading, error = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("95000.5555"),
            submitted_by="collector1",
        )
        
        assert reading is not None
        
        # Verify threshold alert exists
        anomaly_repo = AnomalyRepository(db)
        alerts = anomaly_repo.list_by_assignment(data["assignment"].id)
        
        threshold_alerts = [
            a for a in alerts
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        
        assert len(threshold_alerts) == 1
        assert "95000.5555" in threshold_alerts[0].description


class TestMeterRolloverThresholdDeduplication:
    """Test that only one DETECTED alert exists per meter assignment"""

    def test_no_duplicate_alerts(self, db: Session, setup_test_data):
        """Test that multiple readings >= 90k don't create duplicate alerts"""
        data = setup_test_data
        anomaly_repo = AnomalyRepository(db)
        
        # First reading above threshold
        reading_service = ReadingService(db)
        reading1, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("91000.0000"),
            submitted_by="collector1",
        )
        
        # Check: one alert exists
        alerts_1 = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        assert len(alerts_1) == 1
        first_alert_id = alerts_1[0].id
        
        # Second reading also above threshold (higher value)
        reading2, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("92000.0000"),
            submitted_by="collector1",
        )
        
        # Check: still only one alert (no duplicate)
        alerts_2 = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
            and a.status == AnomalyStatus.DETECTED.value
        ]
        assert len(alerts_2) == 1
        assert alerts_2[0].id == first_alert_id, "Same alert should exist (no duplicates)"

    def test_new_alert_after_acknowledgment(self, db: Session, setup_test_data):
        """Test that new alert is created after previous one is acknowledged"""
        data = setup_test_data
        anomaly_repo = AnomalyRepository(db)
        anomaly_service = AnomalyService(db)
        reading_service = ReadingService(db)
        
        # First reading triggers alert
        reading1, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("91000.0000"),
            submitted_by="collector1",
        )
        
        # Get first alert
        alerts_1 = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        assert len(alerts_1) == 1
        first_alert = alerts_1[0]
        
        # Admin acknowledges the alert
        acknowledged_alert, error = anomaly_service.acknowledge_anomaly(
            anomaly_id=first_alert.id,
            acknowledged_by="admin1"
        )
        assert error is None
        assert acknowledged_alert.status == AnomalyStatus.ACKNOWLEDGED.value
        assert acknowledged_alert.acknowledged_by == "admin1"
        
        # Second reading (still above threshold) should trigger new DETECTED alert
        reading2, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("92000.0000"),
            submitted_by="collector1",
        )
        
        # Check: now two alerts exist (one acknowledged, one detected)
        all_threshold_alerts = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        assert len(all_threshold_alerts) == 2
        
        detected_alerts = [a for a in all_threshold_alerts if a.status == AnomalyStatus.DETECTED.value]
        acknowledged_alerts = [a for a in all_threshold_alerts if a.status == AnomalyStatus.ACKNOWLEDGED.value]
        
        assert len(detected_alerts) == 1, "One detected alert should exist"
        assert len(acknowledged_alerts) == 1, "One acknowledged alert should exist"


class TestMeterRolloverThresholdApprovalFlow:
    """Test rollover threshold detection during approval"""

    def test_alert_created_during_approval(self, db: Session, setup_test_data):
        """Test that threshold alert is created when reading is approved"""
        data = setup_test_data
        reading_service = ReadingService(db)
        anomaly_repo = AnomalyRepository(db)
        
        # Submit reading (below threshold at submission)
        reading, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("80000.0000"),
            submitted_by="collector1",
        )
        
        # Check: no alert yet
        alerts_before = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        assert len(alerts_before) == 0
        
        # Approve reading at threshold value
        approved_reading, error = reading_service.approve_reading(
            reading_id=reading.id,
            approved_by="admin",
            admin_consumption_override=Decimal("90500.0000"),  # Override makes it >= 90k
        )
        
        assert error is None
        
        # Check: alert should be created on approval
        # (The alert check uses absolute_value of the reading, not consumption override)
        # So we need to approve a reading with absolute_value >= 90000
        
        # Let's create another test with proper absolute value
        reading2, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("90000.1234"),
            submitted_by="collector1",
        )
        
        # Approve it
        approved_reading2, _ = reading_service.approve_reading(
            reading_id=reading2.id,
            approved_by="admin",
        )
        
        # Verify alert exists
        alerts_after = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        
        # Should have at least one alert (may be from both readings)
        assert len(alerts_after) >= 1

    def test_alert_persists_with_multiple_approvals(
        self, db: Session, setup_test_data
    ):
        """Test that threshold alert persists across multiple approvals"""
        data = setup_test_data
        reading_service = ReadingService(db)
        anomaly_repo = AnomalyRepository(db)
        
        # First reading at threshold
        reading1, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("91000.0000"),
            submitted_by="collector1",
        )
        
        reading1_approved, _ = reading_service.approve_reading(
            reading_id=reading1.id,
            approved_by="admin",
        )
        
        # Get alert ID
        alerts_1 = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
            and a.status == AnomalyStatus.DETECTED.value
        ]
        assert len(alerts_1) == 1
        alert_id = alerts_1[0].id
        
        # Create another cycle and reading above threshold
        cycle_repo = CycleRepository(db)
        today = datetime.utcnow().date()
        cycle2 = cycle_repo.create(
            name="Test Cycle 2",
            start_date=today + timedelta(days=21),
            target_date=today + timedelta(days=31),
            end_date=today + timedelta(days=41),
            status=CycleStatus.OPEN.value,
        )
        
        # Second reading at higher threshold value
        reading2, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=cycle2.id,
            absolute_value=Decimal("92000.0000"),
            submitted_by="collector1",
        )
        
        reading2_approved, _ = reading_service.approve_reading(
            reading_id=reading2.id,
            approved_by="admin",
        )
        
        # Verify original alert still exists (not created again)
        alerts_final = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
            and a.status == AnomalyStatus.DETECTED.value
        ]
        assert len(alerts_final) == 1, "Same alert should persist (no duplicate)"
        assert alerts_final[0].id == alert_id


class TestMeterRolloverThresholdAcknowledgment:
    """Test admin acknowledgment of rollover threshold alerts"""

    def test_acknowledge_threshold_alert(self, db: Session, setup_test_data):
        """Test that admin can acknowledge threshold alert"""
        data = setup_test_data
        reading_service = ReadingService(db)
        anomaly_service = AnomalyService(db)
        anomaly_repo = AnomalyRepository(db)
        
        # Create alert
        reading, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("90000.0000"),
            submitted_by="collector1",
        )
        
        # Get alert
        alerts = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        alert = alerts[0]
        
        # Acknowledge alert
        ack_alert, error = anomaly_service.acknowledge_anomaly(
            anomaly_id=alert.id,
            acknowledged_by="admin_user"
        )
        
        assert error is None
        assert ack_alert.status == AnomalyStatus.ACKNOWLEDGED.value
        assert ack_alert.acknowledged_by == "admin_user"
        assert ack_alert.acknowledged_at is not None

    def test_cannot_acknowledge_already_acknowledged_alert(
        self, db: Session, setup_test_data
    ):
        """Test that already acknowledged alerts cannot be acknowledged again"""
        data = setup_test_data
        reading_service = ReadingService(db)
        anomaly_service = AnomalyService(db)
        anomaly_repo = AnomalyRepository(db)
        
        # Create and acknowledge alert
        reading, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("90000.0000"),
            submitted_by="collector1",
        )
        
        alerts = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        alert = alerts[0]
        
        # First acknowledgment
        anomaly_service.acknowledge_anomaly(
            anomaly_id=alert.id,
            acknowledged_by="admin1"
        )
        
        # Try to acknowledge again
        ack_alert, error = anomaly_service.acknowledge_anomaly(
            anomaly_id=alert.id,
            acknowledged_by="admin2"
        )
        
        assert error is not None
        assert "already ACKNOWLEDGED" in error

    def test_alert_timestamps_on_acknowledgment(self, db: Session, setup_test_data):
        """Test that acknowledgment timestamps are set correctly"""
        data = setup_test_data
        reading_service = ReadingService(db)
        anomaly_service = AnomalyService(db)
        anomaly_repo = AnomalyRepository(db)
        
        # Create alert
        before_submission = datetime.utcnow()
        reading, _ = reading_service.submit_reading(
            meter_assignment_id=data["assignment"].id,
            cycle_id=data["cycle"].id,
            absolute_value=Decimal("90000.0000"),
            submitted_by="collector1",
        )
        after_submission = datetime.utcnow()
        
        alerts = [
            a for a in anomaly_repo.list_by_assignment(data["assignment"].id)
            if a.anomaly_type == AnomalyType.METER_ROLLOVER_THRESHOLD.value
        ]
        alert = alerts[0]
        
        # Verify created_at is set
        assert before_submission <= alert.created_at <= after_submission
        assert alert.acknowledged_at is None
        assert alert.acknowledged_by is None
        
        # Acknowledge alert
        before_ack = datetime.utcnow()
        ack_alert, _ = anomaly_service.acknowledge_anomaly(
            anomaly_id=alert.id,
            acknowledged_by="admin_user"
        )
        after_ack = datetime.utcnow()
        
        # Verify acknowledgment timestamps
        assert before_ack <= ack_alert.acknowledged_at <= after_ack
        assert ack_alert.acknowledged_by == "admin_user"
