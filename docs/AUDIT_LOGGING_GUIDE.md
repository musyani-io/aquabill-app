# Audit Logging Decorator Usage Guide

## Overview

The `@audit_log` decorator automatically logs admin actions to the immutable audit trail. Use it on service methods that perform significant operations.

## Basic Usage

```python
from app.core.audit_decorator import audit_log
from app.models.audit_log import AuditAction

class ReadingService:
    @audit_log(
        action=AuditAction.READING_APPROVED,
        entity_type="reading",
        get_entity_id=lambda result: result[0].id if result[0] else None,
        description_template="Approved reading {reading_id} for meter assignment {meter_assignment_id}"
    )
    def approve_reading(self, reading_id: int, meter_assignment_id: int, admin_username: str, db: Session):
        # Your approval logic here
        reading, error = self.repository.approve(reading_id)
        return reading, error
```

## Parameters

- **action**: `AuditAction` enum value (e.g., `READING_APPROVED`, `PAYMENT_RECORDED`)
- **entity_type**: String describing entity type (e.g., `"reading"`, `"cycle"`, `"payment"`)
- **get_entity_id**: Function to extract entity ID from function result
- **description_template**: Template string with {kwargs} placeholders
- **get_metadata**: Optional function to extract additional metadata as dict
- **admin_username_key**: Key in kwargs for admin username (default: `"admin_username"`)

## Examples

### Reading Approval

```python
@audit_log(
    action=AuditAction.READING_APPROVED,
    entity_type="reading",
    get_entity_id=lambda result: result[0].id if result[0] else None,
    description_template="Approved reading {reading_id}"
)
def approve_reading(self, reading_id: int, admin_username: str, db: Session):
    ...
```

### Payment Recording

```python
@audit_log(
    action=AuditAction.PAYMENT_RECORDED,
    entity_type="payment",
    get_entity_id=lambda result: result[0].id if result[0] else None,
    description_template="Recorded payment of TZS {amount} for client {client_id}",
    get_metadata=lambda result: {"amount": float(result[0].amount), "method": result[0].method}
)
def record_payment(self, client_id: int, amount: Decimal, admin_username: str, db: Session):
    ...
```

### Penalty Application

```python
@audit_log(
    action=AuditAction.PENALTY_APPLIED,
    entity_type="penalty",
    get_entity_id=lambda result: result[0].id if result[0] else None,
    description_template="Applied penalty: {reason}"
)
def apply_penalty(self, meter_assignment_id: int, amount: Decimal, reason: str, admin_username: str, db: Session):
    ...
```

### Async Functions

```python
from app.core.audit_decorator import audit_log_async

@audit_log_async(
    action=AuditAction.DATA_EXPORTED,
    entity_type="export",
    get_entity_id=lambda result: result.get("export_id"),
    description_template="Exported {record_count} records"
)
async def export_data(self, record_count: int, admin_username: str, db: Session):
    ...
```

## Anomaly Logging Helpers

The `AnomalyService` provides helper methods for automatic anomaly detection:

```python
from app.services.anomaly_service import AnomalyService

service = AnomalyService(db)

# Log negative consumption (potential rollover)
service.log_negative_consumption(
    meter_assignment_id=123,
    cycle_id=45,
    reading_id=678,
    current_reading=Decimal("50.0"),
    previous_reading=Decimal("9850.0"),
    consumption=Decimal("-9800.0")
)

# Log rollover without meter limit configured
service.log_rollover_without_limit(
    meter_assignment_id=123,
    cycle_id=45,
    reading_id=678,
    meter_serial="MTR-001"
)

# Log double submission
service.log_double_submission(
    meter_assignment_id=123,
    cycle_id=45,
    reading_id=678,
    existing_reading_id=555
)

# Log late submission
service.log_late_submission(
    meter_assignment_id=123,
    cycle_id=45,
    reading_id=678,
    days_late=3
)

# Log missing baseline
service.log_missing_baseline(
    meter_assignment_id=123,
    cycle_id=45,
    meter_serial="MTR-001"
)
```

## Best Practices

1. **Always include admin_username** in function parameters
2. **Pass db Session** as parameter for audit logging to work
3. **Use descriptive templates** that include relevant context
4. **Don't catch audit log exceptions** - decorator handles errors gracefully
5. **Use get_metadata** for additional context (amounts, statuses, etc.)
6. **Call anomaly helpers** immediately when issues detected during processing

## Available Audit Actions

### Reading Management

- `READING_APPROVED`
- `READING_REJECTED`
- `READING_EDITED`
- `READING_DELETED`

### Cycle Management

- `CYCLE_CREATED`
- `CYCLE_STATE_CHANGED`
- `CYCLE_APPROVED`
- `CYCLE_CLOSED`
- `CYCLE_ARCHIVED`

### Conflict Resolution

- `CONFLICT_RESOLVED`
- `CONFLICT_ASSIGNED`
- `ANOMALY_ACKNOWLEDGED`

### Financial Actions

- `PENALTY_APPLIED`
- `PENALTY_WAIVED`
- `PAYMENT_RECORDED`
- `LEDGER_ADJUSTMENT`

### Meter Management

- `METER_ASSIGNED`
- `METER_UNASSIGNED`
- `METER_CREATED`

### Client Management

- `CLIENT_CREATED`
- `CLIENT_UPDATED`
- `CLIENT_DELETED`

### System Actions

- `DATA_EXPORTED`
- `BACKUP_CREATED`
- `SETTINGS_CHANGED`

## Anomaly Types

- `NEGATIVE_CONSUMPTION` - Consumption calculated as negative (rollover detected)
- `DOUBLE_SUBMISSION` - Multiple readings in same cycle
- `LATE_SUBMISSION` - Reading submitted after deadline
- `MISSING_BASELINE` - No baseline reading found
- `ROLLOVER_WITHOUT_LIMIT` - Rollover detected but meter max_digits unknown

## Anomaly Workflow

1. **DETECTED** - System automatically logs anomaly
2. **ACKNOWLEDGED** - Admin reviews via API: `POST /issues/anomalies/{id}/acknowledge`
3. **RESOLVED** - Admin fixes issue via API: `POST /issues/anomalies/{id}/resolve`

## Query Audit Logs

```bash
# Get all logs
GET /audit-logs?skip=0&limit=100

# Get logs by admin
GET /audit-logs/admin/{username}

# Get logs by action
GET /audit-logs/action/{action}

# Get logs for entity
GET /audit-logs/entity/{entity_type}/{entity_id}
```

## Query Anomalies

```bash
# List all anomalies
GET /issues/anomalies

# Get by status
GET /issues/anomalies/status/DETECTED

# Get by assignment
GET /issues/anomalies/assignment/{meter_assignment_id}

# Acknowledge
POST /issues/anomalies/{id}/acknowledge
{
  "acknowledged_by": "admin@example.com"
}

# Resolve
POST /issues/anomalies/{id}/resolve
{
  "resolved_by": "admin@example.com",
  "resolution_notes": "Verified meter rollover, consumption corrected"
}
```
