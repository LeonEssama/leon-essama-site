"""Altitude derating k5, BBC Schaltanlagen-Handbuch Tab. 13-14.

Ported 1:1 from cyclotool/src/busbar/busbar_altitude_factor.m.

Tabelle 13-14 ('Belastungsminderung in Hoehen ab 1000 m'):
    1000 m -> 1.00 indoor / 0.98 outdoor
    2000 m -> 0.99        / 0.94
    3000 m -> 0.96        / 0.89
    4000 m -> 0.90        / 0.83
Below 1000 m there is no reduction. Linear interpolation is used between
tabulated altitudes.

ABOVE 4000 m the table ends. No IEC/IEEE requirement found for this item:
IEC 61439-1 makes conditions above 2000 m subject to agreement between
manufacturer and user rather than publishing a curve. This function
LINEARLY EXTRAPOLATES from the last two rows and warns via the returned
`warning` field. That is an ENGINEERING ESTIMATE. Supply an agreed k5
explicitly instead (see k_factors.py's k5 override).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Location = Literal["indoor", "outdoor"]
K5Rule = Literal["below_table", "table", "interpolated", "extrapolated"]

_ALT_KM = [1.0, 2.0, 3.0, 4.0]
_K_IN = [1.00, 0.99, 0.96, 0.90]
_K_OUT = [0.98, 0.94, 0.89, 0.83]


@dataclass(frozen=True)
class AltitudeFactorResult:
    k5: float
    source: str
    rule: K5Rule
    warning: str | None = None


def _interp1(x: list[float], y: list[float], xi: float) -> float:
    for i in range(len(x) - 1):
        if x[i] <= xi <= x[i + 1]:
            t = (xi - x[i]) / (x[i + 1] - x[i])
            return y[i] + t * (y[i + 1] - y[i])
    raise ValueError("xi out of interpolation range")


def busbar_altitude_factor(
    altitude_m: float, location: Location = "indoor"
) -> AltitudeFactorResult:
    if altitude_m < 0 or not (altitude_m == altitude_m):  # NaN check
        raise ValueError("altitude_m must be non-negative and finite.")

    k_tab = _K_IN if location == "indoor" else _K_OUT
    a = altitude_m / 1000.0

    if a < _ALT_KM[0]:
        return AltitudeFactorResult(
            k5=1.0,
            source=f"Tab. 13-14: {altitude_m:g} m is below 1000 m, no reduction",
            rule="below_table",
        )

    if a <= _ALT_KM[-1]:
        k5 = _interp1(_ALT_KM, k_tab, a)
        if any(abs(a - km) < 1e-9 for km in _ALT_KM):
            return AltitudeFactorResult(
                k5=k5,
                source=f"Tab. 13-14 ({location}), tabulated row at {altitude_m:g} m",
                rule="table",
            )
        return AltitudeFactorResult(
            k5=k5,
            source=(
                f"Tab. 13-14 ({location}), linear interpolation at "
                f"{altitude_m:g} m"
            ),
            rule="interpolated",
        )

    slope = (k_tab[-1] - k_tab[-2]) / (_ALT_KM[-1] - _ALT_KM[-2])
    k5 = max(k_tab[-1] + slope * (a - _ALT_KM[-1]), 0.0)
    warning = (
        f"Altitude {altitude_m:g} m exceeds the last row of Tab. 13-14 "
        f"(4000 m). k5 = {k5:.4f} is a linear extrapolation, not a "
        "tabulated or standardised value. Agree a figure with the "
        "manufacturer per IEC 61439-1 and enter it as an explicit k5."
    )
    return AltitudeFactorResult(
        k5=k5,
        source=(
            f"ENGINEERING ESTIMATE: linear extrapolation of Tab. 13-14 "
            f"({location}) beyond 4000 m to {altitude_m:g} m"
        ),
        rule="extrapolated",
        warning=warning,
    )
