"""Core application configuration."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Application
    app_name: str = "AquaBill"
    environment: str = "development"
    debug: bool = False
    
    # Database
    database_url: str = "postgresql://aquabill:aquabill@localhost:5432/aquabill_dev"
    database_pool_size: int = 10
    database_max_overflow: int = 20
    
    # Redis
    redis_url: str = "redis://localhost:6379/0"
    
    # Security
    secret_key: str = "change-me-in-production"
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 24
    
    # SMS
    sms_provider: str = "mock"
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
