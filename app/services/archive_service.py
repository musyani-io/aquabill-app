"""
Archive service - move old data (≥36 months) to read-only archive tables.
"""
from datetime import datetime, timedelta
from typing import List, Tuple, Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_
from app.models.cycle import Cycle
from app.models.reading import Reading
from app.models.ledger_entry import LedgerEntry
from app.repositories.cycle import CycleRepository
import logging

logger = logging.getLogger(__name__)


class ArchiveService:
    """Service for archiving old data"""
    
    def __init__(self, db: Session):
        self.db = db
        self.cycle_repo = CycleRepository(db)
    
    def get_archivable_cycles(self, cutoff_months: int = 36) -> List[Cycle]:
        """
        Get cycles that are ≥cutoff_months old and eligible for archiving.
        Only CLOSED or ARCHIVED cycles are archivable.
        """
        cutoff_date = datetime.utcnow() - timedelta(days=cutoff_months * 30)
        
        cycles = (
            self.db.query(Cycle)
            .filter(
                and_(
                    Cycle.end_date <= cutoff_date,
                    Cycle.status.in_(["CLOSED", "ARCHIVED"])
                )
            )
            .all()
        )
        
        return cycles
    
    def archive_cycle(self, cycle_id: int) -> Tuple[bool, Optional[str]]:
        """
        Archive a single cycle (mark as ARCHIVED).
        
        In production, this would:
        1. Copy data to archive tables (cycles_archive, readings_archive, ledger_archive)
        2. Mark original cycle as ARCHIVED
        3. Optionally delete from active tables (after verification)
        
        For now, we just mark as ARCHIVED (data stays in place but flagged).
        """
        cycle = self.cycle_repo.get(cycle_id)
        if not cycle:
            return False, f"Cycle {cycle_id} not found"
        
        if cycle.status not in ["CLOSED"]:
            return False, f"Cycle {cycle_id} must be CLOSED to archive (current: {cycle.status})"
        
        # Check age
        cutoff_date = datetime.utcnow() - timedelta(days=36 * 30)
        if cycle.end_date > cutoff_date:
            return False, f"Cycle {cycle_id} is not old enough (end_date: {cycle.end_date})"
        
        # Mark as ARCHIVED
        cycle.status = "ARCHIVED"
        self.db.add(cycle)
        self.db.commit()
        self.db.refresh(cycle)
        
        logger.info(f"Archived cycle {cycle_id} (end_date: {cycle.end_date})")
        return True, None
    
    def archive_old_cycles(self, cutoff_months: int = 36, dry_run: bool = False) -> dict:
        """
        Archive all eligible cycles ≥cutoff_months old.
        
        Args:
            cutoff_months: Age threshold in months (default 36)
            dry_run: If True, only report what would be archived without making changes
        
        Returns:
            Summary dict with archived_count, skipped_count, errors
        """
        archivable = self.get_archivable_cycles(cutoff_months)
        
        results = {
            "total_found": len(archivable),
            "archived": 0,
            "skipped": 0,
            "errors": []
        }
        
        if dry_run:
            results["dry_run"] = True
            results["would_archive"] = [
                {
                    "cycle_id": c.id,
                    "start_date": c.start_date.strftime("%Y-%m-%d"),
                    "end_date": c.end_date.strftime("%Y-%m-%d"),
                    "status": c.status
                }
                for c in archivable
            ]
            return results
        
        for cycle in archivable:
            success, error = self.archive_cycle(cycle.id)
            if success:
                results["archived"] += 1
            else:
                results["skipped"] += 1
                results["errors"].append({"cycle_id": cycle.id, "error": error})
        
        return results
    
    def get_archive_statistics(self) -> dict:
        """
        Get statistics about archived data.
        """
        archived_cycles = (
            self.db.query(Cycle)
            .filter(Cycle.status == "ARCHIVED")
            .count()
        )
        
        total_cycles = self.db.query(Cycle).count()
        
        oldest_cycle = (
            self.db.query(Cycle)
            .order_by(Cycle.start_date.asc())
            .first()
        )
        
        newest_cycle = (
            self.db.query(Cycle)
            .order_by(Cycle.start_date.desc())
            .first()
        )
        
        return {
            "total_cycles": total_cycles,
            "archived_cycles": archived_cycles,
            "active_cycles": total_cycles - archived_cycles,
            "oldest_cycle_date": oldest_cycle.start_date.strftime("%Y-%m-%d") if oldest_cycle else None,
            "newest_cycle_date": newest_cycle.start_date.strftime("%Y-%m-%d") if newest_cycle else None
        }
