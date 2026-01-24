# AquaBill API Contract

## Base URL

```bash
https://api.aquabill.app/api/v1
```

## Authentication

All endpoints (except `/auth/login`) require Bearer token in Authorization header:

```bash
Authorization: Bearer <jwt_token>
```

## Authentication Endpoints

### POST /auth/login

Login and get JWT token.

**Request:**

```json
{
	"username": "collector1",
	"password": "password123"
}
```

**Response:**

```json
{
	"access_token": "eyJhbGc...",
	"token_type": "bearer",
	"user": {
		"id": 1,
		"username": "collector1",
		"role": "COLLECTOR"
	}
}
```

---

## Client Management (Admin Only)

### GET /clients

List all clients.

**Query Parameters:**

- `skip`: Offset for pagination (default: 0)
- `limit`: Number of results (default: 10)
- `search`: Search by name or phone

**Response:**

```json
{
	"items": [
		{
			"id": 1,
			"first_name": "John",
			"surname": "Doe",
			"phone_number": "+255700123456",
			"client_code": "C001"
		}
	],
	"total": 100
}
```

### POST /clients

Create a new client.

**Request:**

```json
{
	"first_name": "John",
	"other_names": "Michael",
	"surname": "Doe",
	"phone_number": "+255700123456"
}
```

**Response:**

```json
{
	"id": 1,
	"first_name": "John",
	"surname": "Doe",
	"phone_number": "+255700123456"
}
```

---

## Meter Management (Admin Only)

### POST /meters

Create a new meter.

**Request:**

```json
{
	"serial_number": "MTR-2024-001",
	"max_reading": 99999.9999
}
```

**Response:**

```json
{
	"id": 1,
	"serial_number": "MTR-2024-001",
	"max_reading": 99999.9999,
	"alert_threshold": 90000.0
}
```

### POST /meters/{meter_id}/assign

Assign meter to client.

**Request:**

```json
{
	"client_id": 1,
	"start_date": "2024-01-15"
}
```

**Response:**

```json
{
	"id": 1,
	"meter_id": 1,
	"client_id": 1,
	"start_date": "2024-01-15",
	"is_active": true
}
```

---

## Reading Submission (Collector)

### GET /collectors/clients

Get list of assigned clients (offline-cached).

**Response:**

```json
{
	"items": [
		{
			"id": 1,
			"first_name": "John",
			"surname": "Doe",
			"phone_number": "+255700123456",
			"meters": [
				{
					"id": 1,
					"assignment_id": 1,
					"serial_number": "MTR-2024-001",
					"previous_reading": 1234.5678
				}
			]
		}
	]
}
```

### POST /readings/submit

Submit a meter reading.

**Request:**

```json
{
	"cycle_id": 1,
	"assignment_id": 1,
	"reading_value": 1250.1234
}
```

**Response:**

```json
{
	"id": 1,
	"reading_value": 1250.1234,
	"status": "SUBMITTED",
	"submitted_at": "2024-01-15T10:30:00Z"
}
```

**Error Responses:**

- `400`: Late submission (outside ±5 day window)
- `409`: Conflict (duplicate reading detected)

---

## Reading Approval (Admin)

### GET /readings

Get readings for approval.

**Query Parameters:**

- `cycle_id`: Filter by cycle
- `status`: SUBMITTED, APPROVED, REJECTED

**Response:**

```json
{
	"items": [
		{
			"id": 1,
			"client": { "first_name": "John", "surname": "Doe" },
			"meter": { "serial_number": "MTR-2024-001" },
			"reading_value": 1250.1234,
			"status": "SUBMITTED"
		}
	]
}
```

### POST /readings/{reading_id}/approve

Approve a reading.

**Request:**

```json
{
	"notes": "Reading verified"
}
```

**Response:**

```json
{
	"id": 1,
	"status": "APPROVED",
	"approved_at": "2024-01-15T11:00:00Z"
}
```

---

## Billing & Ledger

### GET /ledger

Get client ledger entries.

**Query Parameters:**

- `client_id`: Required
- `start_date`: Filter by date range
- `end_date`: Filter by date range

**Response:**

```json
{
	"entries": [
		{
			"id": 1,
			"type": "CHARGE",
			"amount": 46037,
			"description": "Water consumption 15.3456 m³",
			"balance_after": 46037,
			"created_at": "2024-01-15T12:00:00Z"
		}
	],
	"current_balance": 46037
}
```

### POST /payments

Record a payment.

**Request:**

```json
{
	"client_id": 1,
	"amount": 46037
}
```

**Response:**

```json
{
	"id": 1,
	"client_id": 1,
	"amount": 46037,
	"payment_date": "2024-01-15T13:00:00Z",
	"new_balance": 0
}
```

---

## SMS Management

### POST /sms/send

Send SMS notification (admin).

**Request:**

```json
{
	"client_id": 1,
	"message": "Your bill is TZS 46,037. Please pay within 30 days."
}
```

**Response:**

```json
{
	"id": 1,
	"status": "PENDING",
	"delivery_attempts": 1
}
```

### POST /sms/callback

SMS delivery callback (webhook from provider).

**Request:**

```json
{
	"message_id": "sms-1",
	"status": "DELIVERED"
}
```

---

## Sync Endpoint (Mobile)

### POST /sync

Sync mobile app data and submit readings.

**Request:**

```json
{
	"readings": [
		{
			"id": "local-1",
			"cycle_id": 1,
			"assignment_id": 1,
			"reading_value": 1250.1234,
			"submitted_at": "2024-01-15T10:30:00Z"
		}
	]
}
```

**Response:**

```json
{
	"synced": [
		{
			"id": "local-1",
			"server_id": 1,
			"status": "SUCCESS"
		}
	],
	"conflicts": [
		{
			"id": "local-2",
			"error": "CONFLICT",
			"message": "Duplicate reading detected"
		}
	]
}
```

---

## Error Responses

### Standard Error Format

```json
{
	"detail": "Error message",
	"error_code": "RESOURCE_NOT_FOUND"
}
```

### Common Status Codes

- `200`: Success
- `201`: Created
- `400`: Bad request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not found
- `409`: Conflict
- `500`: Server error
