"""SMS repository"""

from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import and_
from app.models.sms import SMSMessage, SMSDeliveryHistory, SMSStatus
from app.schemas.sms import SMSMessageCreate, SMSMessageUpdate


class SMSRepository:
    """Repository for SMS operations"""

    def __init__(self, db: Session):
        self.db = db

    def create(self, sms: SMSMessageCreate) -> SMSMessage:
        """Create new SMS message"""
        db_sms = SMSMessage(**sms.model_dump())
        db_sms.calculate_next_retry()
        self.db.add(db_sms)
        self.db.commit()
        self.db.refresh(db_sms)
        return db_sms

    def get_by_id(self, sms_id: int) -> Optional[SMSMessage]:
        """Get SMS by ID"""
        return self.db.query(SMSMessage).filter(SMSMessage.id == sms_id).first()

    def get_by_idempotency_key(self, key: str) -> Optional[SMSMessage]:
        """Get SMS by idempotency key (prevent duplicates)"""
        return (
            self.db.query(SMSMessage).filter(SMSMessage.idempotency_key == key).first()
        )

    def get_all(self, skip: int = 0, limit: int = 100) -> List[SMSMessage]:
        """Get all SMS messages with pagination"""
        return self.db.query(SMSMessage).offset(skip).limit(limit).all()

    def get_by_status(
        self, status: SMSStatus, skip: int = 0, limit: int = 100
    ) -> List[SMSMessage]:
        """Get SMS messages by status"""
        return (
            self.db.query(SMSMessage)
            .filter(SMSMessage.status == status)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_pending(self, skip: int = 0, limit: int = 100) -> List[SMSMessage]:
        """Get pending SMS (not yet sent)"""
        return (
            self.db.query(SMSMessage)
            .filter(SMSMessage.status == SMSStatus.PENDING)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_retry_scheduled(self, skip: int = 0, limit: int = 100) -> List[SMSMessage]:
        """Get SMS ready for retry"""
        now = datetime.utcnow()
        return (
            self.db.query(SMSMessage)
            .filter(
                and_(
                    SMSMessage.status.in_([SMSStatus.PENDING, SMSStatus.FAILED]),
                    SMSMessage.next_retry_at <= now,
                    SMSMessage.retry_count < SMSMessage.max_retries,
                )
            )
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_by_client(
        self, client_id: int, skip: int = 0, limit: int = 100
    ) -> List[SMSMessage]:
        """Get SMS messages for specific client"""
        return (
            self.db.query(SMSMessage)
            .filter(SMSMessage.client_id == client_id)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_by_phone(
        self, phone_number: str, skip: int = 0, limit: int = 100
    ) -> List[SMSMessage]:
        """Get SMS messages for specific phone number"""
        return (
            self.db.query(SMSMessage)
            .filter(SMSMessage.phone_number == phone_number)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def update(self, sms_id: int, sms_update: SMSMessageUpdate) -> Optional[SMSMessage]:
        """Update SMS (status, gateway reference, etc)"""
        db_sms = self.get_by_id(sms_id)
        if db_sms:
            update_data = sms_update.model_dump(exclude_unset=True)
            for field, value in update_data.items():
                setattr(db_sms, field, value)
            self.db.add(db_sms)
            self.db.commit()
            self.db.refresh(db_sms)
        return db_sms

    def add_delivery_history(
        self,
        sms_id: int,
        attempt_number: int,
        status: str,
        gateway_name: Optional[str] = None,
        gateway_response: Optional[str] = None,
        error_code: Optional[str] = None,
        error_message: Optional[str] = None,
    ) -> SMSDeliveryHistory:
        """Record a delivery attempt"""
        history = SMSDeliveryHistory(
            sms_message_id=sms_id,
            attempt_number=attempt_number,
            status=status,
            gateway_name=gateway_name,
            gateway_response=gateway_response,
            error_code=error_code,
            error_message=error_message,
        )
        self.db.add(history)
        self.db.commit()
        self.db.refresh(history)
        return history

    def record_callback(
        self, sms_id: int, callback_status: str, gateway_reference: Optional[str] = None
    ) -> Optional[SMSMessage]:
        """Record SMS gateway callback"""
        db_sms = self.get_by_id(sms_id)
        if db_sms:
            # Find most recent delivery history
            latest_delivery = (
                self.db.query(SMSDeliveryHistory)
                .filter(SMSDeliveryHistory.sms_message_id == sms_id)
                .order_by(SMSDeliveryHistory.attempted_at.desc())
                .first()
            )
            if latest_delivery:
                latest_delivery.callback_received = True
                latest_delivery.callback_status = callback_status
                latest_delivery.callback_received_at = datetime.utcnow()
                self.db.add(latest_delivery)

            # Update SMS status based on callback
            if callback_status == "delivered":
                db_sms.status = SMSStatus.DELIVERED
            elif callback_status in ["failed", "bounced"]:
                db_sms.status = SMSStatus.FAILED

            self.db.add(db_sms)
            self.db.commit()
            self.db.refresh(db_sms)
        return db_sms
