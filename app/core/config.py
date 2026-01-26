from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = Field(..., min_length=1, description="PostgreSQL URL")

    # SMS Gateway (TextBee) Configuration
    sms_gateway_url: str = Field(
        default="https://sms.textbee.ug/api/v1/send",
        description="TextBee SMS gateway URL",
    )
    sms_gateway_key: str = Field(default="", description="TextBee API key")
    sms_sender_id: str = Field(default="", description="SMS sender ID or phone number")

    submission_window_days: int = Field(
        default=5, ge=1, description="Target date window tolerance"
    )

    model_config = {
        "env_file": ".env",
        "env_prefix": "AQUABILL_",
        "extra": "ignore",
    }


settings = Settings()
