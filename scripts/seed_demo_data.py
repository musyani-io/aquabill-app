#!/usr/bin/env python
"""
Seed demo data for AquaBill development and testing.
"""

import sys
from datetime import datetime, timedelta

# Add backend to path
sys.path.insert(0, '/app')

from app.core.config import settings
from app.core.db import engine, SessionLocal
from app.models import (
    User, Client, Meter, MeterAssignment, Cycle, Reading,
    LedgerEntry, Payment, Alert, SmsLog, AuditLog
)
from app.core.security import get_password_hash
from sqlalchemy.orm import Session

def create_demo_data(db: Session):
    """Create demo data for testing."""
    
    # Create demo users
    admin_user = User(
        username="admin",
        email="admin@aquabill.local",
        password_hash=get_password_hash("admin123"),
        role="ADMIN",
        is_active=True
    )
    
    collector_user = User(
        username="collector1",
        email="collector1@aquabill.local",
        password_hash=get_password_hash("collector123"),
        role="COLLECTOR",
        is_active=True
    )
    
    db.add_all([admin_user, collector_user])
    db.flush()
    
    # Create demo clients
    clients = [
        Client(
            first_name="John",
            other_names="Michael",
            surname="Doe",
            phone_number="+255700000001"
        ),
        Client(
            first_name="Jane",
            other_names="Patricia",
            surname="Smith",
            phone_number="+255700000002"
        ),
        Client(
            first_name="Robert",
            surname="Johnson",
            phone_number="+255700000003"
        ),
    ]
    
    db.add_all(clients)
    db.flush()
    
    # Create demo meters
    meters = [
        Meter(serial_number="MTR-2024-001", max_reading=99999.9999),
        Meter(serial_number="MTR-2024-002", max_reading=99999.9999),
        Meter(serial_number="MTR-2024-003", max_reading=99999.9999),
    ]
    
    db.add_all(meters)
    db.flush()
    
    # Create meter assignments
    assignments = [
        MeterAssignment(
            meter_id=meters[0].id,
            client_id=clients[0].id,
            start_date=datetime.now().date()
        ),
        MeterAssignment(
            meter_id=meters[1].id,
            client_id=clients[1].id,
            start_date=datetime.now().date()
        ),
        MeterAssignment(
            meter_id=meters[2].id,
            client_id=clients[2].id,
            start_date=datetime.now().date()
        ),
    ]
    
    db.add_all(assignments)
    db.flush()
    
    # Create demo cycle
    today = datetime.now().date()
    cycle = Cycle(
        name="January 2024",
        start_date=today - timedelta(days=30),
        end_date=today + timedelta(days=5),
        status="OPEN"
    )
    
    db.add(cycle)
    db.flush()
    
    print("✓ Created demo admin user (username: admin, password: admin123)")
    print("✓ Created demo collector user (username: collector1, password: collector123)")
    print(f"✓ Created 3 demo clients")
    print(f"✓ Created 3 demo meters")
    print(f"✓ Created 3 meter assignments")
    print(f"✓ Created demo billing cycle")
    
    db.commit()

if __name__ == "__main__":
    print("=== AquaBill Demo Data Seeding ===\n")
    
    db = SessionLocal()
    try:
        create_demo_data(db)
        print("\n✓ Demo data created successfully!")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        db.rollback()
        sys.exit(1)
    finally:
        db.close()
