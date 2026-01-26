"""SMS API routes"""
from typing import List
from fastapi import APIRouter, Depends, Query, HTTPException, Header
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.services.sms_service import SMSService
from app.schemas.sms import SMSMessageCreate, SMSMessageResponse
from app.models.sms import SMSMessage

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


@router.post("/callbacks/gateway-webhook")
def process_gateway_callback(
    gateway_reference: str,
    status: str,
    db: Session = Depends(get_db),
    x_idempotency_key: str = Header(None)
):
    """
    Process SMS gateway callback webhook.
    
    Supports:
    - status: "delivered", "failed", "bounced"
    - Uses idempotency key to prevent duplicate processing
    """
    service = SMSService(db)
    sms = service.process_callback(gateway_reference, status)
    if not sms:
        raise HTTPException(status_code=404, detail="SMS with this gateway reference not found")
    return {
        "success": True,
        "sms_id": sms.id,
        "status": sms.status,
        "message": f"Callback processed: {status}"
    }
