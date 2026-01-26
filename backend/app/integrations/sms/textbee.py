import logging
from typing import Optional

import requests

from app.core.config import settings

logger = logging.getLogger(__name__)


class TextBeeClient:
    """Minimal TextBee SMS client.

    Expects:
      - settings.textbee_api_key
      - settings.textbee_base_url (e.g., https://api.textbee.io/sms/send)
      - optional settings.textbee_sender_id
    """

    def __init__(self, api_key: Optional[str] = None, base_url: Optional[str] = None, sender_id: Optional[str] = None):
        self.api_key = api_key or settings.textbee_api_key
        self.base_url = base_url or settings.textbee_base_url
        self.sender_id = sender_id or settings.textbee_sender_id

        if not self.api_key:
            logger.warning("TextBee API key not configured.")
        if not self.base_url:
            logger.warning("TextBee base URL not configured.")

    def send_sms(self, to: str, message: str, sender_id: Optional[str] = None) -> bool:
        if not self.api_key or not self.base_url:
            logger.error("TextBee is not properly configured.")
            return False

        sid = sender_id or self.sender_id

        payload = {
            "to": to,
            "message": message,
        }
        if sid:
            payload["sender_id"] = sid

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        try:
            resp = requests.post(self.base_url, json=payload, headers=headers, timeout=10)
            if resp.status_code in (200, 201):
                return True
            logger.error("TextBee send failed: %s - %s", resp.status_code, resp.text)
            return False
        except requests.RequestException as exc:
            logger.exception("Error sending SMS via TextBee: %s", exc)
            return False
