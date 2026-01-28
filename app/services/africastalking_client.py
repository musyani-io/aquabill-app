"""
Africa's Talking SMS Gateway Client

Handles communication with Africa's Talking SMS API.
Documentation: https://developers.africastalking.com/docs/sms/overview
"""

import httpx
import logging
from typing import Dict, Optional, Tuple
from app.core.config import settings

logger = logging.getLogger(__name__)


class AfricasTalkingClient:
    """Client for Africa's Talking SMS Gateway API"""

    def __init__(self):
        self.api_url = settings.sms_gateway_url or "https://api.africastalking.com/version1/messaging"
        self.api_key = settings.sms_gateway_key
        self.username = settings.sms_username  # Africa's Talking username
        self.sender_id = settings.sms_sender_id or None  # Optional sender ID
        self.timeout = 30.0

    async def send_sms(
        self, phone_number: str, message: str, idempotency_key: Optional[str] = None
    ) -> Tuple[bool, Optional[str], Optional[Dict]]:
        """
        Send SMS via Africa's Talking Gateway.

        Args:
            phone_number: Recipient phone number (e.g., "+255700000000")
            message: SMS message body
            idempotency_key: Optional key for idempotent requests

        Returns:
            Tuple of (success, gateway_reference, response_data)
        """
        if not self.api_key or not self.username:
            logger.error("Africa's Talking configuration missing: API key or username not set")
            return False, None, {"error": "SMS gateway not configured"}

        # Normalize phone number for Africa's Talking
        normalized_phone = self._normalize_phone_number(phone_number)

        # Prepare request payload for Africa's Talking
        payload = {
            "username": self.username,
            "to": normalized_phone,
            "message": message,
        }

        # Add sender ID if configured
        if self.sender_id:
            payload["from"] = self.sender_id

        headers = {
            "apiKey": self.api_key,
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                logger.info(f"Sending SMS to {normalized_phone} via Africa's Talking")
                
                response = await client.post(
                    self.api_url,
                    data=payload,
                    headers=headers,
                )

                response_data = response.json()
                
                # Africa's Talking returns:
                # {
                #   "SMSMessageData": {
                #     "Message": "Sent to 1/1 Total Cost: TZS 20",
                #     "Recipients": [{
                #       "statusCode": 101,  # 101 = Processed, 102 = Failed
                #       "number": "+255700000000",
                #       "status": "Success",
                #       "cost": "TZS 20",
                #       "messageId": "ATXid_xxxx"
                #     }]
                #   }
                # }

                if response.status_code == 201:
                    sms_data = response_data.get("SMSMessageData", {})
                    recipients = sms_data.get("Recipients", [])
                    
                    if recipients and len(recipients) > 0:
                        recipient = recipients[0]
                        status_code = recipient.get("statusCode")
                        
                        # Status code 101 or 102 (processed)
                        if status_code in [101, 102]:
                            message_id = recipient.get("messageId")
                            status = recipient.get("status", "Unknown")
                            
                            logger.info(
                                f"SMS sent successfully to {normalized_phone}. "
                                f"MessageId: {message_id}, Status: {status}"
                            )
                            return True, message_id, response_data
                        else:
                            error_msg = recipient.get("status", "Unknown error")
                            logger.error(f"Africa's Talking API error: {error_msg}")
                            return False, None, response_data
                    else:
                        logger.error("Africa's Talking API returned no recipients")
                        return False, None, response_data
                else:
                    error_msg = response_data.get("message", "Unknown error")
                    logger.error(f"Africa's Talking API error: {error_msg}")
                    return False, None, response_data

        except httpx.TimeoutException:
            logger.error("Africa's Talking API timeout")
            return False, None, {"error": "Request timeout"}
        except Exception as e:
            logger.error(f"Africa's Talking request error: {str(e)}")
            return False, None, {"error": str(e)}

    def _normalize_phone_number(self, phone_number: str) -> str:
        """
        Normalize phone number to Africa's Talking format.
        
        Africa's Talking accepts international format with + prefix.
        Converts: 0700000000 -> +255700000000 (for Tanzania)
                  255700000000 -> +255700000000
        
        Args:
            phone_number: Input phone number
            
        Returns:
            Normalized phone number in +255XXXXXXXXX format
        """
        phone = phone_number.strip()
        
        # Remove any spaces or dashes
        phone = phone.replace(" ", "").replace("-", "")
        
        # If starts with 0, assume Tanzanian number
        if phone.startswith("0"):
            phone = "+255" + phone[1:]
        # If starts with 255 but no +, add it
        elif phone.startswith("255"):
            phone = "+" + phone
        # If doesn't start with +, assume it needs +255
        elif not phone.startswith("+"):
            phone = "+255" + phone
            
        return phone
