# CycloTool

MATLAB dimensioning and design tool for cycloconverters (6/12/18-pulse):
electrical dimensioning, harmonics, losses, water cooling, firing angle,
excitation, overvoltage protection, and a uifigure-based GUI
(`src/gui/CycloGUI_v2_0.m`).

## Layout

- `src/gui/` — the application (CycloGUI_v2_0.m)
- `src/dimensioning/`, `src/harmonics/`, `src/losses/`, `src/cooling/`,
  `src/excitation/`, `src/protection/`, `src/characteristic/`,
  `src/firing_angle/`, `src/busbar/`, `src/detailed_simulation/` — calculation
  engines, one folder per subsystem
- `src/databases/` — component/material lookup tables
- `src/reports/` — Design Data report generation
- `src/ui_helpers/` — shared GUI utilities
- `tests/` — matlab.unittest test suite (`runtests('tests')`)
- `docs/` — reference workbooks/design documents (Git LFS recommended for
  binary formats: `.xlsx`, `.docx`)

## Running

```matlab
addpath(genpath('src'))
CycloGUI_v2_0
```

## Testing

```matlab
addpath(genpath('src'))
results = runtests('tests');
table(results)
```

CI runs this automatically on every push/PR (`.github/workflows/matlab-tests.yml`).

## Status

Cooling engine (`src/cooling/`) was rebuilt against the reference workbook
"Design of Water-Cooling System for Cycloconverters" and is covered by
`tests/test_cyclo_cooling.m`, verified against the workbook's own computed
cells to <0.1% across all four converter types (6/12/18-pulse, 6-pulse w/
fuses). See `tests/test_cyclo_cooling.m` header for details.

Known open items (not yet actioned, tracked here instead of lost in chat
history):
- `src/*` calculation engines other than cooling have not been
  cross-checked against a reference source the way cooling was.
- No CLAUDE.md-driven regression test exists yet for the GUI itself
  (uifigure callbacks aren't unit-testable without a display; consider
  `matlab.uitest` on a CI runner with a virtual display if this becomes a
  priority).
- Several `src/reports` and `src/detailed_simulation` functions are not
  yet wired to the GUI (present as callable library functions only).
