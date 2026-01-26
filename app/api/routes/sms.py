"""SMS API routes"""
from typing import List, Dict, Optional
from fastapi import APIRouter, Depends, Query, HTTPException, Header, BackgroundTasks
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.services.sms_service import SMSService
from app.schemas.sms import SMSMessageCreate, SMSMessageResponse
from app.models.sms import SMSMessage
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/", response_model=SMSMessageResponse)
def queue_sms(
    sms: SMSMessageCreate,
    db: Session = Depends(get_db)
):
    """Queue new SMS for sending (with idempotency)"""
    service = SMSService(db)
    
    # Check idempotency to prevent duplicates
    existing = service.check_idempotency(sms.idempotency_key)
    if existing:
        return existing
    
    return service.queue_sms(sms)


@router.get("/", response_model=List[SMSMessageResponse])
def get_all_sms(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """Get all SMS messages"""
    service = SMSService(db)
    return service.get_all_sms(skip, limit)


@router.get("/pending", response_model=List[SMSMessageResponse])
def get_pending_sms(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """Get pending SMS (not yet sent)"""
    service = SMSService(db)
    return service.get_pending_sms(skip, limit)


@router.get("/retry-scheduled", response_model=List[SMSMessageResponse])
def get_retry_scheduled(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """Get SMS ready for retry (for scheduler)"""
    service = SMSService(db)
    return service.get_retry_scheduled(skip, limit)


@router.get("/client/{client_id}", response_model=List[SMSMessageResponse])
def get_sms_by_client(
    client_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """Get SMS messages for specific client"""
    service = SMSService(db)
    return service.get_sms_by_client(client_id, skip, limit)


@router.get("/phone/{phone_number}", response_model=List[SMSMessageResponse])
def get_sms_by_phone(
    phone_number: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """Get SMS messages for specific phone number"""
    service = SMSService(db)
    return service.get_sms_by_phone(phone_number, skip, limit)


@router.get("/{sms_id}", response_model=SMSMessageResponse)
def get_sms(
    sms_id: int,
    db: Session = Depends(get_db)
):
    """Get specific SMS by ID"""
    service = SMSService(db)
    sms = service.get_sms(sms_id)
    if not sms:
        raise HTTPException(status_code=404, detail="SMS not found")
    return sms


@router.post("/{sms_id}/send")
async def send_sms(
    sms_id: int,
    db: Session = Depends(get_db)
):
    """
    Send SMS immediately via TextBee gateway.
    Records delivery attempt in history.
    """
    service = SMSService(db)
    success, error = await service.send_sms(sms_id)
    
    if not success:
        raise HTTPException(status_code=400, detail=error or "Failed to send SMS")
    
    sms = service.get_sms(sms_id)
    return {
        "success": True,
        "sms_id": sms_id,
        "status": sms.status if sms else "SENT",
        "message": "SMS sent successfully"
    }


@router.post("/process-retries")
async def process_retry_queue(
    limit: int = Query(50, ge=1, le=200, description="Max SMS to process"),
    db: Session = Depends(get_db)
):
    """
    Process retry queue - sends all SMS ready for retry.
    SCHEDULER: Call this endpoint every 5-10 minutes.
    """
    service = SMSService(db)
    retry_sms = service.get_retry_scheduled(skip=0, limit=limit)
    
    results = {
        "processed": 0,
        "successful": 0,
        "failed": 0,
        "errors": []
    }
    
    for sms in retry_sms:
        results["processed"] += 1
        try:
            success, error = await service.send_sms(sms.id)
            if success:
                results["successful"] += 1
            else:
                results["failed"] += 1
                results["errors"].append({"sms_id": sms.id, "error": error})
        except Exception as e:
            results["failed"] += 1
            results["errors"].append({"sms_id": sms.id, "error": str(e)})
            logger.error(f"Error sending SMS {sms.id}: {str(e)}")
    
    return results


@router.post("/{sms_id}/record-sent")
def record_sent(
    sms_id: int,
    gateway_reference: str,
    db: Session = Depends(get_db)
):
    """Record that SMS was sent to gateway"""
    service = SMSService(db)
    sms = service.record_sent(sms_id, gateway_reference)
    if not sms:
        raise HTTPException(status_code=404, detail="SMS not found")
    return sms


@router.post("/{sms_id}/record-failed")
def record_failed(
    sms_id: int,
    error_reason: str,
    db: Session = Depends(get_db)
):
    """Record that SMS sending failed"""
    service = SMSService(db)
    sms = service.record_failed(sms_id, error_reason)
    if not sms:
        raise HTTPException(status_code=404, detail="SMS not found")
    return sms


@router.post("/callbacks/textbee-webhook")
def process_textbee_callback(
    gateway_reference: str = Query(..., description="TextBee message ID"),
    status: str = Query(..., description="Delivery status: delivered, failed, bounced"),
    db: Session = Depends(get_db),
    x_idempotency_key: Optional[str] = Header(None, description="Idempotency key for duplicate prevention")
):
    """
    Process TextBee SMS gateway callback webhook.
    
    TextBee callback statuses:
    - delivered: SMS successfully delivered to recipient
    - failed: SMS delivery failed
    - bounced: Invalid number or recipient opted out
    
    Uses idempotency key to prevent duplicate processing.
    """
    service = SMSService(db)
    
    # Idempotency: Check if we've already processed this callback
    if x_idempotency_key:
        # In production, store processed idempotency keys in Redis/cache
        # For now, we rely on the SMS status not changing if already processed
        logger.info(f"Processing callback with idempotency key: {x_idempotency_key}")
    
    sms = service.process_callback(gateway_reference, status)
    if not sms:
        raise HTTPException(
            status_code=404, 
            detail=f"SMS with gateway reference '{gateway_reference}' not found"
        )
    
    return {
        "success": True,
        "sms_id": sms.id,
        "status": sms.status,
        "message": f"Callback processed: {status}"
    }
