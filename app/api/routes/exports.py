"""
Export API routes - generate CSV reports for cycles, ledgers, and payments.
"""
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session
from app.db.deps import get_db
from app.services.export_service import ExportService

router = APIRouter(prefix="/exports", tags=["exports"])


@router.get("/cycle/{cycle_id}/readings")
def export_cycle_readings(cycle_id: int, db: Session = Depends(get_db)):
    """
    Export all readings for a cycle to CSV.
    Returns CSV file with client, meter, reading, consumption, status.
    """
    service = ExportService(db)
    try:
        csv_data = service.export_cycle_readings_csv(cycle_id)
        return Response(
            content=csv_data,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=cycle_{cycle_id}_readings.csv"}
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/cycle/{cycle_id}/charges")
def export_cycle_charges(cycle_id: int, db: Session = Depends(get_db)):
    """
    Export all charges (ledger entries) for a cycle to CSV.
    Returns CSV file with client, meter, charge amounts, descriptions.
    """
    service = ExportService(db)
    try:
        csv_data = service.export_cycle_charges_csv(cycle_id)
        return Response(
            content=csv_data,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=cycle_{cycle_id}_charges.csv"}
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/annual-ledger/{year}")
def export_annual_ledger(year: int, db: Session = Depends(get_db)):
    """
    Export all ledger entries for a year to CSV.
    Annual financial report for compliance and auditing.
    
    Example: GET /exports/annual-ledger/2026
    """
    service = ExportService(db)
    try:
        csv_data = service.export_annual_ledger_csv(year)
        return Response(
            content=csv_data,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=ledger_{year}.csv"}
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/payments")
def export_payments(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Export all payments within date range to CSV.
    
    Query params:
    - start_date: YYYY-MM-DD (optional)
    - end_date: YYYY-MM-DD (optional)
    
    Example: GET /exports/payments?start_date=2026-01-01&end_date=2026-01-31
    """
    service = ExportService(db)
    
    # Parse dates
    start_dt = datetime.strptime(start_date, "%Y-%m-%d") if start_date else None
    end_dt = datetime.strptime(end_date, "%Y-%m-%d") if end_date else None
    
    csv_data = service.export_payments_csv(start_dt, end_dt)
    
    filename = "payments"
    if start_date and end_date:
        filename = f"payments_{start_date}_to_{end_date}"
    
    return Response(
        content=csv_data,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}.csv"}
    )


@router.get("/client-balances")
def export_client_balances(db: Session = Depends(get_db)):
    """
    Export current balance summary for all active clients to CSV.
    Includes: client name, meter, debits, credits, net balance breakdown.
    """
    service = ExportService(db)
    csv_data = service.export_client_balances_csv()
    
    timestamp = datetime.now().strftime("%Y%m%d")
    return Response(
        content=csv_data,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=client_balances_{timestamp}.csv"}
    )
