"""Pydantic I/O models for the Engineering Data report.

Every BOM field (quantity, description, part_number, note) is a plain
editable string -- there is no catalog validation, by design (see
app/calc/engineering_data/engineering_data.py's module docstring for why).
"""

from __future__ import annotations

from pydantic import BaseModel


class BomItemIn(BaseModel):
    quantity: str = ""
    description: str = ""
    part_number: str = ""
    note: str = ""


class BomSectionIn(BaseModel):
    title: str
    items: list[BomItemIn] = []


class NameplateRatingsIn(BaseModel):
    input_phases: str = "6 x 3-phase"
    input_voltage_v: float = 1710
    input_voltage_count: int = 6
    input_current_a: float = 2314
    input_frequency_hz: float = 50
    input_apparent_power_kva: float = 6854
    input_apparent_power_count: int = 6
    output_voltage_min_v: float = 0
    output_voltage_base_v: float = 5200
    output_voltage_max_v: float = 5200
    output_current_a: float = 2692
    output_frequency_min_hz: float = 0
    output_frequency_base_hz: float = 5.89
    output_frequency_max_hz: float = 6.19
    output_apparent_power_kva: float = 24246
    overload_cycles: str = "5 x 30 s/h"
    overload_pu: float = 1.50
    excitation_input_voltage_v: float = 690
    excitation_input_frequency_hz: float = 50
    excitation_input_apparent_power_kva: float = 610
    excitation_output_voltage_v: float = 592
    excitation_output_current_a: float = 546
    excitation_output_overload_current_a: float = 635


class VoltageDutyInputIn(BaseModel):
    uv0_kv: float = 1.71
    series_count: int = 2
    line_overvoltage_factor: float = 1.1
    firing_peak_factor: float = 1.3
    utest_kv_rms: float = 7.8
    utest_duration_s: float = 60
    utest_frequency_hz: float = 50


class ProjectMetaIn(BaseModel):
    name: str = "Untitled Project"
    equipment: str = ""
    client: str = ""
    contractor: str = ""
    project_no: str = ""
    customer_po: str = ""
    prepared_by: str = ""
    date: str = ""


class EngineeringDataRequest(BaseModel):
    project: ProjectMetaIn = ProjectMetaIn()
    nameplate: NameplateRatingsIn = NameplateRatingsIn()
    test_voltage: VoltageDutyInputIn = VoltageDutyInputIn()
    bom_sections: list[BomSectionIn] = []


class VoltageDutyResultOut(BaseModel):
    uwork_kv_peak: float
    formula: str


class EngineeringDataResponse(BaseModel):
    test_voltage: VoltageDutyResultOut
