"""Regression test for the one real calculation in the Engineering Data
domain: the working-voltage formula shown in the reference Engineering
Data report (3BHS857641, page 5):

    Uwork = 2 x 1.71 kVrms x 1.1 x 1.3 x sqrt(2) = 6.92 kVpeak
"""

from __future__ import annotations

import math

from app.calc.engineering_data.engineering_data import (
    VoltageDutyInput,
    calculate_voltage_duty,
)


def test_uwork_matches_reference_report():
    result = calculate_voltage_duty(VoltageDutyInput())
    assert math.isclose(result.uwork_kv_peak, 6.92, rel_tol=0, abs_tol=0.01)
