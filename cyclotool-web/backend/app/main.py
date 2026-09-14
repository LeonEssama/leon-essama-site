"""CycloTool Web API entrypoint.

Run with: uvicorn app.main:app --reload --port 8000
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.busbar import router as busbar_router
from app.api.engineering_data import router as engineering_data_router

app = FastAPI(
    title="CycloTool API",
    description=(
        "Cycloconverter dimensioning/analysis engine -- Python/FastAPI port "
        "of the MATLAB CycloTool. See /docs for interactive API docs."
    ),
    version="0.1.0",
)

# Vite's default dev server port. Tighten this before deploying anywhere
# other than a developer's own machine.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(busbar_router)
app.include_router(engineering_data_router)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
