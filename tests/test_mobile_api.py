"""
Mobile API integration tests.
"""

import pytest
from datetime import datetime, timedelta, date
from decimal import Decimal
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.db.base import Base
from app.db.deps import get_db
from app.models.client import Client
from app.models.meter import Meter
from app.models.meter_assignment import MeterAssignment, AssignmentStatus
from app.models.cycle import Cycle, CycleStatus
from app.models.reading import Reading, ReadingType


# Test database setup
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///./test_mobile.db"
engine = create_engine(
    SQLALCHEMY_TEST_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(scope="function", autouse=True)
def setup_database():
    """Create tables before each test and drop after"""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def sample_data():
    """Populate database with sample data for testing"""
    db = TestingSessionLocal()

    # Create client
    test_client = Client(
        id=1,
        first_name="John",
        surname="Doe",
        phone_number="+255712345678",
    )
    db.add(test_client)

    # Create meter
    meter = Meter(id=1, serial_number="MTR-001")
    db.add(meter)

    # Create assignment
    assignment = MeterAssignment(
        id=1,
        meter_id=1,
        client_id=1,
        start_date=date.today() - timedelta(days=365),
        status=AssignmentStatus.ACTIVE,
    )
    db.add(assignment)

    # Create 3 cycles (12-cycle window for mobile)
    for i in range(3):
        start = date.today() - timedelta(days=90 * (3 - i))
        end = start + timedelta(days=30)
        target = end - timedelta(days=5)

        # Cycle 3 should be OPEN and within submission window (target_date in future)
        if i == 2:
            start = date.today() - timedelta(days=10)
            end = date.today() + timedelta(days=20)
            target = date.today() + timedelta(days=15)

        cycle = Cycle(
            id=i + 1,
            start_date=start,
            end_date=end,
            target_date=target,
            status=CycleStatus.OPEN.value if i == 2 else CycleStatus.CLOSED.value,
        )
        db.add(cycle)

    # Create baseline reading (required before any normal readings)
    baseline = Reading(
        id=1,
        meter_assignment_id=1,
        cycle_id=1,
        absolute_value=Decimal("1000.0000"),
        type=ReadingType.BASELINE.value,
        submitted_by="installer",
        submitted_at=datetime.utcnow(),
        approved=True,
        approved_by="admin",
        approved_at=datetime.utcnow(),
    )
    db.add(baseline)

    # Create normal reading for cycle 2
    reading2 = Reading(
        id=2,
        meter_assignment_id=1,
        cycle_id=2,
        absolute_value=Decimal("1500.0000"),
        type=ReadingType.NORMAL.value,
        submitted_by="collector1",
        submitted_at=datetime.utcnow(),
        consumption=Decimal("500.0000"),
        approved=True,
        approved_by="admin",
        approved_at=datetime.utcnow(),
    )
    db.add(reading2)

    db.commit()
    db.close()


def test_bootstrap_endpoint(sample_data):
    """Test bootstrap returns last 12 cycles + active assignments"""
    response = client.get("/api/v1/mobile/bootstrap")

    assert response.status_code == 200
    data = response.json()

    assert "assignments" in data
    assert "cycles" in data
    assert "readings" in data
    assert "clients" in data
    assert "meters" in data
    assert "last_sync" in data

    # Should have 1 active assignment
    assert len(data["assignments"]) == 1
    assert data["assignments"][0]["id"] == 1

    # Should have 3 cycles
    assert len(data["cycles"]) == 3

    # Should have 2 approved readings
    assert len(data["readings"]) == 2

    # Should have 1 client
    assert len(data["clients"]) == 1

    # Should have 1 meter
    assert len(data["meters"]) == 1


def test_updates_endpoint(sample_data):
    """Test incremental updates endpoint"""
    # Get initial bootstrap timestamp
    bootstrap_response = client.get("/api/v1/mobile/bootstrap")
    last_sync = bootstrap_response.json()["last_sync"]

    # Parse and subtract a small amount to ensure new reading is captured
    from datetime import datetime as dt
    import time

    time.sleep(0.2)  # Ensure time difference

    db = TestingSessionLocal()
    new_reading = Reading(
        id=3,
        meter_assignment_id=1,
        cycle_id=3,
        absolute_value=Decimal("2000.0000"),
        type=ReadingType.NORMAL.value,
        submitted_by="collector2",
        consumption=Decimal("500.0000"),
        approved=True,
        approved_by="admin",
        approved_at=datetime.utcnow(),
        submitted_at=datetime.utcnow(),
    )
    db.add(new_reading)
    db.commit()
    db.refresh(new_reading)
    db.close()

    # Get updates since bootstrap (use slightly earlier timestamp)
    since_param = dt.fromisoformat(last_sync.replace('Z', '+00:00')) - timedelta(seconds=1)
    response = client.get(f"/api/v1/mobile/updates?since={since_param.isoformat()}")

    assert response.status_code == 200
    data = response.json()

    # Should include the new reading
    assert len(data["readings"]) >= 1
    reading_ids = [r["id"] for r in data["readings"]]
    assert 3 in reading_ids


def test_mobile_reading_submission(sample_data):
    """Test mobile reading submission endpoint"""
    payload = {
        "meter_assignment_id": 1,
        "cycle_id": 3,
        "absolute_value": 2000.0,
        "submitted_by": "mobile_collector",
        "submitted_at": datetime.utcnow().isoformat() + "Z",
        "client_tz": "Africa/Dar_es_Salaam",
        "source": "mobile",
        "device_id": "device-123",
        "app_version": "1.0.0",
        "previous_approved_reading": 1500.0,  # Reference reading from cycle 2
        "submission_notes": "Test reading from mobile",
    }

    response = client.post("/api/v1/mobile/readings", json=payload)

    # Debug output
    if response.status_code != 201:
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")

    assert response.status_code == 201
    data = response.json()

    assert data["meter_assignment_id"] == 1
    assert data["cycle_id"] == 3
    assert data["status"] == "PENDING"
    assert "id" in data


def test_mobile_reading_conflict(sample_data):
    """Test conflict detection on duplicate submission"""
    # First submission
    payload = {
        "meter_assignment_id": 1,
        "cycle_id": 3,
        "absolute_value": 2000.0,
        "submitted_by": "mobile_collector",
        "submitted_at": datetime.utcnow().isoformat() + "Z",
        "source": "mobile",
        "previous_approved_reading": 1500.0,
    }

    response1 = client.post("/api/v1/mobile/readings", json=payload)
    assert response1.status_code == 201

    # Duplicate submission with different value should trigger conflict
    payload["absolute_value"] = 2100.0
    payload["submitted_by"] = "another_collector"  # Different collector
    response2 = client.post("/api/v1/mobile/readings", json=payload)

    # Should return 409 or 400 depending on validation
    # (current implementation returns 400 for duplicate; we'd enhance to 409)
    assert response2.status_code in [400, 409]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
