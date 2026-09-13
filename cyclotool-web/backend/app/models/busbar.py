"""Pydantic request/response models for the Busbar Check API.

Kept separate from the calc-layer dataclasses (app/calc/busbar/*) on
purpose: the calc layer is plain Python with no web-framework
dependency, so it can be unit-tested and reused (e.g. by the report
generator) without importing FastAPI/Pydantic at all.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

Location = Literal["indoor", "outdoor"]
BandGapRule = Literal["conservative", "error"]


class BusbarSectionIn(BaseModel):
    name: str
    name_en: str
    profile: str
    current_basis: Literal["Motor", "Line", "Stack"]
    freq_basis: Literal["Motor", "Line"]
    orientation: Literal["horizontal", "vertical"]
    run_length_m: float | None = None
    k3_override: float | None = None


class BusbarCheckRequest(BaseModel):
    IM: float = Field(..., gt=0, description="Nominal machine current [A]")
    u_L: float = Field(..., gt=0, description="uL,min [pu]")
    n_nom: float = Field(..., gt=0, description="Nominal speed [rpm]")
    pole_pairs: int = Field(..., gt=0)
    fL: float = Field(..., gt=0, description="Line frequency [Hz]")
    altitude_m: float | None = Field(None, ge=0, description="Site altitude [m]")

    sections: list[BusbarSectionIn] | None = Field(
        None, description="Defaults to the standard 8-section SR-module layout"
    )
    threshold: float = Field(1.0, gt=0, description="Minimum acceptable reserve [pu]")
    location: Location = "indoor"
    k1: float | None = None
    k2: float | None = None
    k5: float | None = None
    band_gap_rule: BandGapRule = "conservative"


class SectionResultOut(BaseModel):
    section: str
    section_en: str
    profile: str
    i_load_a: float
    f_hz: float
    band: str
    k1: float
    k2: float
    k3: float
    k4: float
    k5: float
    k_total: float
    i_base_a: float
    i_max_a: float
    reserve_pu: float
    ok: bool
    k3_source: str
    k3_rule: str
    k5_source: str
    k5_rule: str


class CurrentsOut(BaseModel):
    i_motor_a: float
    i_motor_formula: str
    i_line_a: float
    i_line_formula: str
    i_stack_a: float
    i_stack_formula: str
    f_motor_hz: float
    f_motor_formula: str
    f_line_hz: float
    f_line_formula: str


class BusbarCheckResponse(BaseModel):
    bare: list[SectionResultOut]
    painted: list[SectionResultOut]
    currents: CurrentsOut
    threshold: float
    altitude_m: float
    location: Location
    all_ok: bool
    paint_required: bool
    paint_required_note: str
    warnings: list[str]
