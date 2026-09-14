"""Busbar Check API: /api/busbar/check and /api/busbar/check/report.docx."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.calc.busbar.busbar_check import BusbarCheckError, BusbarInput, busbar_check
from app.calc.busbar.section_defaults import BusbarSection
from app.models.busbar import (
    BusbarCheckRequest,
    BusbarCheckResponse,
    CurrentsOut,
    SectionResultOut,
)
from app.reports.busbar_report import render_busbar_report_docx

router = APIRouter(prefix="/api/busbar", tags=["busbar"])


def _to_calc_input(req: BusbarCheckRequest) -> BusbarInput:
    try:
        return BusbarInput(
            IM=req.IM,
            u_L=req.u_L,
            n_nom=req.n_nom,
            pole_pairs=req.pole_pairs,
            fL=req.fL,
            altitude_m=req.altitude_m,
        )
    except BusbarCheckError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


def _to_calc_sections(req: BusbarCheckRequest) -> list[BusbarSection] | None:
    if req.sections is None:
        return None
    return [
        BusbarSection(
            name=s.name,
            name_en=s.name_en,
            profile=s.profile,
            current_basis=s.current_basis,
            freq_basis=s.freq_basis,
            orientation=s.orientation,
            run_length_m=s.run_length_m,
            k3_override=s.k3_override,
        )
        for s in req.sections
    ]


def _run_check(req: BusbarCheckRequest):
    calc_input = _to_calc_input(req)
    sections = _to_calc_sections(req)
    try:
        return busbar_check(
            calc_input,
            sections=sections,
            threshold=req.threshold,
            location=req.location,
            k1=req.k1,
            k2=req.k2,
            k5=req.k5,
            band_gap_rule=req.band_gap_rule,
        )
    except BusbarCheckError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


def _to_response(result) -> BusbarCheckResponse:
    def row(r) -> SectionResultOut:
        return SectionResultOut(
            section=r.section,
            section_en=r.section_en,
            profile=r.profile,
            i_load_a=r.i_load_a,
            f_hz=r.f_hz,
            band=r.band,
            k1=r.k1,
            k2=r.k2,
            k3=r.k3,
            k4=r.k4,
            k5=r.k5,
            k_total=r.k_total,
            i_base_a=r.i_base_a,
            i_max_a=r.i_max_a,
            reserve_pu=r.reserve_pu,
            ok=r.ok,
            k3_source=r.k3_source,
            k3_rule=r.k3_rule,
            k5_source=r.k5_source,
            k5_rule=r.k5_rule,
        )

    return BusbarCheckResponse(
        bare=[row(r) for r in result.bare],
        painted=[row(r) for r in result.painted],
        currents=CurrentsOut(
            i_motor_a=result.currents.i_motor_a,
            i_motor_formula=result.currents.i_motor_formula,
            i_line_a=result.currents.i_line_a,
            i_line_formula=result.currents.i_line_formula,
            i_stack_a=result.currents.i_stack_a,
            i_stack_formula=result.currents.i_stack_formula,
            f_motor_hz=result.currents.f_motor_hz,
            f_motor_formula=result.currents.f_motor_formula,
            f_line_hz=result.currents.f_line_hz,
            f_line_formula=result.currents.f_line_formula,
        ),
        threshold=result.threshold,
        altitude_m=result.altitude_m,
        location=result.location,
        all_ok=result.all_ok,
        paint_required=result.paint_required,
        paint_required_note=result.paint_required_note,
        warnings=result.warnings,
    )


@router.post("/check", response_model=BusbarCheckResponse)
def check(req: BusbarCheckRequest) -> BusbarCheckResponse:
    return _to_response(_run_check(req))


@router.post("/check/report.docx")
def check_report_docx(req: BusbarCheckRequest) -> Response:
    result = _run_check(req)
    docx_bytes = render_busbar_report_docx(result)
    return Response(
        content=docx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={
            "Content-Disposition": 'attachment; filename="thermal_busbar_design.docx"'
        },
    )
