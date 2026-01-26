"""SMS service"""
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from app.repositories.sms import SMSRepository
from app.schemas.sms import SMSMessageCreate, SMSMessageUpdate, SMSMessageResponse
from app.models.sms import SMSStatus, SMSDeliveryStatus


class SMSService:
    """Service for SMS operations"""
    
    def __init__(self, db: Session):
        self.repository = SMSRepository(db)
    
    def queue_sms(self, sms: SMSMessageCreate) -> SMSMessageResponse:
        """Queue new SMS for sending"""
        db_sms = self.repository.create(sms)
        return SMSMessageResponse.model_validate(db_sms)
    
    def get_sms(self, sms_id: int) -> Optional[SMSMessageResponse]:
        """Get SMS by ID"""
        db_sms = self.repository.get_by_id(sms_id)
        if db_sms:
            return SMSMessageResponse.model_validate(db_sms)
        return None
    
    def get_all_sms(self, skip: int = 0, limit: int = 100) -> List[SMSMessageResponse]:
        """Get all SMS with pagination"""
        db_sms_list = self.repository.get_all(skip, limit)
        return [SMSMessageResponse.model_validate(sms) for sms in db_sms_list]
    
    def get_pending_sms(self, skip: int = 0, limit: int = 100) -> List[SMSMessageResponse]:
        """Get pending SMS (not yet sent)"""
        db_sms_list = self.repository.get_pending(skip, limit)
        return [SMSMessageResponse.model_validate(sms) for sms in db_sms_list]
    
    def get_retry_scheduled(self, skip: int = 0, limit: int = 100) -> List[SMSMessageResponse]:
        """Get SMS ready for retry (for scheduler)"""
        db_sms_list = self.repository.get_retry_scheduled(skip, limit)
        return [SMSMessageResponse.model_validate(sms) for sms in db_sms_list]
    
    def get_sms_by_client(self, client_id: int, skip: int = 0, limit: int = 100) -> List[SMSMessageResponse]:
        """Get SMS for specific client"""
        db_sms_list = self.repository.get_by_client(client_id, skip, limit)
        return [SMSMessageResponse.model_validate(sms) for sms in db_sms_list]
    
    def get_sms_by_phone(self, phone_number: str, skip: int = 0, limit: int = 100) -> List[SMSMessageResponse]:
        """Get SMS for specific phone number"""
        db_sms_list = self.repository.get_by_phone(phone_number, skip, limit)
        return [SMSMessageResponse.model_validate(sms) for sms in db_sms_list]
    
    def check_idempotency(self, idempotency_key: str) -> Optional[SMSMessageResponse]:
        """Check if SMS already queued with this key (prevent duplicates)"""
        db_sms = self.repository.get_by_idempotency_key(idempotency_key)
        if db_sms:
            return SMSMessageResponse.model_validate(db_sms)
        return None
    
    def record_sent(self, sms_id: int, gateway_reference: str) -> Optional[SMSMessageResponse]:
        """Record that SMS was sent to gateway"""
        update = SMSMessageUpdate(
            status=SMSStatus.SENT,
            gateway_reference=gateway_reference
        )
        db_sms = self.repository.update(sms_id, update)
        if db_sms:
            db_sms.last_attempt_at = datetime.utcnow()
            db_sms.sent_at = datetime.utcnow()
            db_sms.retry_count += 1
            return SMSMessageResponse.model_validate(db_sms)
        return None
    
    def record_failed(self, sms_id: int, error_reason: str) -> Optional[SMSMessageResponse]:
        """Record that SMS sending failed"""
        db_sms = self.repository.get_by_id(sms_id)
        if db_sms:
            db_sms.last_attempt_at = datetime.utcnow()
            db_sms.error_reason = error_reason
            
            # If we have retries left, schedule next retry
            if db_sms.retry_count < db_sms.max_retries:
                db_sms.status = SMSStatus.PENDING
                db_sms.calculate_next_retry()
            else:
                db_sms.status = SMSStatus.FAILED
            
            self.repository.db.add(db_sms)
            self.repository.db.commit()
            self.repository.db.refresh(db_sms)
            return SMSMessageResponse.model_validate(db_sms)
        return None
    
    def record_delivery_attempt(
        self,
        sms_id: int,
        gateway_name: str,
        gateway_response: Optional[str] = None,
        error_code: Optional[str] = None,
        error_message: Optional[str] = None
    ) -> Optional[SMSMessageResponse]:
        """Record individual delivery attempt"""
        db_sms = self.repository.get_by_id(sms_id)
        if db_sms:
            attempt_number = db_sms.retry_count
            status = SMSDeliveryStatus.SENT if not error_code else SMSDeliveryStatus.FAILED
            
            self.repository.add_delivery_history(
                sms_id=sms_id,
                attempt_number=attempt_number,
                status=status,
                gateway_name=gateway_name,
                gateway_response=gateway_response,
                error_code=error_code,
                error_message=error_message
            )
            return SMSMessageResponse.model_validate(db_sms)
        return None
    
    def process_callback(
        self,
        gateway_reference: str,
        callback_status: str
    ) -> Optional[SMSMessageResponse]:
        """Process SMS gateway callback (delivered/failed/bounced)"""
        # Find SMS by gateway reference
        db_sms = self.repository.db.query(self.repository.db.query(SMSMessage).filter(
            SMSMessage.gateway_reference == gateway_reference
        ).first())
        
        if db_sms:
            return SMSMessageResponse.model_validate(
                self.repository.record_callback(db_sms.id, callback_status, gateway_reference)
            )
        return None
