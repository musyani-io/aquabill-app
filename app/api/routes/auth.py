from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional

from app.db.deps import get_db
from app.models.auth import AdminUser, CollectorUser
from app.schemas.auth import (
    AdminRegisterRequest,
    AdminLoginRequest,
    AdminLoginResponse,
    AdminUserResponse,
    CollectorCreateRequest,
    CollectorLoginRequest,
    CollectorLoginResponse,
    CollectorResponse,
    CollectorListResponse,
)
from app.services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    decode_admin_token,
    decode_collector_token,
)

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])
admin_router = APIRouter(prefix="/api/v1/admin", tags=["Admin"])


# ============ Helper Functions ============

def _extract_token(authorization: Optional[str]) -> str:
    """Extract token from Authorization header"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header"
        )
    return authorization[7:]  # Remove "Bearer " prefix


def get_current_admin(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)) -> AdminUser:
    """Dependency to get current authenticated admin"""
    token = _extract_token(authorization)
    admin_id = decode_admin_token(token)
    if not admin_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )

    admin = db.query(AdminUser).filter(AdminUser.id == admin_id).first()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin not found"
        )
    return admin


# ============ Admin Routes ============

@router.post("/admin/register", response_model=AdminLoginResponse)
def register_admin(
    request: AdminRegisterRequest,
    db: Session = Depends(get_db)
):
    """Register a new admin account"""

    # Check if username already exists
    existing_admin = db.query(AdminUser).filter(
        AdminUser.username == request.username
    ).first()

    if existing_admin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists"
        )

    try:
        # Create new admin
        new_admin = AdminUser(
            username=request.username,
            password_hash=hash_password(request.password),
            company_name=request.company_name,
            company_phone=request.company_phone,
            role_at_company=request.role_at_company,
            estimated_clients=request.estimated_clients,
        )

        db.add(new_admin)
        db.commit()
        db.refresh(new_admin)

        # Create access token
        token = create_access_token({
            "admin_id": new_admin.id,
            "username": new_admin.username,
            "type": "admin"
        })

        return AdminLoginResponse(
            token=token,
            user_id=new_admin.id,
            username=new_admin.username,
            company_name=new_admin.company_name,
            role="admin"
        )

    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create admin account"
        )


@router.post("/admin/login", response_model=AdminLoginResponse)
def login_admin(
    request: AdminLoginRequest,
    db: Session = Depends(get_db)
):
    """Admin login"""

    admin = db.query(AdminUser).filter(
        AdminUser.username == request.username
    ).first()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )

    if not verify_password(request.password, admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )

    # Create access token
    token = create_access_token({
        "admin_id": admin.id,
        "username": admin.username,
        "type": "admin"
    })

    return AdminLoginResponse(
        token=token,
        user_id=admin.id,
        username=admin.username,
        company_name=admin.company_name,
        role="admin"
    )


# ============ Collector Routes ============

@admin_router.post("/collectors", response_model=CollectorResponse)
def create_collector(
    request: CollectorCreateRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Create a new collector (admin only)"""

    # Create new collector
    new_collector = CollectorUser(
        admin_id=current_admin.id,
        name=request.name,
        password_hash=hash_password(request.password),
        is_active=True,
    )

    db.add(new_collector)
    db.commit()
    db.refresh(new_collector)

    return CollectorResponse.from_orm(new_collector)


@admin_router.get("/collectors", response_model=CollectorListResponse)
def list_collectors(
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Get all collectors for the current admin"""

    collectors = db.query(CollectorUser).filter(
        CollectorUser.admin_id == current_admin.id
    ).all()

    return CollectorListResponse(
        total=len(collectors),
        collectors=[CollectorResponse.from_orm(c) for c in collectors]
    )


@admin_router.delete("/collectors/{collector_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_collector(
    collector_id: int,
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Delete a collector (admin only)"""

    # Get collector
    collector = db.query(CollectorUser).filter(
        CollectorUser.id == collector_id,
        CollectorUser.admin_id == current_admin.id
    ).first()

    if not collector:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Collector not found"
        )

    db.delete(collector)
    db.commit()


# ============ Collector Login (Public) ============

@router.post("/collector/login", response_model=CollectorLoginResponse)
def login_collector(
    collector_id: int,
    request: CollectorLoginRequest,
    db: Session = Depends(get_db)
):
    """Collector login with password only"""

    collector = db.query(CollectorUser).filter(
        CollectorUser.id == collector_id
    ).first()

    if not collector:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Collector not found"
        )

    if not collector.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Collector account is inactive"
        )

    if not verify_password(request.password, collector.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid password"
        )

    # Create access token
    token = create_access_token({
        "collector_id": collector.id,
        "admin_id": collector.admin_id,
        "name": collector.name,
        "type": "collector"
    })

    return CollectorLoginResponse(
        token=token,
        collector_id=collector.id,
        name=collector.name,
        role="collector"
    )
