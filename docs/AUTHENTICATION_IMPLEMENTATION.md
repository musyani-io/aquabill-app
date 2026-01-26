# Authentication System Implementation Guide

## Overview

Complete authentication system with role-based access control (Admin and Collector) for AquaBill. This integrates the Flutter mobile app with the FastAPI backend.

## Files Created/Modified

### Backend (Python/FastAPI)

#### New Files Created

1. **app/schemas/auth.py** - Pydantic validation models
   - `AdminRegisterRequest` - Admin signup payload
   - `AdminLoginRequest` - Admin login payload
   - `AdminLoginResponse` - Login response with token
   - `CollectorCreateRequest` - Create collector payload
   - `CollectorLoginRequest` - Collector login payload
   - `CollectorLoginResponse` - Collector login response
   - `CollectorResponse` - Single collector details
   - `CollectorListResponse` - List of collectors

2. **app/services/auth_service.py** - Authentication business logic
   - `hash_password()` - Bcrypt password hashing
   - `verify_password()` - Password validation
   - `create_access_token()` - JWT token generation (HS256)
   - `decode_token()` - JWT token parsing
   - `decode_admin_token()` - Extract admin ID from token
   - `decode_collector_token()` - Extract collector ID from token
   - Configuration: 30-day token expiration, bcrypt hashing

3. **app/api/routes/auth.py** - FastAPI authentication endpoints
   - Admin routes under `/api/v1/auth/`
   - Collector routes under `/api/v1/admin/`
   - Token extraction from Authorization header
   - Admin dependency for protected routes

4. **migrations/versions/0011_authentication.py** - Database migration
   - Creates `admin_users` table with:
     - id (PK), username (unique), password_hash
     - company_name, company_phone, role_at_company, estimated_clients
     - created_at, updated_at with server defaults
   - Creates `collector_users` table with:
     - id (PK), admin_id (FK), name, password_hash
     - is_active (default=true), created_at, updated_at
     - CASCADE delete on admin deletion
   - Indexes on username and admin_id for performance

#### Modified Files

1. **app/main.py**
   - Added imports for auth routers
   - Registered auth_router and admin_auth_router in FastAPI app

2. **app/models/auth.py** (already existed)
   - SQLAlchemy ORM models for AdminUser and CollectorUser

3. **requirements.txt**
   - Added `passlib[bcrypt]>=1.7.4` - Password hashing
   - Added `python-jose[cryptography]>=3.3.0` - JWT tokens

### Mobile (Flutter/Dart)

#### New Files Created

1. **mobile/lib/data/remote/auth_dtos.dart** - Data transfer objects
   - Request/response classes for API communication
   - DTOs: AdminRegisterRequest, AdminLoginRequest, LoginResponse
   - CollectorLoginRequest, CollectorCreateRequest, CollectorResponse
   - CollectorListResponse for list operations

2. **mobile/lib/data/remote/auth_api_client.dart** - HTTP client
   - `registerAdmin()` - POST /api/v1/auth/admin/register
   - `loginAdmin()` - POST /api/v1/auth/admin/login
   - `loginCollector()` - POST /api/v1/auth/collector/login
   - `createCollector()` - POST /api/v1/admin/collectors (requires token)
   - `listCollectors()` - GET /api/v1/admin/collectors (requires token)
   - `deleteCollector()` - DELETE /api/v1/admin/collectors/{id} (requires token)
   - Error handling with custom ApiException

3. **mobile/lib/core/config.dart** - Application configuration
   - `apiBaseUrl` - API endpoint (<http://localhost:8000>)
   - Timeout settings, database name, debug mode

#### Modified Files

1. **mobile/lib/ui/login_screen.dart**
   - Calls `AuthApiClient.loginAdmin()` for admin login
   - Validates credentials against backend
   - Proper error handling and loading states

2. **mobile/lib/ui/signup_screen.dart**
   - Calls `AuthApiClient.registerAdmin()` for account creation
   - Validates all 7 form fields (username, password, company details)
   - Auto-login after successful registration

3. **mobile/lib/ui/admin_screen.dart**
   - `_loadCollectors()` - Fetches collectors from backend on init
   - `_addCollector()` - Creates new collector via API
   - `_deleteCollector()` - Deletes collector via API
   - Proper token management and error handling

4. **mobile/lib/core/auth_service.dart**
   - Added `getToken()` method to retrieve stored authentication token

## API Endpoints

### Admin Authentication

```bash
POST /api/v1/auth/admin/register
- Request: AdminRegisterRequest (username, password, company details)
- Response: LoginResponse (token, user_id, username, company_name)
- Status: 200 OK or 400 Bad Request

POST /api/v1/auth/admin/login
- Request: AdminLoginRequest (username, password)
- Response: LoginResponse (token, user_id, username, company_name)
- Status: 200 OK or 401 Unauthorized
```

### Collector Management (Admin Only)

```bash
POST /api/v1/admin/collectors
- Headers: Authorization: Bearer <admin_token>
- Request: CollectorCreateRequest (name, password)
- Response: CollectorResponse (id, name, is_active, created_at)
- Status: 200 OK or 401 Unauthorized

GET /api/v1/admin/collectors
- Headers: Authorization: Bearer <admin_token>
- Response: CollectorListResponse (total, collectors[])
- Status: 200 OK or 401 Unauthorized

DELETE /api/v1/admin/collectors/{collector_id}
- Headers: Authorization: Bearer <admin_token>
- Status: 204 No Content or 401 Unauthorized or 404 Not Found

POST /api/v1/auth/collector/login
- Query: collector_id
- Request: CollectorLoginRequest (password)
- Response: LoginResponse (token, collector_id, name)
- Status: 200 OK or 401 Unauthorized
```

## Authentication Flow

### Admin Registration

1. User fills admin signup form (7 fields)
2. Mobile app validates form locally
3. POST to /api/v1/auth/admin/register with form data
4. Backend validates and checks username uniqueness
5. Backend hashes password with bcrypt
6. Backend creates AdminUser record
7. Backend generates JWT token (admin_id in payload)
8. Response includes token + user details
9. Mobile app stores token in secure storage
10. Mobile app stores role (admin) and username
11. Navigate to home with role-based nav

### Admin Login

1. User enters username + password
2. POST to /api/v1/auth/admin/login
3. Backend finds user by username
4. Backend verifies password against hash
5. Backend generates JWT token
6. Response includes token + company_name
7. Mobile app stores token and navigates home

### Collector Account Creation (Admin)

1. Admin clicks "Add Collector" button
2. Admin enters collector name + password
3. POST to /api/v1/admin/collectors with Authorization header
4. Backend validates admin token and extracts admin_id
5. Backend hashes collector password
6. Backend creates CollectorUser linked to admin
7. Response includes collector details
8. Mobile app adds to local list and shows confirmation

### Collector List (Admin)

1. Admin screen loads on init
2. GET to /api/v1/admin/collectors with token
3. Backend returns all collectors for this admin
4. Mobile displays in list with name, created date, delete button

### Collector Login

1. Collector enters password only (no username)
2. POST to /api/v1/auth/collector/login?collector_id={id} with password
3. Backend finds collector by ID
4. Backend verifies password and active status
5. Backend generates JWT token with collector_id
6. Mobile app stores token and navigates to collector view

## Security Features

### Password Security

- Bcrypt hashing with default salt rounds
- Passwords never stored in plain text
- Passwords never transmitted without HTTPS (in production)

### Token Security

- JWT tokens with HS256 algorithm
- 30-day expiration (configurable)
- Token payload contains user ID, username, and user type
- Tokens extracted from Authorization: Bearer {token} header
- Tokens stored in device secure storage (flutter_secure_storage)

### Admin Authorization

- Protected routes require valid admin token
- Token extracted and decoded before processing
- Admin ID verified against database
- Collectors can only be created/deleted by their admin

### Data Protection

- Cascade delete: deleting admin deletes all their collectors
- Collectors linked to admins via foreign key
- CollectorUser.is_active flag for soft disable

## Database Schema

### admin_users Table

```sql
CREATE TABLE admin_users (
    id INTEGER PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    company_phone VARCHAR(20) NOT NULL,
    role_at_company VARCHAR(100) NOT NULL,
    estimated_clients INTEGER NOT NULL,
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NOW()
);
```

### collector_users Table

```sql
CREATE TABLE collector_users (
    id INTEGER PRIMARY KEY,
    admin_id INTEGER NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NOW()
);
```

## Setup Instructions

### Backend Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Run database migration
alembic upgrade head

# Start server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Mobile Setup

```bash
# Update API base URL in mobile/lib/core/config.dart if needed
# Default: http://localhost:8000

# Build and run
flutter pub get
flutter run
```

## Testing Workflow

### Test Admin Registration

1. Open app, select "Admin" role
2. Click "Sign Up" button
3. Fill form:
   - Username: testadmin
   - Password: Password123
   - Company: Test Company
   - Phone: +255712345678
   - Role: Manager
   - Clients: 100
4. Click Create Admin Account
5. Should see admin screen with empty collectors list

### Test Collector Creation

1. Login as admin (from previous test)
2. Click Add Collector FAB
3. Enter:
   - Name: John Collector
   - Password: pass123
4. Click Add
5. Should appear in list immediately

### Test Collector Deletion

1. Click delete icon on collector
2. Confirm deletion
3. Collector removed from list

### Test Collector Login

1. Logout from admin account
2. Select "Collector" role
3. Note: Collector login requires being able to list collectors first
4. This would require additional UI to display list of collectors
5. Currently collector login only works if collector_id is known

## Error Handling

### Frontend Error Messages

- "Login failed: ..." - Backend validation or network error
- "Failed to add collector: ..." - Backend error during creation
- "Failed to delete collector: ..." - Authorization or not found error
- "No authentication token found" - User logged out or session expired

### Backend Error Responses

- 400 Bad Request - Validation failure (username exists, short password, etc.)
- 401 Unauthorized - Invalid credentials or expired token
- 404 Not Found - Collector not found for delete operation
- 500 Internal Server Error - Unexpected server error

## Configuration

### Environment Variables

Create `.env` file:

```bash
# Backend
DATABASE_URL=postgresql://user:password@localhost/aquabill
SECRET_KEY=your-secret-key-here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_DAYS=30
```

### Mobile Configuration

Edit `mobile/lib/core/config.dart`:

```dart
class Config {
  static const String apiBaseUrl = 'http://your-server:8000';
  static const int apiTimeoutSeconds = 30;
}
```

## Next Steps / Future Enhancements

1. **Collector Login Improvement**
   - Create "Find Collector" screen to list all collectors
   - Allow collectors to login via name + password instead of just ID

2. **Password Reset**
   - Implement forgot password flow
   - Email verification for admins

3. **Session Management**
   - Token refresh mechanism
   - Automatic logout on token expiration

4. **Multi-factor Authentication**
   - Optional SMS/Email verification
   - Device trust management

5. **Audit Logging**
   - Log all authentication attempts
   - Track admin actions (collector creation/deletion)

6. **Role Enhancements**
   - Additional roles (supervisor, accountant)
   - Permission-based access control (RBAC)

7. **Password Policy**
   - Enforce complexity requirements
   - Password history to prevent reuse
   - Account lockout after failed attempts

## Troubleshooting

### "Connection refused" error

- Ensure backend is running on localhost:8000
- Check firewall settings
- Verify Config.apiBaseUrl is correct

### "Packages not installed" error

- Run `pip install -r requirements.txt`
- Run `flutter pub get`

### Database migration errors

- Check DATABASE_URL in .env
- Verify PostgreSQL is running
- Check migration files for syntax errors

### Token invalid/expired

- Clear app cache and reinstall
- Ensure system time is correct
- Check JWT_ALGORITHM and SECRET_KEY in .env

## References

- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [Flask-JWT-Extended](https://flask-jwt-extended.readthedocs.io/)
- [Passlib Bcrypt](https://passlib.readthedocs.io/en/stable/lib/passlib.context.html)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [SQLAlchemy Relationships](https://docs.sqlalchemy.org/en/20/orm/relationships.html)
