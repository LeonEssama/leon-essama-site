"""Default busbar sections of an SR module.

Ported 1:1 from cyclotool/src/databases/BusbarSectionDefaults.m -- see
that file for the full provenance/inference notes (orientation and run
length are not recorded in the source workbook and are inferred from
which k3 the workbook applies to each row; the 'Stapelverschienung' k3
override of 0.8/0.85 is pinned as a probable copy-paste error in the
original workbook, kept here because it is what the released workbook
does).
"""

from __future__ import annotations

from dataclasses import dataclass

from .k_factors import Orientation

CurrentBasis = str  # 'Motor' | 'Line' | 'Stack'
FreqBasis = str  # 'Motor' | 'Line'


@dataclass(frozen=True)
class BusbarSection:
    name: str
    name_en: str
    profile: str
    current_basis: CurrentBasis
    freq_basis: FreqBasis
    orientation: Orientation
    run_length_m: float | None
    # k3_override: None means compute from Tab. 13-13; -1.0 is the
    # sentinel meaning "use the workbook's linked k3 for a 2-bar
    # horizontal arrangement of the same finish" (busbar_check.py
    # resolves it); a normal float is a literal k3 override.
    k3_override: float | None


def busbar_section_defaults() -> list[BusbarSection]:
    return [
        BusbarSection(
            "Sternpunkt Stromrichter beim Stapel",
            "Converter star point at the stack",
            "2 x (160 x 10)",
            "Motor",
            "Motor",
            "horizontal",
            None,
            None,
        ),
        # Profile confirmed against the busbar layout drawing
        # (Schienenplan), which labels this bar '1 x 150 x 20'. The
        # source workbook's row label '1 x (150 x 10)' is wrong.
        BusbarSection(
            "Motorseitige Kabelanschlussschiene",
            "Motor-side cable connection bar",
            "1 x (150 x 20)",
            "Motor",
            "Motor",
            "horizontal",
            None,
            None,
        ),
        BusbarSection(
            "Motorphase Stromrichter beim Stapel",
            "Motor phase at the stack",
            "2 x (160 x 10)",
            "Motor",
            "Motor",
            "horizontal",
            None,
            None,
        ),
        # Profile confirmed against the busbar layout drawing: '1 x 150 x 20'.
        BusbarSection(
            "Netzseite Kabelanschlussschiene",
            "Line-side cable connection bar",
            "1 x (150 x 20)",
            "Line",
            "Line",
            "horizontal",
            None,
            None,
        ),
        BusbarSection(
            "Netzseite Steigschiene",
            "Line-side riser bar",
            "2 x (100 x 10)",
            "Line",
            "Line",
            "vertical",
            2.0,
            None,
        ),
        BusbarSection(
            "Netzseite Horizontalschiene",
            "Line-side horizontal bar",
            "2 x (120 x 10)",
            "Line",
            "Line",
            "horizontal",
            None,
            None,
        ),
        BusbarSection(
            "Stapelverschienung",
            "Stack busbar",
            "1 x (160 x 10)",
            "Stack",
            "Line",
            "horizontal",
            None,
            -1.0,
        ),
        BusbarSection(
            "Wandlerverschienung",
            "Current-transformer busbar",
            "2 x (120 x 10)",
            "Stack",
            "Line",
            "horizontal",
            None,
            None,
        ),
    ]
