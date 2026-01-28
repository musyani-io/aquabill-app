from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = Field(..., min_length=1, description="PostgreSQL URL")

    # SMS Gateway (Africa's Talking) Configuration
    sms_gateway_url: str = Field(
        default="https://api.africastalking.com/version1/messaging",
        description="Africa's Talking SMS gateway URL",
    )
    sms_gateway_key: str = Field(default="", description="Africa's Talking API key")
    sms_username: str = Field(default="", description="Africa's Talking username")
    sms_sender_id: str = Field(default="", description="SMS sender ID (optional)")

    submission_window_days: int = Field(
        default=5, ge=1, description="Target date window tolerance"
    )

    model_config = {
        "env_file": ".env",
        "env_prefix": "AQUABILL_",
        "extra": "ignore",
    }


settings = Settings()
