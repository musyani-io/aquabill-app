# API Reference

Complete API documentation for AquaBill backend endpoints.

**Base URL**: `http://localhost:8000` (development) | `https://your-domain.com` (production)

**API Version**: v1

**Last Updated**: January 2026

---

## Authentication

Most endpoints require authentication via Bearer token in the Authorization header:

```http
Authorization: Bearer <your-token-here>
```

### Mobile Authentication

Mobile endpoints use a pre-shared bearer token configured by the admin:

```bash
# Backend generates token
curl -X POST http://localhost:8000/api/v1/admin/mobile-tokens \
  -H "Authorization: Bearer <admin-token>" \
  -d '{"collector_name": "John Doe", "device_id": "android_abc123"}'
```

Response:

```json
{
	"token": "mob_abc123xyz...",
	"collector_name": "John Doe",
	"expires_at": "2026-12-31T23:59:59Z"
}
```

---

## Mobile Endpoints

### Bootstrap (First Sync)

Fetches complete dataset for the last 12 billing cycles.

**Endpoint**: `GET /api/v1/mobile/bootstrap`

**Auth**: Required (Bearer token)

**Query Parameters**: None

**Response** (200 OK):

```json
{
  "cycles": [
    {
      "id": 12,
      "name": "January 2026",
      "start_date": "2026-01-01",
      "end_date": "2026-01-31",
      "target_date": "2026-02-05",
      "status": "OPEN",
      "updated_at": "2026-01-01T00:00:00Z"
    }
  ],
  "clients": [
    {
      "id": 1,
      "client_code": "C001",
      "first_name": "John",
      "other_names": "Paul",
      "surname": "Doe",
      "phone_number": "+255712345678",
      "updated_at": "2026-01-15T10:30:00Z"
    }
  ],
  "meters": [...],
  "meter_assignments": [...],
  "readings": [...],
  "conflicts": []
}
```

**Use Case**: First-time app installation or after clearing local data.

---

### Incremental Updates

Fetches changes since last sync timestamp.

**Endpoint**: `GET /api/v1/mobile/updates`

**Auth**: Required (Bearer token)

**Query Parameters**:

- `since` (required): ISO 8601 timestamp (e.g., `2026-01-20T10:30:00Z`)

**Response** (200 OK):

```json
{
  "cycles": [...],
  "clients": [...],
  "meters": [...],
  "meter_assignments": [...],
  "readings": [...],
  "conflicts": [...],
  "tombstones": [
    {
      "entity_type": "reading",
      "entity_id": 456,
      "deleted_at": "2026-01-25T14:00:00Z"
    }
  ]
}
```

**Tombstones**: Entities deleted on server. Mobile should remove from local cache.

**Use Case**: Periodic background sync to stay up-to-date.

---

### Submit Reading

Submits a new meter reading from mobile device.

**Endpoint**: `POST /api/v1/mobile/readings`

**Auth**: Required (Bearer token)

**Request Body**:

```json
{
	"meter_assignment_id": 5,
	"cycle_id": 12,
	"absolute_value": 1234.5678,
	"submitted_by": "mobile-user",
	"submitted_at": "2026-01-26T10:30:00Z",
	"client_tz": "Africa/Dar_es_Salaam",
	"source": "mobile",
	"previous_approved_reading": 1200.0,
	"device_id": "android_abc123",
	"app_version": "1.0.0",
	"conflict_id": null,
	"submission_notes": "Meter located outside gate"
}
```

**Response** (201 Created):

```json
{
	"id": 789,
	"status": "SUBMITTED",
	"message": "Reading submitted successfully"
}
```

**Response** (409 Conflict):

```json
{
	"error": "Conflict detected",
	"conflict_id": 42,
	"local_value": 1234.5678,
	"server_value": 1250.0,
	"message": "A different reading exists for this assignment and cycle"
}
```

**Validation**:

- `absolute_value` must be > 0
- `meter_assignment_id` must exist and be ACTIVE
- `cycle_id` must exist and be in last 12 cycles
- Rollover detection if current < previous and previous >= 90000

**Use Case**: Field collector submits reading offline, syncs later.

---

### Resolve Conflict

Accepts server value and marks conflict as resolved.

**Endpoint**: `POST /api/v1/mobile/conflicts/{conflict_id}/resolve`

**Auth**: Required (Bearer token)

**Path Parameters**:

- `conflict_id` (required): Integer ID of conflict

**Request Body**:

```json
{
	"action": "accept_server"
}
```

**Response** (200 OK):

```json
{
	"message": "Conflict resolved",
	"conflict_id": 42,
	"accepted_value": 1250.0
}
```

**Response** (404 Not Found):

```json
{
	"error": "Conflict not found"
}
```

**Use Case**: User reviews conflict in app and accepts server-wins policy.

---

## Admin Endpoints

### Create Client

**Endpoint**: `POST /api/v1/clients`

**Auth**: Required (Admin token)

**Request Body**:

```json
{
	"first_name": "Jane",
	"other_names": "Marie",
	"surname": "Smith",
	"phone_number": "+255723456789",
	"client_code": "C002"
}
```

**Response** (201 Created):

```json
{
	"id": 2,
	"client_code": "C002",
	"first_name": "Jane",
	"other_names": "Marie",
	"surname": "Smith",
	"phone_number": "+255723456789",
	"created_at": "2026-01-26T11:00:00Z"
}
```

---

### List Clients

**Endpoint**: `GET /api/v1/clients`

**Auth**: Required (Admin token)

**Query Parameters**:

- `skip` (optional): Offset for pagination (default: 0)
- `limit` (optional): Max results (default: 100, max: 1000)
- `search` (optional): Search by name or phone

**Response** (200 OK):

```json
{
	"total": 150,
	"items": [
		{
			"id": 1,
			"client_code": "C001",
			"first_name": "John",
			"surname": "Doe",
			"phone_number": "+255712345678"
		}
	]
}
```

---

### Create Meter Assignment

**Endpoint**: `POST /api/v1/meter-assignments`

**Auth**: Required (Admin token)

**Request Body**:

```json
{
	"meter_id": 10,
	"client_id": 5,
	"start_date": "2026-02-01",
	"baseline_reading": 1000.0,
	"max_meter_value": 99999.9999
}
```

**Response** (201 Created):

```json
{
	"id": 25,
	"meter_id": 10,
	"client_id": 5,
	"status": "ACTIVE",
	"start_date": "2026-02-01",
	"baseline_reading": 1000.0
}
```

**Validation**:

- Meter must not have another ACTIVE assignment
- Baseline reading requires admin approval before billing starts

---

### Approve Reading

**Endpoint**: `POST /api/v1/readings/{reading_id}/approve`

**Auth**: Required (Admin token)

**Request Body**:

```json
{
	"approved_by": "admin@aquabill.com",
	"notes": "Verified with photo"
}
```

**Response** (200 OK):

```json
{
	"id": 789,
	"status": "ACCEPTED",
	"approved_at": "2026-01-26T12:00:00Z",
	"consumption": 34.5678,
	"charges_generated": true
}
```

**Side Effects**:

- Creates ledger_entry with CHARGE type
- Calculates consumption (current - previous)
- Triggers SMS notification to client
- Updates cycle status if all readings approved

---

### Create Cycle

**Endpoint**: `POST /api/v1/cycles`

**Auth**: Required (Admin token)

**Request Body**:

```json
{
	"name": "February 2026",
	"start_date": "2026-02-01",
	"end_date": "2026-02-28",
	"target_date": "2026-03-05"
}
```

**Response** (201 Created):

```json
{
	"id": 13,
	"name": "February 2026",
	"status": "OPEN",
	"start_date": "2026-02-01",
	"end_date": "2026-02-28",
	"target_date": "2026-03-05"
}
```

**Validation**:

- Dates must not overlap with existing cycles
- Auto-transitions to OPEN status

---

### Record Payment

**Endpoint**: `POST /api/v1/payments`

**Auth**: Required (Admin token)

**Request Body**:

```json
{
	"client_id": 5,
	"amount": 50000.0,
	"received_at": "2026-01-26T14:30:00Z",
	"payment_method": "CASH",
	"reference": "RCT-2026-001"
}
```

**Response** (201 Created):

```json
{
	"id": 100,
	"client_id": 5,
	"amount": 50000.0,
	"applied_fifo": [
		{ "cycle_id": 11, "amount": 35000.0 },
		{ "cycle_id": 12, "amount": 15000.0 }
	],
	"remaining_credit": 0.0
}
```

**FIFO Logic**: Payment applied to oldest unpaid charges first.

---

### Apply Penalty

**Endpoint**: `POST /api/v1/penalties`

**Auth**: Required (Admin token)

**Request Body**:

```json
{
	"client_id": 5,
	"amount": 10000.0,
	"reason": "Late payment fee",
	"notes": "3 months overdue"
}
```

**Response** (201 Created):

```json
{
	"id": 50,
	"client_id": 5,
	"amount": 10000.0,
	"active": true,
	"applied_at": "2026-01-26T15:00:00Z"
}
```

**Audit**: All penalties logged in audit_log with admin user ID.

---

### Get Client Balance

**Endpoint**: `GET /api/v1/clients/{client_id}/balance`

**Auth**: Required (Admin token)

**Response** (200 OK):

```json
{
	"client_id": 5,
	"total_charges": 250000.0,
	"total_payments": 200000.0,
	"total_penalties": 10000.0,
	"net_balance": 60000.0,
	"credit_balance": 0.0,
	"last_payment_date": "2026-01-26T14:30:00Z"
}
```

**Derivation**: Sum of ledger_entries by type.

---

### Export Cycle Data

**Endpoint**: `GET /api/v1/cycles/{cycle_id}/export`

**Auth**: Required (Admin token)

**Query Parameters**:

- `format` (optional): `json` (default) or `csv`

**Response** (200 OK):

- JSON: Array of readings with client/meter details
- CSV: Download with filename `cycle_{id}_{name}.csv`

**Use Case**: Monthly billing report generation.

---

### Archive Old Cycles

**Endpoint**: `POST /api/v1/admin/archive`

**Auth**: Required (Admin token)

**Request Body**:

```json
{
	"before_date": "2023-01-01",
	"confirm": true
}
```

**Response** (200 OK):

```json
{
	"archived_cycles": 36,
	"archived_readings": 15000,
	"archived_payments": 8000,
	"message": "Data moved to archives_* tables"
}
```

**Note**: Archived data is read-only and excluded from regular queries.

---

## Health & System Endpoints

### Health Check

**Endpoint**: `GET /api/v1/health`

**Auth**: None

**Response** (200 OK):

```json
{
	"status": "healthy",
	"database": "connected",
	"version": "1.0.0",
	"timestamp": "2026-01-26T16:00:00Z"
}
```

---

### SMS Delivery Callback

**Endpoint**: `POST /api/v1/sms/callback`

**Auth**: Webhook signature verification

**Request Body** (from SMS gateway):

```json
{
	"message_id": "msg_abc123",
	"status": "delivered",
	"delivered_at": "2026-01-26T12:05:00Z",
	"failure_reason": null
}
```

**Response** (200 OK):

```json
{
	"acknowledged": true
}
```

**Idempotency**: Multiple callbacks for same message_id are safe.

---

## Error Responses

All errors follow this format:

```json
{
	"error": "Brief error message",
	"detail": "Detailed explanation",
	"code": "ERROR_CODE",
	"timestamp": "2026-01-26T16:30:00Z"
}
```

### HTTP Status Codes

- **200 OK**: Success
- **201 Created**: Resource created
- **400 Bad Request**: Invalid input
- **401 Unauthorized**: Missing/invalid token
- **403 Forbidden**: Insufficient permissions
- **404 Not Found**: Resource doesn't exist
- **409 Conflict**: Data conflict (e.g., duplicate reading)
- **422 Unprocessable Entity**: Validation failed
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server error
- **503 Service Unavailable**: Maintenance mode

---

## Rate Limiting

- **Mobile endpoints**: 100 requests/minute per token
- **Admin endpoints**: 1000 requests/minute per token
- **Public endpoints**: 20 requests/minute per IP

Headers returned:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1643212800
```

---

## Pagination

List endpoints support pagination:

**Query Parameters**:

- `skip`: Number of records to skip (default: 0)
- `limit`: Max records to return (default: 100, max: 1000)

**Response**:

```json
{
  "total": 500,
  "skip": 0,
  "limit": 100,
  "items": [...]
}
```

---

## Filtering & Sorting

### Filtering

Add query parameters:

```bash
GET /api/v1/readings?status=SUBMITTED&cycle_id=12
```

### Sorting

Use `sort_by` and `order`:

```bashs
GET /api/v1/clients?sort_by=surname&order=asc
```

---

## Webhooks

Configure webhooks for real-time notifications:

**Events**:

- `reading.submitted`
- `reading.approved`
- `payment.received`
- `cycle.closed`
- `sms.delivered`
- `sms.failed`

**Payload**:

```json
{
	"event": "reading.approved",
	"data": {
		"reading_id": 789,
		"client_id": 5,
		"cycle_id": 12,
		"consumption": 34.5678
	},
	"timestamp": "2026-01-26T12:00:00Z"
}
```

**Configuration**: Admin panel → Settings → Webhooks

---

## Testing

Use the provided API test collection:

**Postman**:

```bash
# Import collection
postman import docs/postman_collection.json
```

**cURL Examples**:

```bash
# Bootstrap
curl -H "Authorization: Bearer <token>" \
  http://localhost:8000/api/v1/mobile/bootstrap

# Submit reading
curl -X POST \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"meter_assignment_id":5,"cycle_id":12,"absolute_value":1234.5678}' \
  http://localhost:8000/api/v1/mobile/readings
```

---

## Versioning

API version is in the URL path (`/api/v1/`). Breaking changes increment the version.

**Current Version**: v1  
**Deprecation Policy**: 6 months notice before v1 sunset

---

## Support

- **Documentation**: [GitHub Wiki](https://github.com/your-org/aquabill-app/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-org/aquabill-app/issues)
- **Email**: <support@aquabill.example.com>
