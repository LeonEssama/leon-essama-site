"""Correction factors k1..k5 for busbar thermal ratings.

Ported 1:1 from cyclotool/src/busbar/busbar_k_factors.m -- see that file
for the full provenance note. Summary:

    I_max = I_base * k1 * k2 * k3 * k4 * k5      [A]

Every factor carries two companions: `<k>_source` (human-readable
provenance) and `<k>_rule` (machine-readable: 'override' | 'default' |
'fixed' | 'table' | 'interpolated' | 'extrapolated' | 'below_table' |
'single_bar' | 'vertical_exempt'). Assert on `_rule` in tests; `_source`
is for humans and its wording may change.

STANDARDS: No IEC/IEEE requirement found for this item. IEC 61439-1
requires temperature-rise verification of assemblies but publishes no
busbar ampacity or altitude-derating tables; above 2000 m it makes the
conditions subject to agreement between manufacturer and user.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

from .altitude_factor import Location, busbar_altitude_factor

Orientation = Literal["horizontal", "vertical"]

# Tabelle 13-13 (BBC/ABB Schaltanlagen-Handbuch): nBars, Wmin, Wmax,
# k3_painted, k3_bare. The closed-tube row (0.95/0.90) is not
# implemented -- this tool has no tube profiles.
_TAB_13_13 = [
    (2, 50, 200, 0.85, 0.80),
    (3, 50, 80, 0.85, 0.80),
    (3, 100, 120, 0.80, 0.75),
    (4, 160, 160, 0.75, 0.70),
    (4, 200, 200, 0.70, 0.65),
]
_VERTICAL_EXEMPT_LENGTH_M = 2.0
_T_MIN, _T_MAX = 5.0, 10.0  # [mm], Tab. 13-13 validity range


@dataclass
class KFactors:
    k1: float
    k1_source: str
    k1_rule: str
    k2: float
    k2_source: str
    k2_rule: str
    k3: float
    k3_source: str
    k3_rule: str
    k4: float
    k4_source: str
    k4_rule: str
    k5: float
    k5_source: str
    k5_rule: str
    warnings: list[str] = field(default_factory=list)

    @property
    def k_total(self) -> float:
        return self.k1 * self.k2 * self.k3 * self.k4 * self.k5


def _k3_from_table_13_13(
    n_bars: int,
    width_mm: float,
    thickness_mm: float,
    painted: bool,
    orientation: Orientation,
    run_length_m: float | None,
    warnings: list[str],
) -> tuple[float, str, str]:
    if orientation == "vertical" and run_length_m is None:
        warnings.append(
            "A vertical section has no run length. Tab. 13-13 exempts "
            f"vertical runs of {_VERTICAL_EXEMPT_LENGTH_M:g} m or less, "
            "so the derating is applied conservatively. Enter the run "
            "length to remove this assumption."
        )
    if (
        orientation == "vertical"
        and run_length_m is not None
        and run_length_m <= _VERTICAL_EXEMPT_LENGTH_M
    ):
        return (
            1.0,
            (
                f"Tab. 13-13 not applicable: vertical run of "
                f"{run_length_m:.2f} m (<= {_VERTICAL_EXEMPT_LENGTH_M:g} m)"
            ),
            "vertical_exempt",
        )

    if n_bars == 1:
        return (1.0, "Tab. 13-13 has no single-bar entry; not derated", "single_bar")

    if thickness_mm < _T_MIN or thickness_mm > _T_MAX:
        warnings.append(
            f"Bar thickness {thickness_mm:g} mm is outside the Tab. "
            f"13-13 validity range {_T_MIN:g}..{_T_MAX:g} mm. k3 is "
            "applied anyway; verify against the source table."
        )

    row = next(
        (r for r in _TAB_13_13 if r[0] == n_bars and r[1] <= width_mm <= r[2]),
        None,
    )
    if row is None:
        raise ValueError(
            f"No Tabelle 13-13 entry for {n_bars} bars of width "
            f"{width_mm:g} mm. Supply k3 explicitly, or correct the profile."
        )

    _, w_min, w_max, k3_painted, k3_bare = row
    k3 = k3_painted if painted else k3_bare
    finish = "painted" if painted else "bare"
    return (
        k3,
        f"Tab. 13-13: {n_bars} bars, W = {w_min:g}..{w_max:g} mm, {finish}",
        "table",
    )


def busbar_k_factors(
    *,
    painted: bool,
    n_bars: int,
    width_mm: float,
    thickness_mm: float,
    orientation: Orientation = "horizontal",
    run_length_m: float | None = None,
    altitude_m: float = 0.0,
    location: Location = "indoor",
    k1: float | None = None,
    k2: float | None = None,
    k3: float | None = None,
    k4: float | None = None,
    k5: float | None = None,
) -> KFactors:
    warnings: list[str] = []

    if k1 is not None:
        k1_val, k1_source, k1_rule = k1, "user override", "override"
    else:
        k1_val, k1_source, k1_rule = (
            1.0,
            "default 1 (no conductivity data supplied)",
            "default",
        )

    if k2 is not None:
        k2_val, k2_source, k2_rule = k2, "user override (read from Bild 13-4)", "override"
    else:
        k2_val, k2_source, k2_rule = (
            1.0,
            (
                "default 1 (reference 35/65 degC; Bild 13-4 not digitised - "
                "supply k2 explicitly if temperatures differ)"
            ),
            "default",
        )

    if k3 is not None:
        k3_val, k3_source, k3_rule = k3, "user override", "override"
    else:
        k3_val, k3_source, k3_rule = _k3_from_table_13_13(
            n_bars, width_mm, thickness_mm, painted, orientation, run_length_m, warnings
        )

    if k4 is not None:
        k4_val, k4_source, k4_rule = k4, "user override", "override"
    else:
        k4_val, k4_source, k4_rule = (
            1.0,
            "fixed 1 (frequency carried by the base-table band)",
            "fixed",
        )

    if k5 is not None:
        k5_val, k5_source, k5_rule = (
            k5,
            f"user override at {altitude_m:g} m",
            "override",
        )
    else:
        alt_result = busbar_altitude_factor(altitude_m, location)
        k5_val, k5_source, k5_rule = alt_result.k5, alt_result.source, alt_result.rule
        if alt_result.warning:
            warnings.append(alt_result.warning)

    return KFactors(
        k1=k1_val,
        k1_source=k1_source,
        k1_rule=k1_rule,
        k2=k2_val,
        k2_source=k2_source,
        k2_rule=k2_rule,
        k3=k3_val,
        k3_source=k3_source,
        k3_rule=k3_rule,
        k4=k4_val,
        k4_source=k4_source,
        k4_rule=k4_rule,
        k5=k5_val,
        k5_source=k5_source,
        k5_rule=k5_rule,
        warnings=warnings,
    )
