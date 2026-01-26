from fastapi import FastAPI

from app.api.routes.health import router as health_router
from app.api.routes.clients import router as clients_router

app = FastAPI(title="AquaBill API", version="0.1.0")

app.include_router(health_router, prefix="/api/v1")
app.include_router(clients_router, prefix="/api/v1")
