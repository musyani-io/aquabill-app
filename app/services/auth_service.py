from datetime import datetime, timedelta, timezone
import bcrypt
from jose import JWTError, jwt
from typing import Optional, Dict, Any
import os
import secrets
import string

# JWT settings
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30


def generate_random_password(length: int = 12) -> str:
    """Generate a random password with uppercase, lowercase, digits, and special chars"""
    characters = string.ascii_letters + string.digits + "!@#$%^&*"
    password = "".join(secrets.choice(characters) for _ in range(length))
    return password


def hash_password(password: str) -> str:
    """Hash a password using bcrypt"""
    # Ensure password is a string
    if not isinstance(password, str):
        password = str(password)
    password_bytes = password.strip().encode("utf-8")
    if len(password_bytes) > 72:
        raise ValueError(f"Password too long: {len(password_bytes)} bytes")
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password_bytes, salt).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    if not isinstance(plain_password, str):
        plain_password = str(plain_password)
    plain_password_bytes = plain_password.strip().encode("utf-8")
    return bcrypt.checkpw(plain_password_bytes, hashed_password.encode("utf-8"))


def create_access_token(
    data: Dict[str, Any], expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT access token"""
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """Decode JWT token and return payload"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None


def decode_admin_token(token: str) -> Optional[int]:
    """Decode admin token and return admin_id"""
    payload = decode_token(token)
    if payload and payload.get("type") == "admin":
        return payload.get("admin_id")
    return None


def decode_collector_token(token: str) -> Optional[int]:
    """Decode collector token and return collector_id"""
    payload = decode_token(token)
    if payload and payload.get("type") == "collector":
        return payload.get("collector_id")
    return None
