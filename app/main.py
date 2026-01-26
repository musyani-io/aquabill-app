from fastapi import FastAPI, Response

from app.api.routes.health import router as health_router
from app.api.routes.clients import router as clients_router
from app.api.routes.meters import router as meters_router
from app.api.routes.meter_assignments import router as meter_assignments_router

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
