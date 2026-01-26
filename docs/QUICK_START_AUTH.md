# Quick Start Guide - Authentication System

## Prerequisites

- Python 3.10+ with pip
- PostgreSQL database running
- Flutter 3.0+ with Dart
- Git for version control

## Backend Setup (5 minutes)

### 1. Install Dependencies

```bash
cd /path/to/aquabill-app
pip install -r requirements.txt
```

Expected packages installed:

- fastapi, uvicorn, pydantic, sqlalchemy, psycopg2-binary
- alembic, python-dotenv, httpx, pytest
- **NEW**: passlib[bcrypt], python-jose[cryptography]

### 2. Configure Environment

Create `.env` file in project root:

```
DATABASE_URL=postgresql://postgres:password@localhost:5432/aquabill_db
SECRET_KEY=your-super-secret-key-change-this
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_DAYS=30
```

### 3. Create Database

```bash
# Create PostgreSQL database
createdb aquabill_db

# Run migrations
alembic upgrade head

# Verify tables created
# Should see: admin_users, collector_users tables
```

### 4. Start Backend Server

```bash
# Terminal 1: Start backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# You should see:
# ✓ Application startup complete
# ✓ Uvicorn running on http://0.0.0.0:8000
```

### 5. Verify Backend (Optional)

```bash
# In another terminal, test API
curl http://localhost:8000/api/v1/health/ping

# Expected response:
# {"status":"OK","message":"Database connection successful"}
```

## Mobile Setup (5 minutes)

### 1. Install Dependencies

```bash
cd mobile
flutter pub get
```

### 2. Configure API URL

Edit `lib/core/config.dart`:

```dart
class Config {
  static const String apiBaseUrl = 'http://localhost:8000';
  // For real device, use actual machine IP:
  // static const String apiBaseUrl = 'http://192.168.x.x:8000';
}
```

### 3. Run App

```bash
# Terminal 2: Run Flutter app
flutter run

# Or for specific device/platform:
flutter run -d chrome  # Web
flutter run -d android-emulator  # Android
```

## Quick Test Workflow

### Test 1: Admin Registration

```
1. App opens → Select "Admin" role
2. Click "Sign Up" button
3. Fill form:
   ✓ Username: testadmin
   ✓ Password: TestPass123 (remember this!)
   ✓ Company: Test Water Co
   ✓ Phone: +255712345678
   ✓ Role: Manager
   ✓ Clients: 100
4. Click "Create Admin Account"
5. Expected: Navigate to Admin screen with empty collectors
```

### Test 2: Add Collector

```
1. From admin screen, click "Add Collector" button
2. Enter:
   ✓ Name: John Mkumbo
   ✓ Password: john123
3. Click "Add"
4. Expected: Collector appears in list immediately
```

### Test 3: Delete Collector

```
1. From collector list, click trash icon on any collector
2. Confirm deletion
3. Expected: Collector removed from list
```

### Test 4: Admin Login (New Session)

```
1. Click "Logout" in settings
2. Login screen appears
3. Select "Admin" role
4. Enter:
   ✓ Username: testadmin
   ✓ Password: TestPass123
5. Click "Login"
6. Expected: Navigate to admin screen with previous collectors
```

## API Endpoint Testing

### Using cURL (for testing in terminal)

#### Register Admin

```bash
curl -X POST http://localhost:8000/api/v1/auth/admin/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "Pass123456",
    "confirm_password": "Pass123456",
    "company_name": "Water Corp",
    "company_phone": "+255712345678",
    "role_at_company": "Director",
    "estimated_clients": 500
  }'

# Expected response:
# {
#   "token": "eyJhbGciOiJIUzI1NiIs...",
#   "user_id": 1,
#   "username": "admin1",
#   "company_name": "Water Corp",
#   "role": "admin"
# }
```

#### Login Admin

```bash
curl -X POST http://localhost:8000/api/v1/auth/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "Pass123456"
  }'

# Expected response:
# {
#   "token": "eyJhbGciOiJIUzI1NiIs...",
#   "user_id": 1,
#   "username": "admin1",
#   "company_name": "Water Corp",
#   "role": "admin"
# }
```

#### Create Collector (use token from login)

```bash
TOKEN="paste_token_from_login_response_here"

curl -X POST http://localhost:8000/api/v1/admin/collectors \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Peter Collector",
    "password": "peter123"
  }'

# Expected response:
# {
#   "id": 1,
#   "name": "Peter Collector",
#   "is_active": true,
#   "created_at": "2024-01-26T12:00:00"
# }
```

#### List Collectors

```bash
curl -X GET http://localhost:8000/api/v1/admin/collectors \
  -H "Authorization: Bearer $TOKEN"

# Expected response:
# {
#   "total": 1,
#   "collectors": [
#     {
#       "id": 1,
#       "name": "Peter Collector",
#       "is_active": true,
#       "created_at": "2024-01-26T12:00:00"
#     }
#   ]
# }
```

## Common Issues & Solutions

### Issue: "Connection refused" at localhost:8000

```
Solution:
1. Verify backend is running: ps aux | grep uvicorn
2. Check if port 8000 is in use: lsof -i :8000
3. Kill process if needed: kill -9 <PID>
4. Restart backend
```

### Issue: "Packages not installed"

```
Solution:
# Backend
pip install -r requirements.txt

# Mobile
flutter clean
flutter pub get
```

### Issue: Database connection error

```
Solution:
1. Verify PostgreSQL running: psql -U postgres
2. Check DATABASE_URL in .env is correct
3. Verify database exists: createdb aquabill_db
4. Run migrations: alembic upgrade head
```

### Issue: "Invalid token" when creating collectors

```
Solution:
1. Token may have expired (30 days)
2. Login again to get fresh token
3. Ensure token is copied exactly from response
4. Header must be: Authorization: Bearer <token>
```

### Issue: "Username already exists"

```
Solution:
1. Choose different username
2. Or check admin_users table: SELECT * FROM admin_users;
3. Delete test data if needed
```

## Database Inspection

### View Admin Users

```bash
psql aquabill_db -c "SELECT id, username, company_name FROM admin_users;"
```

### View Collectors

```bash
psql aquabill_db -c "SELECT id, admin_id, name, is_active FROM collector_users;"
```

### Delete Test Data

```bash
psql aquabill_db -c "DELETE FROM admin_users WHERE username LIKE 'test%';"
# Note: Will cascade delete all their collectors
```

## Performance Testing

### Load Test (requires Apache Bench)

```bash
# Test login endpoint under load
ab -n 100 -c 10 -p login.json http://localhost:8000/api/v1/auth/admin/login

# login.json:
# {"username": "admin1", "password": "Pass123456"}
```

### Monitor Logs

```bash
# Watch backend logs for errors
tail -f backend.log

# Check response times in API responses
curl -w "\nTime: %{time_total}s\n" http://localhost:8000/api/v1/health/ping
```

## Next Steps

After confirming everything works:

1. **Deploy Backend**
   - Deploy to Render, Railway, or AWS
   - Update database URL for production
   - Set strong SECRET_KEY
   - Enable HTTPS

2. **Deploy Mobile**
   - Update apiBaseUrl to production server
   - Test on real device
   - Build APK/IPA
   - Submit to App Store / Play Store

3. **Setup Monitoring**
   - Error tracking (Sentry)
   - Performance monitoring (New Relic)
   - Database backups

4. **Security Hardening**
   - Add rate limiting
   - Implement password reset flow
   - Add audit logging
   - Enable CORS restrictions

## Support & Debugging

### Enable Debug Logging

```dart
// In mobile app, set in config.dart:
static const bool debugMode = true;

// Then check flutter logs
flutter logs
```

### Backend Debug Mode

```python
# In app/main.py, add:
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Database Query Logging

```python
# In app/db/session.py:
engine = create_engine(DATABASE_URL, echo=True)  # Shows all SQL
```

## Documentation

- Full Implementation Guide: `docs/AUTHENTICATION_IMPLEMENTATION.md`
- Backend Integration Summary: `docs/BACKEND_INTEGRATION_COMPLETE.md`
- API Reference: Check Swagger at `http://localhost:8000/docs`

## Version Information

- FastAPI: 0.110+
- Flutter: 3.0+
- Python: 3.10+
- PostgreSQL: 12+
- Dart: 3.10+

## Getting Help

1. Check error messages in terminal/logs
2. Review API responses for error details
3. Consult documentation files
4. Verify environment configuration
5. Test with cURL before mobile app

Good luck! 🚀
