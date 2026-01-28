"""SMS message and delivery tracking models"""

from datetime import datetime, timedelta
from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    Text,
    Enum as SQLEnum,
    ForeignKey,
    Boolean,
    NUMERIC,
    func,
)
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum
import uuid


class SMSStatus(str, enum.Enum):
    """Status of SMS message"""

    PENDING = "PENDING"  # Queued but not sent
    SENT = "SENT"  # Successfully delivered to gateway
    DELIVERED = "DELIVERED"  # Gateway confirmed delivery
    FAILED = "FAILED"  # Failed after max retries
    BOUNCED = "BOUNCED"  # Invalid number/unsubscribed


class SMSDeliveryStatus(str, enum.Enum):
    """Status of individual delivery attempt"""

    PENDING = "PENDING"  # Not yet attempted
    SENT = "SENT"  # Sent to gateway
    DELIVERED = "DELIVERED"  # Gateway confirmed
    FAILED = "FAILED"  # Gateway rejected
    RETRY_SCHEDULED = "RETRY_SCHEDULED"  # Waiting for retry window


class SMSMessage(Base):
    """
    SMS messages to be sent.

    CRITICAL: Uses idempotency_key to prevent duplicate sends on callback retries.
    Uses smart retry logic: immediate → 30min → 4hr (max 3 attempts).
    """

    __tablename__ = "sms_messages"

    id = Column(Integer, primary_key=True, index=True)

    # Idempotency for preventing duplicate sends
    idempotency_key = Column(String(100), unique=True, nullable=False, index=True)

    # Recipients and content
    phone_number = Column(String(20), nullable=False, index=True)
    message_body = Column(Text, nullable=False)

    # SMS type for categorization
    sms_type = Column(
        String(50), nullable=False
    )  # "BALANCE_ALERT", "PAYMENT_REMINDER", "READING_CONFIRMATION", etc.

    # Related entities
    client_id = Column(
        Integer,
        ForeignKey("clients.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    meter_assignment_id = Column(
        Integer, ForeignKey("meter_assignments.id", ondelete="SET NULL"), nullable=True
    )
    cycle_id = Column(
        Integer, ForeignKey("cycles.id", ondelete="SET NULL"), nullable=True
    )

    # Message status and retry logic
    status = Column(SQLEnum(SMSStatus), default=SMSStatus.PENDING, index=True)

    # Retry tracking
    retry_count = Column(Integer, default=0)  # 0, 1, 2 (max 3 attempts)
    max_retries = Column(Integer, default=3)
    last_attempt_at = Column(DateTime, nullable=True)
    next_retry_at = Column(DateTime, nullable=True, index=True)

    # Gateway and callback tracking
    gateway_reference = Column(
        String(100), nullable=True, unique=True
    )  # ID from SMS gateway
    gateway_response = Column(
        Text, nullable=True
    )  # Full gateway response for debugging

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    sent_at = Column(DateTime(timezone=True), nullable=True)

    # Metadata
    error_reason = Column(Text, nullable=True)  # Why it failed
    metadata_json = Column(
        "metadata", Text, nullable=True
    )  # JSON with additional context (rename attr to avoid reserved name)

    # Relationships
    client = relationship("Client", backref="sms_messages")
    meter_assignment = relationship("MeterAssignment", backref="sms_messages")
    cycle = relationship("Cycle", backref="sms_messages")
    delivery_history = relationship(
        "SMSDeliveryHistory", back_populates="sms_message", cascade="all, delete-orphan"
    )

    def should_retry(self) -> bool:
        """Check if SMS should be retried based on attempt count and time windows"""
        if self.status == SMSStatus.FAILED or self.retry_count >= self.max_retries:
            return False
        if self.next_retry_at and datetime.utcnow() >= self.next_retry_at:
            return True
        return False

    def calculate_next_retry(self):
        """Calculate when next retry should happen: immediate(0), 30min(1), 4hr(2)"""
        retry_delays = [
            timedelta(minutes=0),  # Immediate (before processing delay)
            timedelta(minutes=30),  # 30 minutes
            timedelta(hours=4),  # 4 hours
        ]
        if self.retry_count < len(retry_delays):
            self.next_retry_at = datetime.utcnow() + retry_delays[self.retry_count]

    def __repr__(self):
        return f"<SMSMessage(id={self.id}, to={self.phone_number}, status={self.status}, retries={self.retry_count}/{self.max_retries})>"


class SMSDeliveryHistory(Base):
    """
    Tracks each SMS delivery attempt for debugging and analytics.

    Keeps full history of:
    - When was it attempted
    - What was the response
    - Did it succeed/fail
    - Any error codes from gateway
    """

    __tablename__ = "sms_delivery_history"

    id = Column(Integer, primary_key=True, index=True)

    # Which SMS is this attempt for
    sms_message_id = Column(
        Integer,
        ForeignKey("sms_messages.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Attempt details
    attempt_number = Column(Integer, nullable=False)  # 1, 2, 3
    status = Column(
        SQLEnum(SMSDeliveryStatus), default=SMSDeliveryStatus.PENDING, index=True
    )

    # Gateway interaction
    gateway_name = Column(String(50), nullable=True)  # "Twilio", "AWS SNS", etc.
    gateway_request = Column(Text, nullable=True)  # Request body sent to gateway
    gateway_response = Column(Text, nullable=True)  # Response from gateway
    gateway_status_code = Column(Integer, nullable=True)  # HTTP status code

    # Callback tracking
    callback_received = Column(Boolean, default=False)
    callback_status = Column(
        String(50), nullable=True
    )  # "delivered", "failed", "bounced", etc.
    callback_received_at = Column(DateTime, nullable=True)

    # Timestamps
    attempted_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Error tracking
    error_code = Column(
        String(50), nullable=True
    )  # "INVALID_NUMBER", "THROTTLED", etc.
    error_message = Column(Text, nullable=True)

    # Relationships
    sms_message = relationship("SMSMessage", back_populates="delivery_history")

    def __repr__(self):
        return f"<SMSDeliveryHistory(sms_id={self.sms_message_id}, attempt={self.attempt_number}, status={self.status})>"
