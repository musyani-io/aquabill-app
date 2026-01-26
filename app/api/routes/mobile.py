"""
Mobile API routes - bootstrap, incremental updates, and mobile reading submission.
"""

from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.deps import get_db
from app.services.mobile_service import MobileService
from app.schemas.mobile import (
    MobileBootstrapResponse,
    MobileUpdatesResponse,
    MobileReadingSubmit,
    MobileReadingResponse,
    MobileConflictDetail,
)

router = APIRouter(prefix="/mobile", tags=["mobile"])


@router.get("/bootstrap", response_model=MobileBootstrapResponse)
def get_bootstrap(db: Session = Depends(get_db)):
    """
    Bootstrap endpoint for mobile app initial sync.

    Returns:
    - Last 12 billing cycles
    - All active meter assignments
    - Latest approved readings per assignment+cycle
    - All referenced clients and meters
    - Server timestamp for tracking sync state

    Use this on first app launch or when full resync is needed.
    """
    service = MobileService(db)
    return service.get_bootstrap()


@router.get("/updates", response_model=MobileUpdatesResponse)
def get_updates(
    since: datetime = Query(
        ...,
        description="Last sync timestamp (ISO8601). Returns changes since this time.",
        example="2026-01-20T10:30:00Z",
    ),
    db: Session = Depends(get_db),
):
    """
    Incremental updates endpoint for efficient mobile sync.

    Returns only entities modified since the provided timestamp:
    - Updated assignments, cycles, readings (approved only)
    - Updated clients and meters
    - Tombstones for closed/archived cycles and deactivated assignments

    Mobile app should:
    1. Apply updates (server-wins merge)
    2. Process tombstones (mark local cycles read-only, assignments inactive)
    3. Store new last_sync timestamp for next call
    """
    service = MobileService(db)
    return service.get_updates(since=since)


@router.post(
    "/readings",
    response_model=MobileReadingResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_mobile_reading(
    payload: MobileReadingSubmit,
    db: Session = Depends(get_db),
):
    """
    Submit a meter reading from mobile app with extended metadata.

    Accepts:
    - All standard reading fields (meter_assignment_id, cycle_id, absolute_value)
    - Mobile metadata: device_id, app_version, client_tz, previous_approved_reading
    - Conflict resolution: conflict_id if resubmitting after conflict

    Returns:
    - 201: Reading created successfully
    - 400: Validation fails (window, baseline, late submission)
    - 409: Conflict detected (duplicate reading with different value)

    On 409 conflict, response includes server reading snapshot for comparison.
    Mobile app should:
    1. Mark local reading as CONFLICT
    2. Store conflict entry with server snapshot
    3. Display in conflicts UI for user resolution
    """
    service = MobileService(db)
    reading, error = service.submit_mobile_reading(payload)

    if error:
        # Check if this is a conflict scenario (duplicate with different value)
        if "duplicate" in error.lower() or "already exists" in error.lower():
            # Try to fetch existing reading for conflict detail
            existing = service.reading_repo.get_by_assignment_and_cycle(
                meter_assignment_id=payload.meter_assignment_id,
                cycle_id=payload.cycle_id,
            )

            conflict_detail = MobileConflictDetail(
                conflict_reason=error,
                server_reading=existing,
                local_reading=payload,
            )

            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "message": "Conflict detected",
                    "conflict": conflict_detail.model_dump(),
                },
            )

        # Other validation errors
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)

    # Success response
    return MobileReadingResponse(
        id=reading.id,
        meter_assignment_id=reading.meter_assignment_id,
        cycle_id=reading.cycle_id,
        absolute_value=reading.absolute_value,
        submitted_at=reading.submitted_at,
        submitted_by=reading.submitted_by,
        status="PENDING",
        message="Reading submitted successfully and queued for approval.",
    )


@router.post("/conflicts/{conflict_id}/resolve", status_code=status.HTTP_200_OK)
def resolve_mobile_conflict(
    conflict_id: int,
    resolution: str = Query(
        ...,
        description="Resolution action: 'accept_server' or 'resubmit'",
        regex="^(accept_server|resubmit)$",
    ),
    db: Session = Depends(get_db),
):
    """
    Resolve a mobile reading conflict (optional endpoint).

    Actions:
    - accept_server: Discard local reading, accept server version
    - resubmit: Client will resubmit with new reading (reference conflict_id in payload)

    This endpoint is optional; mobile app can handle resolution client-side
    by marking conflict resolved and either discarding local or resubmitting.
    """
    # This is a placeholder for explicit conflict resolution workflow
    # In practice, mobile app can handle this locally and just resubmit
    # with conflict_id in metadata if user chooses to resubmit

    return {
        "conflict_id": conflict_id,
        "resolution": resolution,
        "message": f"Conflict {conflict_id} marked as {resolution}. "
        f"{'Server version accepted.' if resolution == 'accept_server' else 'Client can resubmit new reading.'}",
    }
