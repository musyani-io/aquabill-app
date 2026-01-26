"""Seed script to create demo users for testing."""

import sys
import os

# Add the backend directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from app.core.db import SessionLocal
from app.core.security import get_password_hash
from app.core.constants import UserRole
from app.models.user import User


def create_demo_users(db: Session):
    """Create demo admin and collector users."""
    
    # Check if users already exist
    existing_admin = db.query(User).filter(User.username == "admin").first()
    if existing_admin:
        print("Demo users already exist. Skipping...")
        return
    
    # Create admin user
    admin = User(
        username="admin",
        email="admin@aquabill.local",
        password_hash=get_password_hash("admin123"),
        role=UserRole.ADMIN,
        is_active=True
    )
    db.add(admin)
    print("✓ Created admin user (username: admin, password: admin123)")
    
    # Create collector user
    collector = User(
        username="collector1",
        email="collector1@aquabill.local",
        password_hash=get_password_hash("collector123"),
        role=UserRole.COLLECTOR,
        is_active=True
    )
    db.add(collector)
    print("✓ Created collector user (username: collector1, password: collector123)")
    
    db.commit()
    print("\n✅ Demo users created successfully!")
    print("\nLogin credentials:")
    print("  Admin: username=admin, password=admin123")
    print("  Collector: username=collector1, password=collector123")


def main():
    """Main function to run the seed script."""
    print("Creating demo users...\n")
    
    db = SessionLocal()
    try:
        create_demo_users(db)
    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    main()
