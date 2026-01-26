"""SMS service"""
from typing import List, Optional, Tuple
from datetime import datetime
from decimal import Decimal
import json
import uuid
from sqlalchemy.orm import Session
from app.repositories.sms import SMSRepository
from app.schemas.sms import SMSMessageCreate, SMSMessageUpdate, SMSMessageResponse
from app.models.sms import SMSMessage, SMSStatus, SMSDeliveryStatus
from app.services.textbee_client import TextBeeClient


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
        db_sms = self.repository.db.query(SMSMessage).filter(
            SMSMessage.gateway_reference == gateway_reference
        ).first()
        
        if db_sms:
            return SMSMessageResponse.model_validate(
                self.repository.record_callback(db_sms.id, callback_status, gateway_reference)
            )
        return None
    
    async def send_sms(self, sms_id: int) -> Tuple[bool, Optional[str]]:
        """
        Send SMS via TextBee gateway and record delivery attempt.
        Returns (success, error_message).
        """
        db_sms = self.repository.get_by_id(sms_id)
        if not db_sms:
            return False, f"SMS {sms_id} not found"
        
        if db_sms.status not in [SMSStatus.PENDING]:
            return False, f"SMS {sms_id} status is {db_sms.status}, cannot send"
        
        # Initialize TextBee client
        textbee = TextBeeClient()
        
        # Normalize phone number
        normalized_phone = textbee.normalize_phone_number(db_sms.phone_number)
        
        # Validate phone number
        if not textbee.validate_phone_number(normalized_phone):
            error_msg = f"Invalid phone number format: {db_sms.phone_number}"
            self.record_failed(sms_id, error_msg)
            self.repository.add_delivery_history(
                sms_id=sms_id,
                attempt_number=db_sms.retry_count + 1,
                status=SMSDeliveryStatus.FAILED.value,
                gateway_name="TextBee",
                error_code="INVALID_PHONE",
                error_message=error_msg
            )
            return False, error_msg
        
        # Send via TextBee
        success, gateway_reference, response_data = await textbee.send_sms(
            phone_number=normalized_phone,
            message=db_sms.message_body,
            idempotency_key=db_sms.idempotency_key
        )
        
        # Record delivery attempt
        attempt_number = db_sms.retry_count + 1
        
        if success and gateway_reference:
            # Success - record sent
            db_sms.status = SMSStatus.SENT
            db_sms.gateway_reference = gateway_reference
            db_sms.gateway_response = json.dumps(response_data)
            db_sms.last_attempt_at = datetime.utcnow()
            db_sms.sent_at = datetime.utcnow()
            db_sms.retry_count = attempt_number
            
            self.repository.db.add(db_sms)
            self.repository.db.commit()
            
            self.repository.add_delivery_history(
                sms_id=sms_id,
                attempt_number=attempt_number,
                status=SMSDeliveryStatus.SENT.value,
                gateway_name="TextBee",
                gateway_response=json.dumps(response_data)
            )
            
            return True, None
        else:
            # Failed - record failure and schedule retry if available
            error_msg = response_data.get("error", "Unknown error")
            
            db_sms.last_attempt_at = datetime.utcnow()
            db_sms.retry_count = attempt_number
            db_sms.error_reason = error_msg
            
            # Schedule retry if we have attempts left
            if db_sms.retry_count < db_sms.max_retries:
                db_sms.status = SMSStatus.PENDING
                db_sms.calculate_next_retry()
            else:
                db_sms.status = SMSStatus.FAILED
            
            self.repository.db.add(db_sms)
            self.repository.db.commit()
            
            self.repository.add_delivery_history(
                sms_id=sms_id,
                attempt_number=attempt_number,
                status=SMSDeliveryStatus.FAILED.value,
                gateway_name="TextBee",
                gateway_response=json.dumps(response_data),
                error_code="GATEWAY_ERROR",
                error_message=error_msg
            )
            
            return False, error_msg
    
    def compose_balance_alert(
        self,
        client_id: int,
        meter_assignment_id: int,
        client_name: str,
        balance: Decimal,
        cycle_name: str = "current"
    ) -> str:
        """
        Compose balance alert SMS.
        Example: "Dear John, your water bill balance for Jan 2026 is TZS 45,000. Thank you."
        """
        return (
            f"Dear {client_name}, your water bill balance for {cycle_name} "
            f"is TZS {balance:,.0f}. Thank you."
        )
    
    def compose_payment_confirmation(
        self,
        client_name: str,
        amount: Decimal,
        reference: Optional[str] = None
    ) -> str:
        """
        Compose payment confirmation SMS.
        Example: "Dear John, we received your payment of TZS 20,000 (Ref: ABC123). Thank you."
        """
        ref_part = f" (Ref: {reference})" if reference else ""
        return (
            f"Dear {client_name}, we received your payment of TZS {amount:,.0f}{ref_part}. Thank you."
        )
    
    def compose_penalty_notice(
        self,
        client_name: str,
        amount: Decimal,
        reason: str
    ) -> str:
        """
        Compose penalty notice SMS.
        Example: "Dear John, a penalty of TZS 5,000 has been applied: Late payment. Thank you."
        """
        return (
            f"Dear {client_name}, a penalty of TZS {amount:,.0f} has been applied: {reason}. Thank you."
        )
    
    def create_balance_alert_sms(
        self,
        client_id: int,
        meter_assignment_id: int,
        cycle_id: int,
        client_name: str,
        phone_number: str,
        balance: Decimal,
        cycle_name: str = "current"
    ) -> SMSMessageResponse:
        """
        Create and queue a balance alert SMS.
        """
        message_body = self.compose_balance_alert(client_id, meter_assignment_id, client_name, balance, cycle_name)
        idempotency_key = f"balance-alert-{meter_assignment_id}-{cycle_id}-{uuid.uuid4().hex[:8]}"
        
        sms = SMSMessageCreate(
            idempotency_key=idempotency_key,
            phone_number=phone_number,
            message_body=message_body,
            sms_type="BALANCE_ALERT",
            client_id=client_id,
            meter_assignment_id=meter_assignment_id,
            cycle_id=cycle_id
        )
        
        return self.queue_sms(sms)
