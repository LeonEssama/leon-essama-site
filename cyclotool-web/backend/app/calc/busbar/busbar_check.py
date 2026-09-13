"""Thermal ampacity check of the SR-module busbars.

Ported 1:1 from cyclotool/src/busbar/busbar_check.m -- see that file's
docstring for the full engineering note. Summary:

    Replaces Schienenueberpruefung.xlsx. Takes the cycloconverter
    dimensioning inputs, derives the load current and frequency of every
    busbar section, applies the k1..k5 derating factors, and reports the
    reserve of each section for both surface finishes.

LOAD CURRENT DEFINITIONS
    Motor sections   I = IM/u_L                 [A]
    Line sections    I = IM/u_L * sqrt(2/3)     [A]
    Stack sections   I = IM/u_L / sqrt(3)       [A]

    IM/u_L (u_L = uL,min) is the same undervoltage current-scaling
    already established elsewhere in the tool: at reduced line voltage
    the motor current rises by 1/u_L to hold shaft power roughly
    constant, so every busbar section sees its worst case at uL,min, not
    at rated line voltage.

    The line-side factor sqrt(2/3) = 0.8165 is the converter valve-side
    RMS current of a 6-pulse bridge. The stack factor 1/sqrt(3) = 0.5774
    is the per-branch RMS current of a bridge arm conducting 120
    electrical degrees -- an INTERPRETATION of the source workbook,
    which documents no derivation. Confirm before issuing a design.

FREQUENCY BAND
    The base table has data for f < 16 Hz and f > 20 Hz only. A
    frequency in the undefined 16..20 Hz gap is resolved per
    band_gap_rule: 'conservative' selects the lower (>20 Hz) rating and
    warns; 'error' refuses to compute.

STANDARDS
    No IEC/IEEE requirement found for this item. Base ratings and k
    factors are BBC/ABB Schaltanlagen-Handbuch ch. 13; see
    ampacity_table.py and k_factors.py for the full note.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Literal

from .altitude_factor import Location, busbar_altitude_factor
from .ampacity_table import BUSBAR_AMPACITY_TABLE, get_profile
from .k_factors import busbar_k_factors
from .section_defaults import BusbarSection, busbar_section_defaults

BandGapRule = Literal["conservative", "error"]

_F_LOW_MAX = 16.0  # [Hz]
_F_HIGH_MIN = 20.0  # [Hz]


class BusbarCheckError(ValueError):
    """Raised for invalid input or an unresolvable frequency-band gap."""


@dataclass
class BusbarInput:
    """Required Input fields, matching busbar_check.m's REQUIRED FIELDS."""

    IM: float  # [A] nominal machine current
    u_L: float  # [pu] uL,min -- minimum line voltage, undervoltage case
    n_nom: float  # [rpm] nominal speed
    pole_pairs: int  # [-]
    fL: float  # [Hz] line frequency
    altitude_m: float | None = None  # [m], default 0 with a warning

    def __post_init__(self) -> None:
        if self.IM <= 0 or not math.isfinite(self.IM):
            raise BusbarCheckError("IM must be a positive, finite number.")
        if self.u_L <= 0 or not math.isfinite(self.u_L):
            raise BusbarCheckError("u_L must be a positive, finite number.")
        if self.n_nom <= 0 or not math.isfinite(self.n_nom):
            raise BusbarCheckError("n_nom must be a positive, finite number.")
        if self.pole_pairs <= 0:
            raise BusbarCheckError("pole_pairs must be a positive integer.")
        if self.fL <= 0 or not math.isfinite(self.fL):
            raise BusbarCheckError("fL must be a positive, finite number.")


@dataclass
class SectionResult:
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
    warnings: list[str] = field(default_factory=list)


@dataclass
class CurrentsResult:
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


@dataclass
class BusbarCheckResult:
    bare: list[SectionResult]
    painted: list[SectionResult]
    currents: CurrentsResult
    threshold: float
    altitude_m: float
    location: Location
    all_ok: bool
    paint_required: bool
    paint_required_note: str
    warnings: list[str] = field(default_factory=list)


def _select_band(
    f_hz: float, section_name: str, rule: BandGapRule, warnings: list[str]
) -> tuple[bool, str]:
    if f_hz < _F_LOW_MAX:
        return True, "< 16 Hz"
    if f_hz > _F_HIGH_MIN:
        return False, "> 20 Hz"

    if rule == "error":
        raise BusbarCheckError(
            f'Section "{section_name}" runs at {f_hz:.2f} Hz, inside the '
            f"undefined {_F_LOW_MAX:g}..{_F_HIGH_MIN:g} Hz gap of the base "
            "table. Supply a rating for this band or set band_gap_rule to "
            "'conservative'."
        )
    warnings.append(
        f'Section "{section_name}" runs at {f_hz:.2f} Hz, inside the '
        f"undefined {_F_LOW_MAX:g}..{_F_HIGH_MIN:g} Hz gap of the base "
        "table. The lower (> 20 Hz) rating has been used. This is an "
        "engineering estimate, not tabulated data."
    )
    return False, "> 20 Hz (gap)"


def _evaluate_finish(
    sections: list[BusbarSection],
    painted: bool,
    i_motor: float,
    i_line: float,
    i_stack: float,
    f_motor: float,
    f_line: float,
    altitude_m: float,
    location: Location,
    threshold: float,
    band_gap_rule: BandGapRule,
    k1_override: float | None,
    k2_override: float | None,
    k5_resolved: float,
    k5_source: str,
    k5_rule: str,
    warnings: list[str],
) -> list[SectionResult]:
    results: list[SectionResult] = []

    for s in sections:
        profile = get_profile(s.profile)

        if s.current_basis == "Motor":
            i_load = i_motor
        elif s.current_basis == "Line":
            i_load = i_line
        elif s.current_basis == "Stack":
            i_load = i_stack
        else:
            raise BusbarCheckError(
                f'Section "{s.name}": CurrentBasis "{s.current_basis}" is '
                "not recognised."
            )

        if s.freq_basis == "Motor":
            f_hz = f_motor
        elif s.freq_basis == "Line":
            f_hz = f_line
        else:
            raise BusbarCheckError(
                f'Section "{s.name}": FreqBasis "{s.freq_basis}" is not '
                "recognised."
            )

        is_low_band, band = _select_band(f_hz, s.name, band_gap_rule, warnings)

        if painted:
            i_base = profile.i_painted_lt16 if is_low_band else profile.i_painted_gt20
        else:
            i_base = profile.i_bare_lt16 if is_low_band else profile.i_bare_gt20

        # k3 override sentinel: -1 means "the workbook's linked 2-bar
        # horizontal value" (see section_defaults.py's Stapelverschienung note)
        k3_override = s.k3_override
        if k3_override == -1:
            k3_override = 0.85 if painted else 0.80

        k = busbar_k_factors(
            painted=painted,
            n_bars=profile.n_bars,
            width_mm=profile.width_mm,
            thickness_mm=profile.thickness_mm,
            orientation=s.orientation,
            run_length_m=s.run_length_m,
            altitude_m=altitude_m,
            location=location,
            k1=k1_override,
            k2=k2_override,
            k3=k3_override,
            k5=k5_resolved,
        )
        warnings.extend(k.warnings)

        # k5 was resolved once for the whole run (see busbar_check()), so
        # busbar_k_factors saw it as a plain override and would otherwise
        # mislabel every row's provenance as 'override'. Restore the
        # provenance it actually came from -- mirrors busbar_check.m's
        # own k5info restoration step.
        k.k5_source = k5_source
        k.k5_rule = k5_rule

        i_max = i_base * k.k_total
        reserve = i_max / i_load
        ok = reserve >= threshold

        results.append(
            SectionResult(
                section=s.name,
                section_en=s.name_en,
                profile=s.profile,
                i_load_a=i_load,
                f_hz=f_hz,
                band=band,
                k1=k.k1,
                k2=k.k2,
                k3=k.k3,
                k4=k.k4,
                k5=k.k5,
                k_total=k.k_total,
                i_base_a=i_base,
                i_max_a=i_max,
                reserve_pu=reserve,
                ok=ok,
                k3_source=k.k3_source,
                k3_rule=k.k3_rule,
                k5_source=k.k5_source,
                k5_rule=k.k5_rule,
            )
        )

    return results


def busbar_check(
    input_: BusbarInput,
    *,
    sections: list[BusbarSection] | None = None,
    threshold: float = 1.0,
    location: Location = "indoor",
    k1: float | None = None,
    k2: float | None = None,
    k5: float | None = None,
    band_gap_rule: BandGapRule = "conservative",
) -> BusbarCheckResult:
    if threshold <= 0:
        raise BusbarCheckError("threshold must be positive.")

    warnings: list[str] = []

    altitude_m = input_.altitude_m
    if altitude_m is None:
        altitude_m = 0.0
        warnings.append("Altitude not supplied; assuming sea level (k5 = 1).")

    f_motor = input_.pole_pairs * input_.n_nom / 60.0
    f_line = input_.fL

    # Worst-case (uL,min undervoltage) machine current: same 1/u_L
    # scaling used for IM_op in the operating-point sweep.
    im_used = input_.IM / input_.u_L
    i_motor = im_used
    i_line = im_used * math.sqrt(2 / 3)
    i_stack = im_used / math.sqrt(3)

    currents = CurrentsResult(
        i_motor_a=i_motor,
        i_motor_formula="IM / u_L",
        i_line_a=i_line,
        i_line_formula="IM / u_L * sqrt(2/3)",
        i_stack_a=i_stack,
        i_stack_formula="IM / u_L / sqrt(3)",
        f_motor_hz=f_motor,
        f_motor_formula="pole_pairs * n_nom / 60",
        f_line_hz=f_line,
        f_line_formula="fL",
    )

    if sections is None:
        sections = busbar_section_defaults()

    # k5 is resolved once for the whole run so the altitude-extrapolation
    # warning appears once, not once per section per finish.
    if k5 is not None:
        k5_resolved = k5
        k5_source = f"user override at {altitude_m:g} m"
        k5_rule = "override"
    else:
        alt_result = busbar_altitude_factor(altitude_m, location)
        k5_resolved = alt_result.k5
        k5_source = alt_result.source
        k5_rule = alt_result.rule
        if alt_result.warning:
            warnings.append(alt_result.warning)

    bare = _evaluate_finish(
        sections,
        False,
        i_motor,
        i_line,
        i_stack,
        f_motor,
        f_line,
        altitude_m,
        location,
        threshold,
        band_gap_rule,
        k1,
        k2,
        k5_resolved,
        k5_source,
        k5_rule,
        warnings,
    )
    painted = _evaluate_finish(
        sections,
        True,
        i_motor,
        i_line,
        i_stack,
        f_motor,
        f_line,
        altitude_m,
        location,
        threshold,
        band_gap_rule,
        k1,
        k2,
        k5_resolved,
        k5_source,
        k5_rule,
        warnings,
    )

    all_ok = all(r.ok for r in bare) and all(r.ok for r in painted)
    paint_required = (not all(r.ok for r in bare)) and all(r.ok for r in painted)
    paint_required_note = ""
    if paint_required:
        n_fail_bare = sum(1 for r in bare if not r.ok)
        paint_required_note = (
            f"{n_fail_bare} section(s) fail bare but pass painted. Painting "
            "the bars is then a design requirement, not an option."
        )

    return BusbarCheckResult(
        bare=bare,
        painted=painted,
        currents=currents,
        threshold=threshold,
        altitude_m=altitude_m,
        location=location,
        all_ok=all_ok,
        paint_required=paint_required,
        paint_required_note=paint_required_note,
        warnings=warnings,
    )
