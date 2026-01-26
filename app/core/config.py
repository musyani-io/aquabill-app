from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = Field(..., min_length=1, description="PostgreSQL URL")
    sms_gateway_url: str = Field(default="", description="SMS gateway base URL")
    sms_api_key: str = Field(default="", description="SMS gateway API key")
    submission_window_days: int = Field(default=5, ge=1, description="Target date window tolerance")

    model_config = {
        "env_file": ".env",
        "env_prefix": "AQUABILL_",
    }


settings = Settings()
