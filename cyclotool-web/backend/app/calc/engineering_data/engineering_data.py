"""Engineering Data: nameplate + bill-of-materials for one project.

Unlike every other domain in this tool, this one has NO physics engine
behind most of its content: the reference report (3BHS857641) is mostly
a parts list (thyristor unit, overvoltage protection, crowbar, excitation
rectifier) whose part numbers, quantities and descriptions come from a
manufacturer's component catalog that does not exist anywhere in this
tool (MATLAB or here) -- only electrical RATINGS are modelled elsewhere.

Per user direction: part numbers are EDITABLE FIELDS, not looked up from
a catalog. The defaults below are the Atalaya SAG Mill project's own
values (read from the supplied reference PDF) purely as a worked
EXAMPLE/STARTING POINT for a new project -- they are not derived or
computed, and must be reviewed/replaced for any other project.

The one piece of real engineering calculation this domain contains is
the test-voltage formula (test_voltage_calc), which the reference report
itself shows as a formula, not a table lookup.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field


@dataclass
class BomItem:
    """One bill-of-materials line. part_number is always user-editable --
    this tool has no parts catalog to validate it against."""

    quantity: str  # kept as text: the reference report uses forms like
    #                "3 x 1 St." or "72 St." that don't reduce to one number
    description: str
    part_number: str
    note: str = ""


@dataclass
class BomSection:
    title: str
    items: list[BomItem] = field(default_factory=list)


@dataclass
class NameplateRatings:
    # Input (converter transformer secondary / thyristor bridge side)
    input_phases: str = "6 x 3-phase"
    input_voltage_v: float = 1710
    input_voltage_count: int = 6
    input_current_a: float = 2314
    input_frequency_hz: float = 50
    input_apparent_power_kva: float = 6854
    input_apparent_power_count: int = 6
    # Output (motor side)
    output_voltage_min_v: float = 0
    output_voltage_base_v: float = 5200
    output_voltage_max_v: float = 5200
    output_current_a: float = 2692
    output_frequency_min_hz: float = 0
    output_frequency_base_hz: float = 5.89
    output_frequency_max_hz: float = 6.19
    output_apparent_power_kva: float = 24246
    # Overload
    overload_cycles: str = "5 x 30 s/h"
    overload_pu: float = 1.50
    # Excitation
    excitation_input_voltage_v: float = 690
    excitation_input_frequency_hz: float = 50
    excitation_input_apparent_power_kva: float = 610
    excitation_output_voltage_v: float = 592
    excitation_output_current_a: float = 546
    excitation_output_overload_current_a: float = 635


@dataclass
class VoltageDutyInput:
    """Inputs to the working/test-voltage formula the reference report
    shows on its 'Kurzschliesser, Wandler, Pruefspannung' page:

        Uwork = n * Uv0 * k_line_overvoltage * k_firing_peak * sqrt(2)
        (n = 2 for a stacked/series arrangement, 1 otherwise)

    IEC 61800-5-1 Table 23 (a.c./d.c. test voltage for circuits not
    connected directly to the mains) then maps Uwork to a standardised
    Utest. That table is NOT digitised here (no IEC/IEEE requirement
    tracked for this item beyond citing the standard); Utest is an
    editable field defaulting to the reference project's own value.
    """

    uv0_kv: float = 1.71
    series_count: int = 2
    line_overvoltage_factor: float = 1.1  # "Netzueberspannung"
    firing_peak_factor: float = 1.3  # "Spannungsspitzen im 90-Grad-Betrieb"
    utest_kv_rms: float = 7.8  # editable; IEC 61800-5-1 Table 23 not digitised
    utest_duration_s: float = 60
    utest_frequency_hz: float = 50


@dataclass
class VoltageDutyResult:
    uwork_kv_peak: float
    formula: str


def calculate_voltage_duty(inp: VoltageDutyInput) -> VoltageDutyResult:
    uwork = (
        inp.series_count
        * inp.uv0_kv
        * inp.line_overvoltage_factor
        * inp.firing_peak_factor
        * math.sqrt(2)
    )
    formula = (
        f"Uwork = {inp.series_count} x {inp.uv0_kv:g} kVrms x "
        f"{inp.line_overvoltage_factor:g} x {inp.firing_peak_factor:g} x "
        f"sqrt(2) = {uwork:.2f} kVpeak"
    )
    return VoltageDutyResult(uwork_kv_peak=uwork, formula=formula)


def default_bom_sections() -> list[BomSection]:
    """The Atalaya SAG Mill project's own BOM, as a worked example --
    every field here is editable in the UI; nothing is computed."""

    return [
        BomSection(
            "Kurzschliesser, Wandler (Short-circuiter, transducers)",
            [
                BomItem("1 x 1 St.", "Star-point fuse assembly, complete", "3BHB007431R0001"),
                BomItem(
                    "1 x 2 St.",
                    "Earth-fault relay adapter AGH675S-7, up to 7200 V",
                    "3BHB030045R0001",
                ),
                BomItem(
                    "3 x 1 St.",
                    "Fuse 6000 V, 32 A, with optical indicator and microswitch",
                    "HIES417848P0001",
                    "Manufacturer: Bussmann",
                ),
                BomItem(
                    "3 x 1 St.",
                    "LEM current transducer HAZ 10000-SBI",
                    "3BHB047487R0001",
                ),
                BomItem(
                    "3 x 1 St.",
                    "DC-rail current sensor, type LF NCS165T-7075",
                    "3BHB024831R0003",
                    "Manufacturer: ABB Entrelec",
                ),
                BomItem(
                    "3 x 4 St.",
                    "Current transformer ASS 12-101, 3600 A / 1 A, 2 VA, cl. 1, 50/60 Hz",
                    "HUAD300880P0005",
                ),
            ],
        ),
        BomSection(
            "Thyristor unit (per DB branch: 2 antiparallel thyristors + RC snubber)",
            [
                BomItem("72 St.", "Thyristor, ns = 1 (6500 V, 100 mm silicon)", "3BHB017655R0001"),
                BomItem("36 St.", "Capacitor 1.5 uF +/-10%, 4200 Veff", "3BHB002001R0002", "Manufacturer: Siemens"),
                BomItem("36 St.", "Resistor 34 Ohm, water-cooled, 2.3 l/min", "HIES308461R0004"),
                BomItem("72 St.", "MV-GDR (without BOD), type XV C517 AE30", "3BHB004744R0030"),
                BomItem("6 St.", "LIN GF D563 A102, ns = 4", "3BHE046836R0102"),
            ],
        ),
        BomSection(
            "Overvoltage protection (x6 assemblies)",
            [
                BomItem("3 St.", "Surge arrester POLIM-C 2.0", "3BHB012158R2000"),
                BomItem(
                    "3 St.",
                    "Fuse 2000 V / 50 A, type 1BKN/125, incl. fuse switch",
                    "HEIS413526P0001",
                    "Manufacturer: Bussmann",
                ),
            ],
        ),
        BomSection(
            "Crowbar / motor overvoltage protection (x6)",
            [
                BomItem(
                    "2 St.",
                    "Complete crowbar, 2x antiparallel thyristors 2\" / 3600 V, BOD V(BOD) = 2600 V",
                    "3BHB001605R1008 / HUEL412304P0001",
                ),
                BomItem("1 St.", "LEM current transducer LF 1005-S/SP16", "3BHB020938R0001"),
                BomItem(
                    "1 St.",
                    (
                        "Crowbar resistor unit: 2 parallel 1.6 Ohm resistors, "
                        "total 0.8 Ohm cold / 1.0 Ohm warm, air-cooled 1410 A / 0.5 s, "
                        "max. voltage peak 5300 V"
                    ),
                    "3BHB032648R0001",
                ),
            ],
        ),
        BomSection(
            "Excitation rectifier and crowbar",
            [
                BomItem("1 St.", "Rectifier, type DCS800-S01-0900-07", "3BHB030000R0907"),
                BomItem("1 St.", "Current transformer TGC3_800:1A, cl. 1", "3BHD003267R0006"),
                BomItem(
                    "1 St.",
                    "Complete crowbar with BOD 2000 V and crowbar firing card LT C773 A, 2x antiparallel thyristors",
                    "3BHB022490R2000 / HUEL412304P0001",
                ),
                BomItem(
                    "1 St.",
                    "Resistor RK, 252 A / 0.5 s / 4.6 Ohm cold, 5.8 Ohm warm, 2050 Vpeak at crowbar firing",
                    "3BHB032647R0001",
                ),
            ],
        ),
    ]
