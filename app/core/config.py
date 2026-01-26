from pydantic_settings import BaseSettings
from pydantic import Field

class Settings(BaseSettings):
    database_url: str = Field(default="")
    sms_gateway_url: str = Field(default="")
    sms_api_key: str = Field(default="")
    submission_window_days: int = 5

    model_config = {
        "env_file": ".env",
        "env_prefix": "AQUABILL_",
    }

settings = Settings()
