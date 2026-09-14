"""Base thermal current rating of the converter busbars.

Ported 1:1 from cyclotool/src/databases/BusbarAmpacityTable.m -- see that
file for the full provenance note. Summary:

    No IEC/IEEE requirement found for this item. These currents and the
    associated k-factor scheme come from the BBC/ABB Schaltanlagen-
    Handbuch, chapter 13 (Bild 13-4, Tabellen 13-13 and 13-14). They are
    manufacturer/industry practice, not a standard requirement. IEC
    61439-1 covers temperature-rise verification of assemblies but does
    not publish busbar ampacity tables.

Reference conditions of the tabulated currents: ambient 35 degC, bar
surface 65 degC, altitude < 1000 m, single circuit, no adjacent-bar
derating. Deviations are covered by the k1..k5 correction factors (see
k_factors.py).

Entries 1..4 are tabulated values, transcribed verbatim from
Schienenueberpruefung.xlsx, sheet 'blanke Schienen'/'gestrichene
Schienen', rows 5..8, columns H..K. Entry 5 is derived (see below).
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class BusbarProfile:
    profile: str
    n_bars: int
    width_mm: float
    thickness_mm: float
    i_bare_lt16: float
    i_bare_gt20: float
    i_painted_lt16: float
    i_painted_gt20: float
    source: str


_SRC_TAB = (
    "Schienenueberpruefung.xlsx rows 5..8 "
    "(BBC/ABB Schaltanlagen-Handbuch ch.13)"
)

# Entry 5 derivation constants (workbook row 9): only I_bare_lt16 is a
# given value there; the rest follow the workbook's own derivation,
# restated as named constants (see BusbarAmpacityTable.m for the full
# profile-identity note -- confirmed against the Schienenplan drawing as
# a single 150 x 20 bar, not the workbook's inconsistent row label).
_I150_BARE_LT16 = 3350.0  # [A] given, workbook cell H9
_F150_FREQ_RATIO = 1.12  # [-] workbook cell I9, '=H9/1.12'


def _build_table() -> list[BusbarProfile]:
    db = [
        BusbarProfile("2 x (100 x 10)", 2, 100, 10, 2890, 2480, 3310, 2850, _SRC_TAB),
        BusbarProfile("2 x (120 x 10)", 2, 120, 10, 3390, 2860, 3900, 3280, _SRC_TAB),
        BusbarProfile("1 x (160 x 10)", 1, 160, 10, 2470, 2220, 3010, 2700, _SRC_TAB),
        BusbarProfile("2 x (160 x 10)", 2, 160, 10, 4400, 3590, 5060, 4130, _SRC_TAB),
    ]

    entry3 = db[2]
    i150_bare_gt20 = _I150_BARE_LT16 / _F150_FREQ_RATIO
    i150_painted_lt16 = (
        _I150_BARE_LT16 * entry3.i_painted_lt16 / entry3.i_bare_lt16
    )
    i150_painted_gt20 = (
        i150_bare_gt20 * entry3.i_painted_gt20 / entry3.i_bare_gt20
    )
    db.append(
        BusbarProfile(
            "1 x (150 x 20)",
            1,
            150,
            20,
            _I150_BARE_LT16,
            i150_bare_gt20,
            i150_painted_lt16,
            i150_painted_gt20,
            (
                f"Derived: H9 = {_I150_BARE_LT16:g} A given; >20 Hz via "
                f"ratio {_F150_FREQ_RATIO:g}; painted columns scaled from "
                "the 1 x (160 x 10) profile"
            ),
        )
    )

    for e in db:
        currents = (e.i_bare_lt16, e.i_bare_gt20, e.i_painted_lt16, e.i_painted_gt20)
        if any(not (c > 0) for c in currents):
            raise ValueError(f"Entry {e.profile} has a non-positive rating.")

    return db


BUSBAR_AMPACITY_TABLE: list[BusbarProfile] = _build_table()


def get_profile(profile_name: str) -> BusbarProfile:
    for entry in BUSBAR_AMPACITY_TABLE:
        if entry.profile == profile_name:
            return entry
    available = ", ".join(e.profile for e in BUSBAR_AMPACITY_TABLE)
    raise KeyError(
        f"Unknown busbar profile '{profile_name}'. Available: {available}"
    )
