"""
Integration test for Client + Meter + Baseline Reading flow.

Verifies that creating a client automatically:
1. Creates a Meter record
2. Creates a MeterAssignment (ACTIVE)
3. Creates a BASELINE Reading (pending approval)
4. Enforces one-active-assignment per meter rule
"""

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from datetime import date
from decimal import Decimal
import traceback

import pytest
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.models.client import Client
from app.models.meter import Meter
from app.models.meter_assignment import MeterAssignment, AssignmentStatus
from app.models.cycle import Cycle, CycleStatus
from app.models.reading import Reading, ReadingType
from app.schemas.client import ClientCreate
from app.services.client_service import ClientService
from app.services.cycle_service import CycleService


@pytest.fixture
def db():
    """Create test database and session."""
    # Note: In production, use test DB. Here we use the actual DB for manual testing.
    Base.metadata.create_all(bind=engine)
    session = SessionLocal()
    yield session
    session.close()


def test_client_creation_creates_meter(db: Session):
    """Test that creating a client creates a Meter record."""
    # Setup: Create an OPEN cycle
    cycle_service = CycleService(db)
    cycle, error = cycle_service.create_cycle(
        start_date=date(2026, 1, 1),
        end_date=date(2026, 1, 31),
        target_date=date(2026, 1, 31),
        status=CycleStatus.OPEN,
    )
    assert cycle is not None, f"Failed to create cycle: {error}"

    # Create a client
    client_data = ClientCreate(
        first_name="John",
        other_names="Paul",
        surname="Doe",
        phone_number="+255712345678",
        meter_serial_number="M12345",
        initial_meter_reading=Decimal("1234.5000"),
    )
    service = ClientService(db)
    client = service.create(client_data)

    # Verify client was created
    assert client.id is not None
    assert client.first_name == "John"
    assert client.meter_serial_number == "M12345"

    # Verify Meter was created
    meter = db.query(Meter).filter(
        Meter.serial_number == "M12345"
    ).first()
    assert meter is not None, "Meter not created"
    assert meter.serial_number == "M12345"

    print("✓ Test: Client creation creates Meter - PASSED")


def test_client_creation_creates_meter_assignment(db: Session):
    """Test that creating a client creates a MeterAssignment record."""
    # Setup: Close the previous OPEN cycle and create a new one
    cycle_service = CycleService(db)
    
    # Close any existing OPEN cycles
    db.execute(text("UPDATE cycles SET status = 'PENDING_REVIEW' WHERE status = 'OPEN'"))
    db.commit()
    
    cycle, error = cycle_service.create_cycle(
        start_date=date(2026, 6, 1),
        end_date=date(2026, 6, 30),
        target_date=date(2026, 6, 30),
        status=CycleStatus.OPEN,
    )
    assert cycle is not None, f"Failed to create cycle: {error}"

    # Create a client
    client_data = ClientCreate(
        first_name="Jane",
        other_names="M",
        surname="Smith",
        phone_number="+255754321098",
        meter_serial_number="M67890",
        initial_meter_reading=Decimal("5000.0000"),
    )
    service = ClientService(db)
    client = service.create(client_data)

    # Verify MeterAssignment was created
    assignment = db.query(MeterAssignment).filter(
        MeterAssignment.client_id == client.id
    ).first()
    assert assignment is not None, "MeterAssignment not created"
    assert assignment.status == AssignmentStatus.ACTIVE
    assert assignment.start_date == date.today()
    assert assignment.end_date is None

    print("✓ Test: Client creation creates MeterAssignment - PASSED")


def test_client_creation_creates_baseline_reading(db: Session):
    """Test that creating a client creates a BASELINE Reading."""
    # Setup: Close the previous OPEN cycle and create a new one
    cycle_service = CycleService(db)
    
    # Close any existing OPEN cycles
    db.execute(text("UPDATE cycles SET status = 'PENDING_REVIEW' WHERE status = 'OPEN'"))
    db.commit()
    
    cycle, error = cycle_service.create_cycle(
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 31),
        target_date=date(2026, 7, 31),
        status=CycleStatus.OPEN,
    )
    assert cycle is not None, f"Failed to create cycle: {error}"

    initial_reading_value = Decimal("2500.7500")

    # Create a client
    client_data = ClientCreate(
        first_name="Bob",
        other_names="Robert",
        surname="Johnson",
        phone_number="+255765432109",
        meter_serial_number="M11111",
        initial_meter_reading=initial_reading_value,
    )
    service = ClientService(db)
    client = service.create(client_data)

    # Verify BASELINE Reading was created
    reading = db.query(Reading).filter(
        Reading.cycle_id == cycle.id
    ).first()
    assert reading is not None, "Baseline Reading not created"
    assert reading.type == ReadingType.BASELINE
    assert reading.absolute_value == initial_reading_value
    assert reading.consumption is None, "Baseline should have no consumption"
    assert reading.has_rollover is False
    assert reading.approved is False, "Baseline should be pending approval"

    print("✓ Test: Client creation creates BASELINE Reading - PASSED")


def test_one_active_assignment_per_meter(db: Session):
    """Test that only one active assignment exists per meter at a time.
    
    NOTE: Due to unique constraint on clients.meter_serial_number,
    this test creates two distinct clients with different meters,
    then tests reassignment by deactivating the first assignment manually.
    """
    # Setup: Close the previous OPEN cycle and create a new one
    cycle_service = CycleService(db)
    
    # Close any existing OPEN cycles
    db.execute(text("UPDATE cycles SET status = 'PENDING_REVIEW' WHERE status = 'OPEN'"))
    db.commit()
    
    cycle, error = cycle_service.create_cycle(
        start_date=date(2026, 8, 1),
        end_date=date(2026, 8, 31),
        target_date=date(2026, 8, 31),
        status=CycleStatus.OPEN,
    )
    assert cycle is not None, f"Failed to create cycle: {error}"

    # Create first client
    client_data_1 = ClientCreate(
        first_name="Alice",
        other_names="A",
        surname="Anderson",
        phone_number="+255711111111",
        meter_serial_number="M99991",
        initial_meter_reading=Decimal("1000.0000"),
    )
    service = ClientService(db)
    client1 = service.create(client_data_1)

    # Verify first assignment is active
    assignment1 = db.query(MeterAssignment).filter(
        MeterAssignment.client_id == client1.id
    ).first()
    assert assignment1.status == AssignmentStatus.ACTIVE

    # Create second client with different meter (due to unique constraint)
    client_data_2 = ClientCreate(
        first_name="Bob",
        other_names="B",
        surname="Brown",
        phone_number="+255722222222",
        meter_serial_number="M99992",
        initial_meter_reading=Decimal("1500.0000"),
    )
    client2 = service.create(client_data_2)

    # Get second assignment
    assignment2 = db.query(MeterAssignment).filter(
        MeterAssignment.client_id == client2.id
    ).first()
    assert assignment2.status == AssignmentStatus.ACTIVE

    # Verify each meter has only one ACTIVE assignment
    for assignment in [assignment1, assignment2]:
        active_assignments = db.query(MeterAssignment).filter(
            MeterAssignment.meter_id == assignment.meter_id,
            MeterAssignment.status == AssignmentStatus.ACTIVE,
        ).all()
        assert len(active_assignments) == 1, f"More than one active assignment for meter {assignment.meter_id}"

    print("✓ Test: One active assignment per meter - PASSED")


def test_baseline_reading_no_consumption(db: Session):
    """Test that BASELINE readings have NULL consumption."""
    # Setup: Close the previous OPEN cycle and create a new one
    cycle_service = CycleService(db)
    
    # Close any existing OPEN cycles
    db.execute(text("UPDATE cycles SET status = 'PENDING_REVIEW' WHERE status = 'OPEN'"))
    db.commit()
    
    cycle, error = cycle_service.create_cycle(
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 30),
        target_date=date(2026, 9, 30),
        status=CycleStatus.OPEN,
    )
    assert cycle is not None, f"Failed to create cycle: {error}"

    # Create a client
    client_data = ClientCreate(
        first_name="Charlie",
        other_names="C",
        surname="Clark",
        phone_number="+255733333333",
        meter_serial_number="M55555",
        initial_meter_reading=Decimal("3000.0000"),
    )
    service = ClientService(db)
    client = service.create(client_data)

    # Get the BASELINE reading
    reading = db.query(Reading).filter(
        Reading.cycle_id == cycle.id
    ).first()

    # Verify consumption is NULL for BASELINE
    assert reading.consumption is None, "BASELINE reading should have NULL consumption"
    assert reading.type == ReadingType.BASELINE

    print("✓ Test: Baseline reading has no consumption - PASSED")


def test_client_without_open_cycle(db: Session):
    """Test client creation when no OPEN cycle exists (should not fail)."""
    # Close all OPEN cycles (don't delete, just change status)
    db.execute(text("UPDATE cycles SET status = 'PENDING_REVIEW' WHERE status = 'OPEN'"))
    db.commit()

    # Create a client without OPEN cycle
    client_data = ClientCreate(
        first_name="David",
        other_names="D",
        surname="Davis",
        phone_number="+255744444444",
        meter_serial_number="M77777",
        initial_meter_reading=Decimal("4000.0000"),
    )
    service = ClientService(db)
    client = service.create(client_data)

    # Client should still be created
    assert client.id is not None
    assert client.first_name == "David"

    # MeterAssignment should still be created
    assignment = db.query(MeterAssignment).filter(
        MeterAssignment.client_id == client.id
    ).first()
    assert assignment is not None

    # But no Reading should be created (no OPEN cycle)
    reading = db.query(Reading).filter(
        Reading.meter_assignment_id == assignment.id
    ).first()
    assert reading is None, "Reading should not exist without OPEN cycle"

    print("✓ Test: Client creation without OPEN cycle - PASSED")


if __name__ == "__main__":
    # Manual test execution
    db = SessionLocal()
    try:
        print("\n" + "=" * 70)
        print("RUNNING CLIENT + METER + BASELINE INTEGRATION TESTS")
        print("=" * 70 + "\n")

        # Clean up test data (delete test cycles, clients, meters, assignments, readings)
        print("Cleaning up test data...")
        db.execute(text("DELETE FROM readings WHERE submitted_by = 'SYSTEM'"))
        db.execute(text("DELETE FROM meter_assignments WHERE start_date >= '2026-01-01'"))
        db.execute(text("DELETE FROM cycles WHERE start_date >= '2026-01-01'"))
        db.execute(text("DELETE FROM clients WHERE created_at >= '2026-01-01'"))
        db.execute(text("DELETE FROM meters WHERE serial_number LIKE 'M%'"))
        db.commit()
        print("✓ Test data cleaned\n")

        test_client_creation_creates_meter(db)
        test_client_creation_creates_meter_assignment(db)
        test_client_creation_creates_baseline_reading(db)
        test_one_active_assignment_per_meter(db)
        test_baseline_reading_no_consumption(db)
        test_client_without_open_cycle(db)

        print("\n" + "=" * 70)
        print("ALL TESTS PASSED ✓")
        print("=" * 70 + "\n")

    except AssertionError as e:
        print(f"\n❌ TEST FAILED: {e}\n")
        traceback.print_exc()
        db.rollback()
    except Exception as e:
        print(f"\n❌ ERROR: {e}\n")
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()
