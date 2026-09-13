# CycloTool Web

Python/FastAPI + React rebuild of the MATLAB **CycloTool** cycloconverter
dimensioning/analysis suite. Every report this tool generates is a
**Word (.docx)** document laid out to match one of the five reference
PDF reports supplied for this project.

## Why this stack

Summary: **Python for the calculation engine, a web UI (FastAPI + React)
for the interface**, not Jupyter (great for exploration, poor as a
delivered multi-tab tool) and not staying in MATLAB App Designer (license
cost per user, and the pixel-position layout system was the direct cause
of two real bugs fixed in the MATLAB tool this session — a hidden
toolbar, no progress feedback). A browser-based app needs nothing
installed beyond the browser itself.

## Architecture

```
cyclotool-web/
  backend/                  FastAPI application
    app/
      calc/<domain>/        Pure-Python physics, no web-framework import.
                             One subpackage per MATLAB src/<domain>/ folder.
                             Ported 1:1 from the .m files, same formulas,
                             same variable names where practical, same
                             docstring engineering notes (standard vs.
                             practice vs. estimate).
      models/<domain>.py     Pydantic request/response models (API I/O only)
      api/<domain>.py        FastAPI router: HTTP <-> calc layer
      reports/               python-docx report generation:
                                docx_utils.py    shared helpers (title,
                                                 meta table, data table
                                                 with pass/fail shading,
                                                 bullets, footer) used by
                                                 every report
                                <domain>_report.py   one per report type,
                                                 see "Report mapping" below
      main.py                App entrypoint, CORS, router registration
    tests/                   pytest, one file per calc domain, asserting
                              against the SAME reference values the MATLAB
                              tests/*.m files already validated against
  frontend/                  React + TypeScript + Vite
    src/
      api/<domain>.ts        Typed fetch wrapper, mirrors the backend
                              Pydantic models by hand (see note below)
      pages/<Domain>.tsx      One page per domain: input form + results
      components/             Reusable editors (e.g. BomSectionEditor)
      App.tsx                 Sidebar nav + routing (HashRouter)
```

**Why calc/ has no FastAPI or Pydantic import:** the physics has to be
testable and reusable (by the API layer AND the report generator)
without dragging in a web framework. This mirrors the MATLAB tool's own
separation between `src/<domain>/*.m` (calculation) and `src/gui/
CycloGUI_v2_0.m` (presentation) — same idea, cleaner enforcement, since
Python's import system won't let a calc module accidentally reach into a
FastAPI request object the way a MATLAB nested function can reach into
its enclosing GUI's workspace.

**Reports are Word, not PDF:** every report endpoint (`/report.docx`)
returns a `.docx` built with `python-docx` via the shared helpers in
`app/reports/docx_utils.py`. A new report is: build the domain's result
object, call `add_title`/`add_meta_table`/`add_data_table`/etc. in the
right order, `render_bytes(doc)`.

**Keeping frontend types in sync:** `frontend/src/api/*.ts` interfaces are
maintained by hand to mirror `backend/app/models/*.py`. Worth generating
(e.g. via `openapi-typescript` against FastAPI's auto-generated
`/openapi.json`) once more domains are ported.

## What's built vs. planned

| Domain | MATLAB source | Status |
|---|---|---|
| **Busbar Check** | `src/busbar/`, `src/databases/Busbar*.m` | **Done** — calc, 17 pytest cases (same reference values as `tests/test_busbar_check.m`), API, Word report, React page |
| **Engineering Data** | Nameplate/BOM data (no MATLAB equivalent exists — see below) | **Done** — nameplate ratings, the one real formula (test/working-voltage), and an editable bill-of-materials (thyristor unit, overvoltage protection, crowbar, excitation rectifier), API, Word report, React page |
| Dimensioning | `src/dimensioning/` | Planned |
| Harmonics (multi-pulse + detailed-sim source spectrum) | `src/harmonics/` | Planned |
| Losses | `src/losses/` | Planned |
| Excitation | `src/excitation/` | Planned |
| Overvoltage Protection | `src/protection/` | Planned |
| Cooling (water + glycol) | `src/cooling/` | Planned |
| Firing Angle / Characteristic | `src/firing_angle/`, `src/characteristic/` | Planned |
| Detailed Simulation (waveforms, speed sweep) | `src/detailed_simulation/` | Planned — largest single domain; likely split into its own phase |
| Design Data report | `src/reports/` | Planned — depends on Dimensioning + Excitation + Protection all being ported first |

## Report mapping (the 5 PDFs supplied) — all as Word documents

| Reference report | Source data | Web status |
|---|---|---|
| **Thermal Busbar Design** (3BHS857530) | `src/busbar/busbar_check.m` | **Done**, `app/reports/busbar_report.py`. Shows both Bare and Painted tables rather than the reference's single table, because that table's per-section finish-selection convention isn't recoverable from the PDF alone — see the module docstring. |
| **Engineering Data** (3BHS857641) | Nameplate + BOM, see `app/calc/engineering_data/` | **Done**, `app/reports/engineering_data_report.py`. **Part numbers, quantities and descriptions are plain editable fields** — this tool has no parts catalog (the MATLAB tool doesn't either), so nothing is looked up or validated. The Atalaya SAG Mill project's own values ship as the default/example data. The one real calculation (working/test-voltage formula) reproduces the reference report's own worked example (6.92 kVpeak) exactly; `Utest` itself is user-supplied since IEC 61800-5-1 Table 23 is not digitised here. |
| **Water Cooling Specification** (3BHS857647) | `src/cooling/calculate_cyclo_water_cooling.m`, `calculate_cyclo_pressure_drop.m` | Planned with the Cooling domain |
| **Design Data** (3BHS857640) | `src/reports/build_cyclo_design_data.m` (already consolidates Dimensioning + OperatingPoint + Excitation + FiringAngle + Protection) | Planned last — needs those domains ported first |
| **Harmonic and Inter-harmonic Currents** (3BHS857642) | `src/harmonics/calculate_cyclo_source_harmonics.m` (characteristic harmonics + sidebands, already computed per operating point) | Planned with the Harmonics domain |

## Running it locally

**Prerequisites:** Python 3.11+, Node 18+. See the chat guide ("what to
install on your laptop") for exact download links and OS-specific notes.

### Backend

```bash
cd cyclotool-web/backend
pip install -e ".[dev]"          # or: pip install fastapi "uvicorn[standard]" pydantic python-docx pytest httpx
pytest                            # should show all tests passing
uvicorn app.main:app --reload --port 8000
```

Once running, open `http://127.0.0.1:8000/docs` for interactive API docs
(Swagger UI) — useful for testing endpoints before the frontend has a
page for them.

### Frontend

```bash
cd cyclotool-web/frontend
npm install
npm run dev                       # opens on http://127.0.0.1:5173
```

The Vite dev server proxies `/api/*` to `http://127.0.0.1:8000` (see
`vite.config.ts`), so run the backend first.

### Using it

See the chat's page-by-page walkthrough for the full "how to use it"
guide. In short: open `http://127.0.0.1:5173`, pick a page from the
sidebar under "Working" (Busbar Check or Engineering Data), fill in or
edit the fields, and use the Download button for a Word report matching
the corresponding reference PDF's structure.

Every sidebar entry under "Planned" is a placeholder page — the domain
exists in the MATLAB tool but hasn't been ported here yet.

## Next steps (suggested order)

1. **Dimensioning** — foundational; almost every other domain (and the
   Design Data report) needs its `R` result struct as input.
2. **Cooling** (water + glycol) — self-contained, has its own report
   target (Water Cooling Specification), and its MATLAB tests
   (`test_cyclo_cooling.m`) are explicitly called out as
   workbook-verified reference values to reproduce.
3. **Harmonics** — has its own report target and is a pure function of
   Dimensioning's output.
4. **Excitation, Overvoltage Protection, Firing Angle/Characteristic** —
   each individually small; needed together for the Design Data report.
5. **Design Data report** — assembles 1-4 into the customer-facing
   summary document.
6. **Detailed Simulation** — largest remaining domain (waveform
   synthesis, device currents, motor-side/source-side harmonics, the
   multi-speed sweep); worth its own dedicated phase given its size in
   the MATLAB source.

Each phase should follow the pattern this slice established: port the
calc module 1:1 with the MATLAB source's own docstring notes preserved,
write pytest cases against the same reference values the MATLAB test
already validated (never re-derive new expected values), then wire up
the API endpoint, the `.docx` report template, and the React page.
