"""
Mobile authentication middleware - simple bearer token validation.
"""

from fastapi import HTTPException, status, Request
from typing import Optional


class MobileAuthMiddleware:
    """
    Simple bearer token validation for mobile endpoints.

    In production, integrate with a real auth service (OAuth2, JWT, etc).
    For MVP, we verify a collector token is provided.
    """

    def __init__(self, token: Optional[str] = None):
        """
        Initialize with optional expected token.
        If None, we just require Authorization header to be present.
        """
        self.expected_token = token

    def validate(self, request: Request) -> str:
        """
        Validate Authorization header and return collector ID/token.

        Expects: Authorization: Bearer <token>

        Returns:
            Collector ID/token from header

        Raises:
            HTTPException 401 if missing or invalid
        """
        auth_header = request.headers.get("Authorization")

        if not auth_header:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing Authorization header",
                headers={"WWW-Authenticate": "Bearer"},
            )

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Authorization header format. Expected: Bearer <token>",
                headers={"WWW-Authenticate": "Bearer"},
            )

        token = parts[1]

        # If we have an expected token, validate it
        if self.expected_token and token != self.expected_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return token


def require_mobile_auth(request: Request) -> str:
    """
    Dependency for FastAPI routes that require mobile authentication.
    Returns the collector token/ID from Authorization header.

    Usage:
        @router.post("/readings")
        def submit_reading(collector_id: str = Depends(require_mobile_auth)):
            ...
    """
    middleware = MobileAuthMiddleware()
    return middleware.validate(request)
