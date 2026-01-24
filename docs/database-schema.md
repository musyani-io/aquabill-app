# Database Schema

## Overview

AquaBill uses PostgreSQL for persistent data storage with the following entities:

## Entity Relationship Diagram (ERD)

```bash
users
├── id (PK)
├── username (UNIQUE)
├── email
├── password_hash
├── role (COLLECTOR, ADMIN)
├── is_active
├── created_at

clients
├── id (PK)
├── first_name
├── other_names
├── surname
├── phone_number
├── client_code (reserved for future)
├── created_at
├── updated_at

meters
├── id (PK)
├── serial_number (UNIQUE)
├── max_reading (default: 99999.9999)
├── alert_threshold (90000.0000)
├── created_at

meter_assignments
├── id (PK)
├── meter_id (FK)
├── client_id (FK)
├── start_date
├── end_date (nullable)
├── is_active
├── created_at

cycles
├── id (PK)
├── name
├── start_date
├── end_date
├── status (OPEN, PENDING_REVIEW, APPROVED, CLOSED)
├── created_at
├── updated_at

readings
├── id (PK)
├── cycle_id (FK)
├── assignment_id (FK)
├── collector_id (FK)
├── reading_value (4 decimal places)
├── is_baseline
├── submitted_at
├── approved_at
├── approved_by (FK)
├── status (SUBMITTED, APPROVED, REJECTED)
├── created_at

ledger_entries
├── id (PK)
├── client_id (FK)
├── reading_id (FK nullable)
├── amount (TZS)
├── type (CHARGE, PAYMENT, PENALTY)
├── description
├── balance_before
├── balance_after
├── created_at

payments
├── id (PK)
├── client_id (FK)
├── amount (TZS)
├── payment_date
├── recorded_by (FK)
├── created_at

penalties
├── id (PK)
├── client_id (FK)
├── amount (TZS)
├── reason
├── applied_by (FK)
├── resolved_at (nullable)
├── is_resolved
├── created_at

alerts
├── id (PK)
├── client_id (FK)
├── reading_id (FK nullable)
├── alert_type (HIGH_CONSUMPTION, METER_ROLLBACK, METER_ROLLOVER)
├── description
├── is_acknowledged
├── acknowledged_at (nullable)
├── acknowledged_by (FK nullable)
├── created_at

sms_logs
├── id (PK)
├── client_id (FK)
├── phone_number
├── message
├── status (PENDING, SENT, FAILED, PERMANENTLY_FAILED)
├── delivery_attempts
├── last_attempt_at
├── created_at

audit_logs
├── id (PK)
├── user_id (FK)
├── action
├── resource_type
├── resource_id
├── changes
├── created_at

sync_conflicts
├── id (PK)
├── cycle_id (FK)
├── assignment_id (FK)
├── reading1_id (FK)
├── reading2_id (FK)
├── collector1_id (FK)
├── collector2_id (FK)
├── status (DETECTED, RESOLVED)
├── resolved_by (FK nullable)
├── resolution
├── created_at
```

## Table Descriptions

### users

Stores login credentials and role information for both collectors and admins.

**Indexes:**

- username (UNIQUE)
- email
- role

### clients

Water service clients identified by name and phone number.

**Indexes:**

- phone_number
- surname, first_name (composite for search)

### meters

Physical meter devices with unique serial numbers.

**Indexes:**

- serial_number (UNIQUE)

### meter_assignments

Links meters to clients for a specific period. A meter can be reassigned.

**Indexes:**

- client_id, is_active
- meter_id, is_active

### cycles

Billing cycles with state transitions.

**Indexes:**

- start_date, end_date
- status

### readings

Meter readings submitted by collectors and approved by admins.

**Indexes:**

- cycle_id, assignment_id (composite, for duplicate detection)
- submitted_at
- status

### ledger_entries

Immutable transaction log for all financial activity.

**Indexes:**

- client_id
- created_at
- type

### payments

Client payment records linked to ledger.

**Indexes:**

- client_id
- payment_date

### penalties

Manual penalty records with resolution tracking.

**Indexes:**

- client_id
- is_resolved

### alerts

System anomaly detection alerts.

**Indexes:**

- client_id
- alert_type
- is_acknowledged

### sms_logs

SMS delivery tracking with retry counts.

**Indexes:**

- client_id
- status

### audit_logs

Immutable admin action log for compliance.

**Indexes:**

- user_id
- created_at

### sync_conflicts

Tracks duplicate collector submissions for resolution.

**Indexes:**

- cycle_id, assignment_id
- status
