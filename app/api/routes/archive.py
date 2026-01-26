"""
Archive API routes - manage data archival for old cycles (≥36 months).
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.services.archive_service import ArchiveService

router = APIRouter(prefix="/archive", tags=["archive"])


@router.get("/eligible-cycles")
def get_eligible_cycles(
    cutoff_months: int = Query(
        36, ge=12, le=120, description="Age threshold in months"
    ),
    db: Session = Depends(get_db),
):
    """
    Get list of cycles eligible for archiving (≥cutoff_months old).
    Only CLOSED cycles are eligible.
    """
    service = ArchiveService(db)
    cycles = service.get_archivable_cycles(cutoff_months)

    return {
        "cutoff_months": cutoff_months,
        "eligible_count": len(cycles),
        "cycles": [
            {
                "cycle_id": c.id,
                "start_date": c.start_date.strftime("%Y-%m-%d"),
                "end_date": c.end_date.strftime("%Y-%m-%d"),
                "status": c.status,
            }
            for c in cycles
        ],
    }


@router.post("/cycle/{cycle_id}")
def archive_cycle(cycle_id: int, db: Session = Depends(get_db)):
    """
    Archive a single cycle (mark as ARCHIVED).
    Cycle must be CLOSED and ≥36 months old.
    """
    service = ArchiveService(db)
    success, error = service.archive_cycle(cycle_id)

    if not success:
        raise HTTPException(status_code=400, detail=error)

    return {
        "success": True,
        "cycle_id": cycle_id,
        "message": f"Cycle {cycle_id} archived successfully",
    }


@router.post("/archive-old")
def archive_old_cycles(
    cutoff_months: int = Query(
        36, ge=12, le=120, description="Age threshold in months"
    ),
    dry_run: bool = Query(False, description="Preview without making changes"),
    db: Session = Depends(get_db),
):
    """
    Archive all eligible cycles ≥cutoff_months old.

    SCHEDULER: Call this monthly with dry_run=false to automatically archive old data.

    Use dry_run=true to preview what would be archived.
    """
    service = ArchiveService(db)
    results = service.archive_old_cycles(cutoff_months, dry_run)

    return results


@router.get("/statistics")
def get_archive_statistics(db: Session = Depends(get_db)):
    """
    Get statistics about archived data.
    Shows: total cycles, archived cycles, active cycles, date ranges.
    """
    service = ArchiveService(db)
    stats = service.get_archive_statistics()

    return stats
