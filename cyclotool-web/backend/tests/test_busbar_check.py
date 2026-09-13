"""Regression test against Schienenueberpruefung.xlsx.

Ported from cyclotool/tests/test_busbar_check.m -- same reference
values, same two workbook sheets (different projects, hence the
differing machine current / frequency / altitude between cases 1 and 2).

Every case asserts on RETURNED VALUES, never on warning plumbing (a
lesson already learned once in the MATLAB test: see that file's own
TEST DESIGN NOTE).
"""

from __future__ import annotations

import math

import pytest

from app.calc.busbar.altitude_factor import busbar_altitude_factor
from app.calc.busbar.busbar_check import BusbarCheckError, BusbarInput, busbar_check
from app.calc.busbar.k_factors import busbar_k_factors

TOL = 1e-6


def _close(a: float, b: float, tol: float = TOL) -> bool:
    return math.isclose(a, b, rel_tol=0, abs_tol=tol)


def test_case1_bare_sheet_workbook_reproduction():
    # IM = 2720 A, f_motor = 7 Hz, altitude 930 m (below 1000 m -> k5 = 1)
    # u_L = 1 (no undervoltage scaling) so I_load_A = IM, reproducing the
    # workbook exactly.
    in1 = BusbarInput(IM=2720, u_L=1, n_nom=14, pole_pairs=30, fL=50, altitude_m=930)
    # f_motor = 30 * 14 / 60 = 7.00 Hz, matching workbook cell C14

    b1 = busbar_check(in1, location="indoor")

    expected_i_max = [3520, 3350, 3520, 2991.0714285714284, 2480, 2288, 1776, 2288]
    expected_reserve = [
        1.2941176470588236,
        1.2316176470588236,
        1.2941176470588236,
        1.3468012470988129,
        1.1166791474452724,
        1.030226568288219,
        1.130927292000855,
        1.4569603851902908,
    ]
    for row, exp_i, exp_r in zip(b1.bare, expected_i_max, expected_reserve):
        assert _close(row.i_max_a, exp_i, TOL * max(1, exp_i))
        assert _close(row.reserve_pu, exp_r, TOL)

    assert all(r.ok for r in b1.bare), "every bare section should pass at 930 m"
    assert not b1.paint_required and b1.paint_required_note == ""
    assert _close(b1.currents.f_motor_hz, 7.0)
    assert all(r.band in ("< 16 Hz", "> 20 Hz") for r in b1.bare)


def test_case2_painted_sheet_paint_required():
    # IM = 2555.5556 A, f_motor = 6 Hz, altitude 4400 m with the workbook's
    # k5 = 0.86 supplied as an explicit override (Tab. 13-14 stops at 4000 m).
    in2 = BusbarInput(
        IM=2555.5555555555557, u_L=1, n_nom=12, pole_pairs=30, fL=50, altitude_m=4400
    )
    # f_motor = 30 * 12 / 60 = 6.00 Hz, matching workbook cell C14

    b2 = busbar_check(in2, location="indoor", k5=0.86)

    assert b2.paint_required, "PaintRequired should be true (bare fails, painted passes)"
    assert b2.paint_required_note != ""

    expected_i_max = [
        3698.86,
        3510.8542510121456,
        3698.86,
        3128.4990347490343,
        2451,
        2397.68,
        1973.7,
        2397.68,
    ]
    expected_reserve = [
        1.4473799999999999,
        1.3738125330047526,
        1.4473799999999999,
        1.4993268839852918,
        1.1746368312185667,
        1.1490833282236363,
        1.337692961308184,
        1.6250492270706827,
    ]
    for row, exp_i, exp_r in zip(b2.painted, expected_i_max, expected_reserve):
        assert _close(row.i_max_a, exp_i, TOL * max(1, exp_i))
        assert _close(row.reserve_pu, exp_r, TOL)
    assert all(r.ok for r in b2.painted), "every painted section should pass"

    # Expected bare failure: 'Netzseite Horizontalschiene' (section 6, 0-indexed 5).
    #   I_max = 2860 A * k3 0.80 * k5 0.86 = 1967.7 A
    #   Reserve = 1967.7 / 2086.60 = 0.9430  -> below 1.0
    fail_indices = [i for i, r in enumerate(b2.bare) if not r.ok]
    assert fail_indices == [5], "section 6 alone should fail bare"
    assert _close(b2.bare[5].reserve_pu, 0.9430066911677487, TOL)


@pytest.mark.parametrize(
    "altitude,location,expected_k5,expected_rule",
    [
        (500, "indoor", 1.000, "below_table"),
        (1000, "indoor", 1.000, "table"),
        (1000, "outdoor", 0.980, "table"),
        (2500, "indoor", 0.975, "interpolated"),
        (4000, "indoor", 0.900, "table"),
        (4400, "indoor", 0.876, "extrapolated"),
        (4400, "outdoor", 0.806, "extrapolated"),
    ],
)
def test_case3_altitude_k5_rule(altitude, location, expected_k5, expected_rule):
    result = busbar_altitude_factor(altitude, location)
    assert _close(result.k5, expected_k5, TOL)
    assert result.rule == expected_rule


@pytest.mark.parametrize(
    "painted,n_bars,width_mm,orientation,run_length_m,expected_k3,expected_rule",
    [
        (False, 2, 160, "horizontal", None, 0.80, "table"),
        (True, 2, 160, "horizontal", None, 0.85, "table"),
        (False, 1, 160, "horizontal", None, 1.00, "single_bar"),
        (False, 2, 100, "vertical", 2.0, 1.00, "vertical_exempt"),
        (False, 2, 100, "vertical", 3.0, 0.80, "table"),
    ],
)
def test_case4_k3_arrangement_rule(
    painted, n_bars, width_mm, orientation, run_length_m, expected_k3, expected_rule
):
    k = busbar_k_factors(
        painted=painted,
        n_bars=n_bars,
        width_mm=width_mm,
        thickness_mm=10,
        orientation=orientation,
        run_length_m=run_length_m,
    )
    assert _close(k.k3, expected_k3, TOL)
    assert k.k3_rule == expected_rule


def test_case5_frequency_band_gap():
    # 18 Hz lies in the undefined 16..20 Hz gap.
    in5 = BusbarInput(IM=2720, u_L=1, n_nom=36, pole_pairs=30, fL=50, altitude_m=930)
    # f_motor = 30 * 36 / 60 = 18 Hz

    with pytest.raises(BusbarCheckError):
        busbar_check(in5, band_gap_rule="error")

    b5 = busbar_check(in5, band_gap_rule="conservative")
    motor_rows = [r for r in b5.bare if _close(r.f_hz, 18.0)]
    assert motor_rows and all(r.band == "> 20 Hz (gap)" for r in motor_rows)


def test_case6_im_over_ul_undervoltage_current_basis():
    # Busbars must be sized for the worst case: the uL,min undervoltage
    # operating point (motor current rises by 1/u_L to hold shaft power
    # roughly constant). Re-running Case 1's inputs at u_L = 0.90 must
    # scale I_load_A by 1/0.90 and Reserve_pu by 0.90 relative to the
    # u_L = 1 result, with I_max_A (a property of the busbar, not the
    # load) unchanged.
    in1 = BusbarInput(IM=2720, u_L=1, n_nom=14, pole_pairs=30, fL=50, altitude_m=930)
    b1 = busbar_check(in1, location="indoor")

    in6 = BusbarInput(IM=2720, u_L=0.90, n_nom=14, pole_pairs=30, fL=50, altitude_m=930)
    b6 = busbar_check(in6, location="indoor")

    assert _close(b6.currents.i_motor_a, 2720 / 0.90, TOL * 2720)
    assert _close(b6.currents.i_line_a, 2720 / 0.90 * math.sqrt(2 / 3), TOL * 2720)
    assert _close(b6.currents.i_stack_a, 2720 / 0.90 / math.sqrt(3), TOL * 2720)

    for r6, r1 in zip(b6.bare, b1.bare):
        assert _close(r6.i_load_a, r1.i_load_a / 0.90, TOL * r1.i_load_a)
        assert _close(r6.i_max_a, r1.i_max_a, TOL * max(1, r1.i_max_a))
        assert _close(r6.reserve_pu, r1.reserve_pu * 0.90, TOL)


def test_case7_ul_is_required():
    with pytest.raises(BusbarCheckError):
        BusbarInput(IM=2720, u_L=0, n_nom=14, pole_pairs=30, fL=50, altitude_m=930)
