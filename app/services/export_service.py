"""
Export service - generate CSV/PDF reports for cycles, ledgers, and payments.
"""
import csv
import io
from typing import List, Dict, Optional
from datetime import datetime
from decimal import Decimal
from sqlalchemy.orm import Session
from app.repositories.cycle import CycleRepository
from app.repositories.reading import ReadingRepository
from app.repositories.ledger_entry import LedgerEntryRepository
from app.repositories.payment import PaymentRepository
from app.repositories.meter_assignment import MeterAssignmentRepository
from app.models.cycle import Cycle
from app.models.reading import Reading
from app.models.ledger_entry import LedgerEntry


class ExportService:
    """Service for generating exports and reports"""
    
    def __init__(self, db: Session):
        self.db = db
        self.cycle_repo = CycleRepository(db)
        self.reading_repo = ReadingRepository(db)
        self.ledger_repo = LedgerEntryRepository(db)
        self.payment_repo = PaymentRepository(db)
        self.assignment_repo = MeterAssignmentRepository(db)
    
    def export_cycle_readings_csv(self, cycle_id: int) -> str:
        """
        Export all readings for a cycle to CSV.
        Includes: client, meter, reading value, consumption, status.
        """
        cycle = self.cycle_repo.get(cycle_id)
        if not cycle:
            raise ValueError(f"Cycle {cycle_id} not found")
        
        readings = self.reading_repo.list_by_cycle(cycle_id)
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Headers
        writer.writerow([
            "Reading ID",
            "Client Name",
            "Phone Number",
            "Meter Serial",
            "Reading Value",
            "Previous Reading",
            "Consumption (m³)",
            "Status",
            "Approved",
            "Submitted At",
            "Approved At",
            "Approved By"
        ])
        
        # Data rows
        for reading in readings:
            assignment = reading.meter_assignment
            client = assignment.client
            meter = assignment.meter
            
            writer.writerow([
                reading.id,
                f"{client.first_name} {client.surname}",
                client.phone_number,
                meter.serial_number,
                f"{reading.reading_value:.4f}",
                f"{reading.previous_reading:.4f}" if reading.previous_reading else "",
                f"{reading.consumption:.4f}" if reading.consumption else "",
                reading.status,
                "Yes" if reading.approved else "No",
                reading.submitted_at.strftime("%Y-%m-%d %H:%M:%S") if reading.submitted_at else "",
                reading.approved_at.strftime("%Y-%m-%d %H:%M:%S") if reading.approved_at else "",
                reading.approved_by or ""
            ])
        
        return output.getvalue()
    
    def export_cycle_charges_csv(self, cycle_id: int) -> str:
        """
        Export all charges (ledger entries) for a cycle to CSV.
        Includes: client, meter, charge amount, cycle period.
        """
        cycle = self.cycle_repo.get(cycle_id)
        if not cycle:
            raise ValueError(f"Cycle {cycle_id} not found")
        
        ledger_entries = self.ledger_repo.list_by_cycle(cycle_id)
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Headers
        writer.writerow([
            "Entry ID",
            "Client Name",
            "Phone Number",
            "Meter Serial",
            "Entry Type",
            "Amount (TZS)",
            "Is Credit",
            "Description",
            "Created At",
            "Created By"
        ])
        
        # Data rows
        for entry in ledger_entries:
            assignment = entry.meter_assignment
            client = assignment.client
            meter = assignment.meter
            
            writer.writerow([
                entry.id,
                f"{client.first_name} {client.surname}",
                client.phone_number,
                meter.serial_number,
                entry.entry_type,
                f"{float(entry.amount):,.2f}",
                "Yes" if entry.is_credit else "No",
                entry.description,
                entry.created_at.strftime("%Y-%m-%d %H:%M:%S"),
                entry.created_by
            ])
        
        return output.getvalue()
    
    def export_annual_ledger_csv(self, year: int) -> str:
        """
        Export all ledger entries for a year to CSV.
        Annual financial report for compliance and auditing.
        """
        # Get all cycles for the year
        all_cycles = self.cycle_repo.list(skip=0, limit=1000)
        year_cycles = [c for c in all_cycles if c.start_date.year == year]
        
        if not year_cycles:
            raise ValueError(f"No cycles found for year {year}")
        
        # Collect all ledger entries for year cycles
        all_entries = []
        for cycle in year_cycles:
            entries = self.ledger_repo.list_by_cycle(cycle.id)
            all_entries.extend([(entry, cycle) for entry in entries])
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Headers
        writer.writerow([
            "Entry ID",
            "Cycle",
            "Client Name",
            "Phone Number",
            "Meter Serial",
            "Entry Type",
            "Amount (TZS)",
            "Is Credit",
            "Description",
            "Created At",
            "Created By"
        ])
        
        # Data rows
        for entry, cycle in sorted(all_entries, key=lambda x: x[0].created_at):
            assignment = entry.meter_assignment
            client = assignment.client
            meter = assignment.meter
            
            writer.writerow([
                entry.id,
                f"{cycle.start_date.strftime('%Y-%m-%d')} to {cycle.end_date.strftime('%Y-%m-%d')}",
                f"{client.first_name} {client.surname}",
                client.phone_number,
                meter.serial_number,
                entry.entry_type,
                f"{float(entry.amount):,.2f}",
                "Yes" if entry.is_credit else "No",
                entry.description,
                entry.created_at.strftime("%Y-%m-%d %H:%M:%S"),
                entry.created_by
            ])
        
        return output.getvalue()
    
    def export_payments_csv(self, start_date: Optional[datetime] = None, end_date: Optional[datetime] = None) -> str:
        """
        Export all payments within date range to CSV.
        """
        payments = self.payment_repo.list(skip=0, limit=10000)
        
        # Filter by date range if provided
        if start_date:
            payments = [p for p in payments if p.received_at >= start_date]
        if end_date:
            payments = [p for p in payments if p.received_at <= end_date]
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Headers
        writer.writerow([
            "Payment ID",
            "Client Name",
            "Phone Number",
            "Amount (TZS)",
            "Reference",
            "Method",
            "Notes",
            "Received At",
            "Recorded By"
        ])
        
        # Data rows
        for payment in payments:
            assignment = payment.meter_assignment
            client = self.assignment_repo.get(payment.meter_assignment_id).client if payment.meter_assignment_id else None
            
            writer.writerow([
                payment.id,
                f"{client.first_name} {client.surname}" if client else "N/A",
                client.phone_number if client else "N/A",
                f"{float(payment.amount):,.2f}",
                payment.reference or "",
                payment.method or "",
                payment.notes or "",
                payment.received_at.strftime("%Y-%m-%d %H:%M:%S"),
                payment.recorded_by
            ])
        
        return output.getvalue()
    
    def export_client_balances_csv(self) -> str:
        """
        Export current balance summary for all active clients.
        """
        from app.services.ledger_service import LedgerService
        
        # Get all active assignments
        assignments = self.assignment_repo.list_active()
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Headers
        writer.writerow([
            "Client Name",
            "Phone Number",
            "Meter Serial",
            "Total Debits (TZS)",
            "Total Credits (TZS)",
            "Net Balance (TZS)",
            "Charges (TZS)",
            "Penalties (TZS)",
            "Payments (TZS)"
        ])
        
        # Data rows
        ledger_service = LedgerService(self.db)
        for assignment in assignments:
            client = assignment.client
            meter = assignment.meter
            
            balance, error = ledger_service.compute_balance(assignment.id)
            if error:
                continue
            
            writer.writerow([
                f"{client.first_name} {client.surname}",
                client.phone_number,
                meter.serial_number,
                f"{balance['total_debits']:,.2f}",
                f"{balance['total_credits']:,.2f}",
                f"{balance['net_balance']:,.2f}",
                f"{balance['breakdown']['charges']:,.2f}",
                f"{balance['breakdown']['penalties']:,.2f}",
                f"{balance['breakdown']['payments']:,.2f}"
            ])
        
        return output.getvalue()
