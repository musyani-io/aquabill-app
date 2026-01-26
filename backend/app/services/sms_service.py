import logging
from typing import Optional

from app.core.config import settings

# Optional imports guarded to avoid import errors if modules not present yet
try:
    from app.integrations.sms.textbee import TextBeeClient
except Exception:  # pragma: no cover
    TextBeeClient = None  # type: ignore

logger = logging.getLogger(__name__)


def send_sms(to: str, message: str, sender_id: Optional[str] = None) -> bool:
    """Send an SMS using the configured provider.

    Providers:
      - mock: logs the message and returns True
      - textbee: uses TextBeeClient
      - twilio: TODO (not implemented yet)
    """
    provider = (settings.sms_provider or "mock").lower()

    if provider == "mock":
        logger.info("[MOCK SMS] to=%s sender_id=%s message=%s", to, sender_id, message)
        return True

    if provider == "textbee":
        if TextBeeClient is None:
            logger.error("TextBee client not available.")
            return False
        client = TextBeeClient()
        return client.send_sms(to=to, message=message, sender_id=sender_id)

    if provider == "twilio":
        logger.error("Twilio provider not implemented yet.")
        return False

    logger.error("Unknown SMS provider: %s", provider)
    return False
