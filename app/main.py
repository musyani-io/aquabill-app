from fastapi import FastAPI, Response

from app.api.routes.health import router as health_router
from app.api.routes.clients import router as clients_router
from app.api.routes.meters import router as meters_router
from app.api.routes.meter_assignments import router as meter_assignments_router
from app.api.routes.cycles import router as cycles_router
from app.api.routes.readings import router as readings_router
from app.api.routes.anomaly_conflict import router as anomaly_conflict_router
from app.api.routes.billing import router as billing_router
from app.api.routes.audit_logs import router as audit_logs_router
from app.api.routes.sms import router as sms_router

app = FastAPI(title="AquaBill API", version="0.1.0")


@app.get("/")
def root():
    return {"status": "Initialized", "message": "AquaBill API is running"}


@app.get("/favicon.ico", include_in_schema=False)
def favicon():
    return Response(status_code=204)


app.include_router(health_router, prefix="/api/v1")
app.include_router(clients_router, prefix="/api/v1")
app.include_router(meters_router, prefix="/api/v1")
app.include_router(meter_assignments_router, prefix="/api/v1")
app.include_router(cycles_router, prefix="/api/v1")
app.include_router(readings_router, prefix="/api/v1")
app.include_router(anomaly_conflict_router, prefix="/api/v1")
app.include_router(billing_router, prefix="/api/v1")
app.include_router(audit_logs_router, prefix="/api/v1")
app.include_router(sms_router, prefix="/api/v1/sms", tags=["sms"])
