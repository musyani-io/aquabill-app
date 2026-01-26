"""API v1 router."""

from fastapi import APIRouter
from app.api.v1 import auth


api_router = APIRouter()

# Include authentication routes
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])

# TODO: Add more routers as we implement them:
# api_router.include_router(clients.router, prefix="/clients", tags=["clients"])
# api_router.include_router(meters.router, prefix="/meters", tags=["meters"])
# api_router.include_router(cycles.router, prefix="/cycles", tags=["cycles"])
# api_router.include_router(readings.router, prefix="/readings", tags=["readings"])
# api_router.include_router(ledger.router, prefix="/ledger", tags=["ledger"])
# api_router.include_router(payments.router, prefix="/payments", tags=["payments"])
# api_router.include_router(penalties.router, prefix="/penalties", tags=["penalties"])
# api_router.include_router(alerts.router, prefix="/alerts", tags=["alerts"])
# api_router.include_router(sms.router, prefix="/sms", tags=["sms"])
# api_router.include_router(sync.router, prefix="/sync", tags=["sync"])
# api_router.include_router(exports.router, prefix="/exports", tags=["exports"])
