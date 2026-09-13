"""Engineering Data API: defaults, live test-voltage calc, and the docx report.

All BOM content (quantity/description/part_number/note) is user-editable
data passed straight through from the request to the report -- there is
no catalog lookup or validation, by design.
"""

from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import Response

from app.calc.engineering_data.engineering_data import (
    BomItem,
    BomSection,
    NameplateRatings,
    VoltageDutyInput,
    calculate_voltage_duty,
    default_bom_sections,
)
from app.models.engineering_data import (
    BomItemIn,
    BomSectionIn,
    EngineeringDataRequest,
    EngineeringDataResponse,
    NameplateRatingsIn,
    ProjectMetaIn,
    VoltageDutyInputIn,
    VoltageDutyResultOut,
)
from app.reports.docx_utils import ProjectMeta
from app.reports.engineering_data_report import render_engineering_data_report_docx

router = APIRouter(prefix="/api/engineering-data", tags=["engineering-data"])


def _default_project() -> ProjectMetaIn:
    return ProjectMetaIn(
        name="Proyecto Riotinto",
        equipment="Gearless Mill Drive SAG Mill",
        client="Atalaya Mining",
        contractor="Minnovo Pty Ltd.",
        project_no="20726 / 11109389",
        customer_po="PC011693-2",
        prepared_by="",
        date="",
    )


@router.get("/defaults", response_model=EngineeringDataRequest)
def defaults() -> EngineeringDataRequest:
    """The Atalaya SAG Mill project's own values, as a worked EXAMPLE --
    every field is meant to be edited for a new project, none of it is
    computed."""
    sections = default_bom_sections()
    return EngineeringDataRequest(
        project=_default_project(),
        nameplate=NameplateRatingsIn(),
        test_voltage=VoltageDutyInputIn(),
        bom_sections=[
            BomSectionIn(
                title=s.title,
                items=[
                    BomItemIn(
                        quantity=i.quantity,
                        description=i.description,
                        part_number=i.part_number,
                        note=i.note,
                    )
                    for i in s.items
                ],
            )
            for s in sections
        ],
    )


@router.post("/test-voltage", response_model=VoltageDutyResultOut)
def test_voltage(req: VoltageDutyInputIn) -> VoltageDutyResultOut:
    result = calculate_voltage_duty(
        VoltageDutyInput(
            uv0_kv=req.uv0_kv,
            series_count=req.series_count,
            line_overvoltage_factor=req.line_overvoltage_factor,
            firing_peak_factor=req.firing_peak_factor,
            utest_kv_rms=req.utest_kv_rms,
            utest_duration_s=req.utest_duration_s,
            utest_frequency_hz=req.utest_frequency_hz,
        )
    )
    return VoltageDutyResultOut(uwork_kv_peak=result.uwork_kv_peak, formula=result.formula)


@router.post("/report.docx")
def report_docx(req: EngineeringDataRequest) -> Response:
    nameplate = NameplateRatings(**req.nameplate.model_dump())
    tv_input = VoltageDutyInput(**req.test_voltage.model_dump())
    sections = [
        BomSection(
            title=s.title,
            items=[
                BomItem(
                    quantity=i.quantity,
                    description=i.description,
                    part_number=i.part_number,
                    note=i.note,
                )
                for i in s.items
            ],
        )
        for s in req.bom_sections
    ]
    project = ProjectMeta(**req.project.model_dump())

    docx_bytes = render_engineering_data_report_docx(nameplate, tv_input, sections, project)
    return Response(
        content=docx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={
            "Content-Disposition": 'attachment; filename="engineering_data.docx"'
        },
    )
