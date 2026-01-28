from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional

from app.db.deps import get_db
from app.api.dependencies import get_current_admin
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
    generate_random_password,
)

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])
admin_router = APIRouter(prefix="/api/v1/admin", tags=["Admin"])


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

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create admin account"
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error: {str(e)}"
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

    # Return with plain password so admin can see it
    response = CollectorResponse.model_validate(new_collector)
    response.plain_password = request.password  # Include plain password in creation response
    return response


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
        collectors=[CollectorResponse.model_validate(c) for c in collectors]
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


@admin_router.post("/collectors/{collector_id}/reset-password", response_model=CollectorResponse)
def reset_collector_password(
    collector_id: int,
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Reset a collector's password (generates new password, admin only)"""

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

    # Generate new random password
    new_password = generate_random_password()
    collector.password_hash = hash_password(new_password)
    
    db.commit()
    db.refresh(collector)

    # Return collector with plain password
    response = CollectorResponse.model_validate(collector)
    response.plain_password = new_password
    return response


# ============ Collector Login (Public) ============

@router.post("/collector/login", response_model=CollectorLoginResponse)
def login_collector(
    request: CollectorLoginRequest,
    db: Session = Depends(get_db)
):
    """Collector login with name and password"""

    collector = db.query(CollectorUser).filter(
        CollectorUser.name == request.name
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
