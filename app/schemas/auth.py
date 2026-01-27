from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


# ============ Admin Registration/Login ============

class AdminRegisterRequest(BaseModel):
    """Admin sign up request"""
    username: str = Field(..., min_length=3, max_length=100)
    password: str = Field(..., min_length=6, max_length=72)
    confirm_password: str = Field(..., min_length=6, max_length=72)
    company_name: str = Field(..., min_length=1, max_length=255)
    company_phone: str = Field(..., pattern=r'^\+\d{7,15}$')
    role_at_company: str = Field(..., min_length=1, max_length=100)
    estimated_clients: int = Field(..., ge=1)

    @field_validator('confirm_password')
    def passwords_match(cls, v, info):
        if 'password' in info.data and v != info.data['password']:
            raise ValueError('Passwords do not match')
        return v


class AdminLoginRequest(BaseModel):
    """Admin login request"""
    username: str = Field(..., min_length=3)
    password: str = Field(..., min_length=6)


class AdminLoginResponse(BaseModel):
    """Admin login response"""
    token: str
    user_id: int
    username: str
    company_name: str
    role: str = "admin"


class AdminUserResponse(BaseModel):
    """Admin user details"""
    id: int
    username: str
    company_name: str
    company_phone: str
    role_at_company: str
    estimated_clients: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Collector Management ============

class CollectorCreateRequest(BaseModel):
    """Create new collector"""
    name: str = Field(..., min_length=1, max_length=100)
    password: str = Field(..., min_length=4, max_length=100)


class CollectorLoginRequest(BaseModel):
    """Collector login request (name and password)"""
    name: str = Field(..., min_length=1, max_length=100)
    password: str = Field(..., min_length=4)


class CollectorLoginResponse(BaseModel):
    """Collector login response"""
    token: str
    collector_id: int
    name: str
    role: str = "collector"


class CollectorResponse(BaseModel):
    """Collector details"""
    id: int
    name: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class CollectorListResponse(BaseModel):
    """List of collectors"""
    total: int
    collectors: list[CollectorResponse]
