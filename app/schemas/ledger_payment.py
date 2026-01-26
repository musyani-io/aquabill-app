"""
Schemas for ledger entries, payments, and penalties.
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field
from app.models.ledger_entry import LedgerEntryType
from app.models.penalty import PenaltyStatus


# ============================================================================
# Ledger Entry Schemas
# ============================================================================

class LedgerEntryBase(BaseModel):
    """Base ledger entry attributes"""
    meter_assignment_id: int
    cycle_id: int
    entry_type: LedgerEntryType = LedgerEntryType.CHARGE
    amount: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    is_credit: bool = False
    description: str = Field(min_length=1, max_length=500)
    created_by: str = Field(min_length=1, max_length=100)


class LedgerEntryCreate(LedgerEntryBase):
    """Schema for creating ledger entries"""
    pass


class LedgerEntryRead(LedgerEntryBase):
    """Schema for reading ledger entries"""
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# Payment Schemas
# ============================================================================

class PaymentBase(BaseModel):
    """Base payment attributes"""
    meter_assignment_id: int
    cycle_id: Optional[int] = None
    amount: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    reference: Optional[str] = Field(None, max_length=100)
    method: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = Field(None, max_length=500)
    recorded_by: str = Field(min_length=1, max_length=100)


class PaymentCreate(PaymentBase):
    """Schema for creating payments"""
    pass


class PaymentRead(PaymentBase):
    """Schema for reading payments"""
    id: int
    client_id: int
    received_at: datetime
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# Penalty Schemas
# ============================================================================

class PenaltyBase(BaseModel):
    """Base penalty attributes"""
    meter_assignment_id: int
    cycle_id: Optional[int] = None
    amount: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    reason: str = Field(min_length=1, max_length=200)
    notes: Optional[str] = Field(None, max_length=500)
    imposed_by: str = Field(min_length=1, max_length=100)


class PenaltyCreate(PenaltyBase):
    """Schema for creating penalties"""
    pass


class PenaltyWaive(BaseModel):
    """Schema for waiving a penalty"""
    waived_by: str = Field(min_length=1, max_length=100)
    notes: Optional[str] = Field(None, max_length=500)


class PenaltyRead(PenaltyBase):
    """Schema for reading penalties"""
    id: int
    status: PenaltyStatus
    imposed_at: datetime
    waived_at: Optional[datetime] = None
    waived_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
