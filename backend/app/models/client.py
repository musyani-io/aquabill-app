"""Client model."""

from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime
from . import Base


class Client(Base):
    """Client model for water service customers."""
    
    __tablename__ = "clients"
    
    id = Column(Integer, primary_key=True)
    first_name = Column(String(100), nullable=False)
    other_names = Column(String(100), nullable=True)
    surname = Column(String(100), nullable=False)
    phone_number = Column(String(20), nullable=False, index=True)
    client_code = Column(String(50), unique=True, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f"<Client {self.first_name} {self.surname}>"
