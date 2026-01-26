"""SMS schemas"""
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from typing import Optional, List
from app.models.sms import SMSStatus, SMSDeliveryStatus


class SMSDeliveryHistoryResponse(BaseModel):
    """Schema for SMS delivery history"""
    id: int
    sms_message_id: int
    attempt_number: int
    status: SMSDeliveryStatus
    gateway_name: Optional[str]
    callback_received: bool
    callback_status: Optional[str]
    attempted_at: datetime
    error_code: Optional[str]
    error_message: Optional[str]
    
    model_config = ConfigDict(from_attributes=True)


class SMSMessageBase(BaseModel):
    """Base schema for SMS"""
    phone_number: str = Field(..., max_length=20, description="Phone number to send SMS to")
    message_body: str = Field(..., description="SMS message content")
    sms_type: str = Field(..., max_length=50, description="Type of SMS (BALANCE_ALERT, PAYMENT_REMINDER, etc)")
    client_id: int = Field(..., description="Client ID")
    meter_assignment_id: Optional[int] = Field(None, description="Meter assignment ID")
    cycle_id: Optional[int] = Field(None, description="Cycle ID")


class SMSMessageCreate(SMSMessageBase):
    """Schema for creating SMS"""
    idempotency_key: str = Field(..., max_length=100, description="Unique key to prevent duplicates")
    metadata: Optional[str] = Field(None, description="JSON metadata")


class SMSMessageUpdate(BaseModel):
    """Schema for updating SMS (limited fields)"""
    status: Optional[SMSStatus] = None
    gateway_reference: Optional[str] = None
    gateway_response: Optional[str] = None
    error_reason: Optional[str] = None


class SMSMessageResponse(SMSMessageBase):
    """Schema for SMS response"""
    id: int
    idempotency_key: str
    status: SMSStatus
    retry_count: int
    max_retries: int
    last_attempt_at: Optional[datetime]
    next_retry_at: Optional[datetime]
    gateway_reference: Optional[str]
    created_at: datetime
    sent_at: Optional[datetime]
    error_reason: Optional[str]
    delivery_history: List[SMSDeliveryHistoryResponse] = []
    
    model_config = ConfigDict(from_attributes=True)
