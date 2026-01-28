"""Shared API dependencies for FastAPI routes"""

from typing import Optional
from fastapi import Depends, HTTPException, Header, status
from sqlalchemy.orm import Session

from app.db.deps import get_db
from app.models.auth import AdminUser
from app.services.auth_service import decode_admin_token


def _extract_token(authorization: Optional[str]) -> str:
    """Extract token from Authorization header"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header",
        )
    return authorization[7:]  # Remove "Bearer " prefix


async def get_current_admin(
    authorization: Optional[str] = Header(None), db: Session = Depends(get_db)
) -> AdminUser:
    """Dependency to get current authenticated admin"""
    token = _extract_token(authorization)
    admin_id = decode_admin_token(token)
    if not admin_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token"
        )

    admin = db.query(AdminUser).filter(AdminUser.id == admin_id).first()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Admin not found"
        )
    return admin
