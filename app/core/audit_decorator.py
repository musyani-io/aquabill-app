"""
Audit logging decorator for automatic action tracking.

Usage:
    @audit_log(
        action=AuditAction.READING_APPROVED,
        entity_type="reading",
        get_entity_id=lambda result: result.id,
        description_template="Approved reading for meter {meter_id}"
    )
    def approve_reading(...):
        ...
"""

import functools
import json
from typing import Callable, Optional, Any, Dict
from sqlalchemy.orm import Session
from app.models.audit_log import AuditAction
from app.schemas.audit_log import AuditLogCreate
from app.repositories.audit_log import AuditLogRepository
import logging

logger = logging.getLogger(__name__)


def audit_log(
    action: AuditAction,
    entity_type: str,
    get_entity_id: Optional[Callable[[Any], int]] = None,
    description_template: Optional[str] = None,
    get_metadata: Optional[Callable[[Any], Dict]] = None,
    admin_username_key: str = "admin_username",
):
    """
    Decorator to automatically log admin actions to audit trail.

    Args:
        action: The AuditAction enum value
        entity_type: Type of entity (e.g., "reading", "cycle", "payment")
        get_entity_id: Function to extract entity ID from function result/args
        description_template: Template for description (can use kwargs)
        get_metadata: Function to extract additional metadata
        admin_username_key: Key in kwargs to get admin username

    Example:
        @audit_log(
            action=AuditAction.READING_APPROVED,
            entity_type="reading",
            get_entity_id=lambda result: result[0].id if result[0] else None,
            description_template="Approved reading {reading_id} for meter {meter_id}"
        )
        def approve_reading(reading_id, meter_id, admin_username):
            ...
    """

    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            # Execute the actual function
            result = func(*args, **kwargs)

            # Extract admin username
            admin_username = kwargs.get(admin_username_key, "system")

            # Extract entity_id
            entity_id = None
            if get_entity_id:
                try:
                    entity_id = get_entity_id(result)
                except Exception as e:
                    logger.warning(f"Failed to extract entity_id: {e}")

            # If entity_id not from result, try from kwargs
            if entity_id is None and f"{entity_type}_id" in kwargs:
                entity_id = kwargs[f"{entity_type}_id"]

            # Generate description
            if description_template:
                try:
                    description = description_template.format(**kwargs)
                except Exception:
                    description = f"{action.value} on {entity_type} {entity_id}"
            else:
                description = f"{action.value} on {entity_type} {entity_id}"

            # Extract metadata
            metadata = None
            if get_metadata:
                try:
                    metadata_dict = get_metadata(result)
                    metadata = json.dumps(metadata_dict)
                except Exception as e:
                    logger.warning(f"Failed to extract metadata: {e}")

            # Get DB session from args/kwargs
            db: Optional[Session] = None
            for arg in args:
                if isinstance(arg, Session):
                    db = arg
                    break
            if not db:
                db = kwargs.get("db")

            # Log to audit trail
            if db and entity_id:
                try:
                    audit_repo = AuditLogRepository(db)
                    audit_entry = AuditLogCreate(
                        admin_username=admin_username,
                        action=action,
                        entity_type=entity_type,
                        entity_id=entity_id,
                        description=description,
                        metadata=metadata,
                    )
                    audit_repo.create(audit_entry)
                except Exception as e:
                    # Don't fail the original operation if audit logging fails
                    logger.error(f"Failed to create audit log: {e}")

            return result

        return wrapper

    return decorator


def audit_log_async(
    action: AuditAction,
    entity_type: str,
    get_entity_id: Optional[Callable[[Any], int]] = None,
    description_template: Optional[str] = None,
    get_metadata: Optional[Callable[[Any], Dict]] = None,
    admin_username_key: str = "admin_username",
):
    """
    Async version of audit_log decorator for async functions.
    """

    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            # Execute the actual function
            result = await func(*args, **kwargs)

            # Extract admin username
            admin_username = kwargs.get(admin_username_key, "system")

            # Extract entity_id
            entity_id = None
            if get_entity_id:
                try:
                    entity_id = get_entity_id(result)
                except Exception as e:
                    logger.warning(f"Failed to extract entity_id: {e}")

            # If entity_id not from result, try from kwargs
            if entity_id is None and f"{entity_type}_id" in kwargs:
                entity_id = kwargs[f"{entity_type}_id"]

            # Generate description
            if description_template:
                try:
                    description = description_template.format(**kwargs)
                except Exception:
                    description = f"{action.value} on {entity_type} {entity_id}"
            else:
                description = f"{action.value} on {entity_type} {entity_id}"

            # Extract metadata
            metadata = None
            if get_metadata:
                try:
                    metadata_dict = get_metadata(result)
                    metadata = json.dumps(metadata_dict)
                except Exception as e:
                    logger.warning(f"Failed to extract metadata: {e}")

            # Get DB session from args/kwargs
            db: Optional[Session] = None
            for arg in args:
                if isinstance(arg, Session):
                    db = arg
                    break
            if not db:
                db = kwargs.get("db")

            # Log to audit trail
            if db and entity_id:
                try:
                    audit_repo = AuditLogRepository(db)
                    audit_entry = AuditLogCreate(
                        admin_username=admin_username,
                        action=action,
                        entity_type=entity_type,
                        entity_id=entity_id,
                        description=description,
                        metadata=metadata,
                    )
                    audit_repo.create(audit_entry)
                except Exception as e:
                    # Don't fail the original operation if audit logging fails
                    logger.error(f"Failed to create audit log: {e}")

            return result

        return wrapper

    return decorator
