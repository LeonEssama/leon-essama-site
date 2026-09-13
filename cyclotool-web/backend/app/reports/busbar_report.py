"""Render a BusbarCheckResult as a PDF, laid out like the reference
'Thermal Busbar Design' report (see the project README for the mapping
from that report's tables to this tool's fields).

Deliberately shows BOTH the Bare and Painted tables rather than picking
one finish per section: the reference report appears to show a single
table whose finish-selection convention (which section is bare vs.
painted in the as-built design) is not recoverable from the PDF alone.
Showing both, plus the AllOK/PaintRequired verdict, is a strict superset
of that information and does not require guessing which finish was
actually installed on a given section.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape
from weasyprint import HTML

from app.calc.busbar.busbar_check import BusbarCheckResult

_TEMPLATE_DIR = Path(__file__).parent / "templates"

_env = Environment(
    loader=FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=select_autoescape(["html"]),
)


@dataclass
class ProjectMeta:
    name: str = "Untitled Project"
    equipment: str = ""
    client: str = ""
    prepared_by: str = ""
    date: str = ""


def render_busbar_report_pdf(
    result: BusbarCheckResult, project: ProjectMeta | None = None
) -> bytes:
    project = project or ProjectMeta()
    template = _env.get_template("busbar_report.html")
    html_str = template.render(
        result=result,
        project=project,
        generated_at=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    )
    return HTML(string=html_str, base_url=str(_TEMPLATE_DIR)).write_pdf()
