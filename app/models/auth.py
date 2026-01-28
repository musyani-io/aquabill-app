from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, func
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base import Base


class AdminUser(Base):
    """Admin user account"""

    __tablename__ = "admin_users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    company_name = Column(String(255), nullable=False)
    company_phone = Column(String(20), nullable=False)
    role_at_company = Column(String(100), nullable=False)
    estimated_clients = Column(Integer, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationship to collectors
    collectors = relationship(
        "CollectorUser", back_populates="admin", cascade="all, delete-orphan"
    )


class CollectorUser(Base):
    """Collector field worker account"""

    __tablename__ = "collector_users"

    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(
        Integer,
        ForeignKey("admin_users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationship back to admin
    admin = relationship("AdminUser", back_populates="collectors")
