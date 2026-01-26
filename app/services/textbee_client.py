"""
TextBee SMS Gateway Client

Handles communication with TextBee SMS Gateway API.
Documentation: https://sms.textbee.ug
"""
import httpx
import logging
from typing import Dict, Optional, Tuple
from app.core.config import settings

logger = logging.getLogger(__name__)


class TextBeeClient:
    """Client for TextBee SMS Gateway API"""
    
    def __init__(self):
        self.api_url = settings.sms_gateway_url
        self.api_key = settings.sms_gateway_key
        self.sender_id = settings.sms_sender_id
        self.timeout = 30.0
    
    async def send_sms(
        self,
        phone_number: str,
        message: str,
        idempotency_key: Optional[str] = None
    ) -> Tuple[bool, Optional[str], Optional[Dict]]:
        """
        Send SMS via TextBee Gateway.
        
        Args:
            phone_number: Recipient phone number (e.g., "+256700000000")
            message: SMS message body
            idempotency_key: Optional key for idempotent requests
        
        Returns:
            Tuple of (success, gateway_reference, response_data)
        """
        if not self.api_key or not self.sender_id:
            logger.error("TextBee configuration missing: API key or sender ID not set")
            return False, None, {"error": "SMS gateway not configured"}
        
        # Prepare request payload for TextBee
        payload = {
            "to": phone_number,
            "message": message,
            "sender": self.sender_id,
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        
        if idempotency_key:
            headers["X-Idempotency-Key"] = idempotency_key
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                logger.info(f"Sending SMS to {phone_number} via TextBee")
                
                response = await client.post(
                    self.api_url,
                    json=payload,
                    headers=headers
                )
                
                response_data = response.json()
                
                # TextBee typically returns:
                # Success: {"status": "success", "message_id": "...", "balance": "..."}
                # Failure: {"status": "error", "message": "..."}
                
                if response.status_code == 200 and response_data.get("status") == "success":
                    gateway_reference = response_data.get("message_id")
                    logger.info(f"SMS sent successfully: {gateway_reference}")
                    return True, gateway_reference, response_data
                else:
                    error_msg = response_data.get("message", "Unknown error")
                    logger.error(f"TextBee API error: {error_msg}")
                    return False, None, response_data
                    
        except httpx.TimeoutException:
            logger.error("TextBee API timeout")
            return False, None, {"error": "Gateway timeout"}
        except httpx.RequestError as e:
            logger.error(f"TextBee request error: {str(e)}")
            return False, None, {"error": str(e)}
        except Exception as e:
            logger.error(f"Unexpected error sending SMS: {str(e)}")
            return False, None, {"error": str(e)}
    
    def validate_phone_number(self, phone_number: str) -> bool:
        """
        Basic phone number validation for Tanzanian numbers.
        TextBee accepts formats: +255700000000, 255700000000, 0700000000
        """
        if not phone_number:
            return False
        
        # Remove spaces and dashes
        cleaned = phone_number.replace(" ", "").replace("-", "")
        
        # Check common formats
        if cleaned.startswith("+255") and len(cleaned) == 13:
            return True
        if cleaned.startswith("255") and len(cleaned) == 12:
            return True
        if cleaned.startswith("0") and len(cleaned) == 10:
            return True
        
        return False
    
    def normalize_phone_number(self, phone_number: str) -> str:
        """
        Normalize phone number to international format (+255...).
        """
        cleaned = phone_number.replace(" ", "").replace("-", "")
        
        if cleaned.startswith("+255"):
            return cleaned
        elif cleaned.startswith("255"):
            return f"+{cleaned}"
        elif cleaned.startswith("0"):
            return f"+255{cleaned[1:]}"
        
        return phone_number  # Return as-is if unrecognized format
