# CycloTool Web

Python/FastAPI + React rebuild of the MATLAB **CycloTool** cycloconverter
dimensioning/analysis suite (`cyclotool/` in this repo). This folder is a
new, independent codebase living alongside the MATLAB tool — the MATLAB
version is not modified or removed, and stays the reference for
cross-checking every ported formula.

## Why this stack

See the chat discussion for the full comparison. Summary: **Python for the
calculation engine, a web UI (FastAPI + React) for the interface**, not
Jupyter (great for exploration, poor as a delivered multi-tab tool) and
not staying in MATLAB App Designer (license cost per user, and the pixel-
position layout system is the direct cause of two real bugs fixed this
session — a hidden toolbar, no progress feedback). A browser-based app
needs nothing installed beyond the browser itself.

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
      reports/               Jinja2 HTML templates + WeasyPrint -> PDF,
                              one per report type (see "Report mapping" below)
      main.py                App entrypoint, CORS, router registration
    tests/                   pytest, one file per calc domain, asserting
                              against the SAME reference values the MATLAB
                              tests/*.m files already validated against
  frontend/                  React + TypeScript + Vite
    src/
      api/<domain>.ts        Typed fetch wrapper, mirrors the backend
                              Pydantic models by hand (see note below)
      pages/<Domain>.tsx      One page per domain: input form + results
      App.tsx                 Sidebar nav + routing (HashRouter)
```

**Why calc/ has no FastAPI or Pydantic import:** the physics has to be
testable and reusable (by the API layer AND the PDF report generator)
without dragging in a web framework. This mirrors the MATLAB tool's own
separation between `src/<domain>/*.m` (calculation) and `src/gui/
CycloGUI_v2_0.m` (presentation) — same idea, cleaner enforcement, since
Python's import system won't let a calc module accidentally reach into a
FastAPI request object the way a MATLAB nested function can reach into
its enclosing GUI's workspace.

**Keeping frontend types in sync:** `frontend/src/api/*.ts` interfaces are
maintained by hand to mirror `backend/app/models/*.py`. For a project this
size, generating them (e.g. via `openapi-typescript` against FastAPI's
auto-generated `/openapi.json`) is worth setting up once more than one or
two domains are ported — noted here rather than done prematurely for a
single domain.

## What's built vs. planned

| Domain | MATLAB source | Status |
|---|---|---|
| **Busbar Check** | `src/busbar/`, `src/databases/Busbar*.m` | **Done** — calc, 17 pytest cases (same reference values as `tests/test_busbar_check.m`), API, PDF report, React page |
| Dimensioning | `src/dimensioning/` | Planned |
| Harmonics (multi-pulse + detailed-sim source spectrum) | `src/harmonics/` | Planned |
| Losses | `src/losses/` | Planned |
| Excitation | `src/excitation/` | Planned |
| Overvoltage Protection | `src/protection/` | Planned |
| Cooling (water + glycol) | `src/cooling/` | Planned |
| Firing Angle / Characteristic | `src/firing_angle/`, `src/characteristic/` | Planned |
| Detailed Simulation (waveforms, speed sweep) | `src/detailed_simulation/` | Planned — largest single domain; likely split into its own phase |
| Design Data / Engineering Data reports | `src/reports/` | Planned — depends on Dimensioning + Excitation + Protection all being ported first |

Busbar Check was chosen as the first slice because it has the cleanest
1:1 mapping to one of the five reference reports (Thermal Busbar Design)
and the smallest input surface, making it the fastest way to prove the
whole pipeline — calc port, test parity, API, PDF, UI — before repeating
the pattern at scale.

## Report mapping (the 5 PDFs supplied)

| Reference report | Source data (MATLAB module) | Web status |
|---|---|---|
| **Thermal Busbar Design** (3BHS857530) | `src/busbar/busbar_check.m` | **Done**, see `app/reports/busbar_report.py`. Shows both Bare and Painted tables rather than the reference's single table, because that table's per-section finish-selection convention isn't recoverable from the PDF alone — see the module docstring. |
| **Water Cooling Specification** (3BHS857647) | `src/cooling/calculate_cyclo_water_cooling.m`, `calculate_cyclo_pressure_drop.m` | Planned with the Cooling domain |
| **Design Data** (3BHS857640) | `src/reports/build_cyclo_design_data.m` (already consolidates Dimensioning + OperatingPoint + Excitation + FiringAngle + Protection) | Planned last — needs those domains ported first |
| **Engineering Data** (3BHS857641) | Nameplate/BOM data — **partially outside the current tool's scope**: the thyristor/BOD/component part numbers (e.g. `3BHB017655R0001`) are not in `src/databases/*.m` today, only electrical ratings are. Producing this report will need a new parts-catalog data source, to be discussed before that phase starts. | Planned, scope TBD |
| **Harmonic and Inter-harmonic Currents** (3BHS857642) | `src/harmonics/calculate_cyclo_source_harmonics.m` (characteristic harmonics + sidebands, already computed per operating point) | Planned with the Harmonics domain |

## Running it locally

**Prerequisites:** Python 3.11+, Node 18+.

### Backend

```bash
cd cyclotool-web/backend
pip install -e ".[dev]"          # or: pip install fastapi "uvicorn[standard]" pydantic jinja2 weasyprint pytest httpx
pytest                            # should show all tests passing
uvicorn app.main:app --reload --port 8000
```

WeasyPrint (PDF generation) needs its native libraries (Pango, Cairo,
GDK-PixBuf). They're already present in this environment; on a fresh
machine follow WeasyPrint's own install docs for your OS if `pip install
weasyprint` doesn't work out of the box.

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

1. Open `http://127.0.0.1:5173`.
2. Click **Busbar Check** in the sidebar.
3. Fill in the machine current, uL,min, speed, pole pairs, line
   frequency, and site altitude (defaults are the Atalaya SAG Mill
   project's values from this session).
4. Click **Run Busbar Check** — results appear as Bare/Painted tables,
   color-coded pass (green) / fail (red), with the same PaintRequired
   advisory the MATLAB tool shows.
5. Click **Download PDF Report** for a document formatted like the
   reference Thermal Busbar Design report.

Every other sidebar entry under "Planned" is a placeholder page — the
domain exists in the MATLAB tool but hasn't been ported here yet.

## Next steps (suggested order)

1. **Dimensioning** — foundational; almost every other domain (and both
   remaining reports) needs its `R` result struct as input.
2. **Cooling** (water + glycol) — self-contained, has its own PDF
   target (Water Cooling Specification), and its MATLAB tests
   (`test_cyclo_cooling.m`) are explicitly called out as
   workbook-verified reference values to reproduce.
3. **Harmonics** — has its own PDF target and is a pure function of
   Dimensioning's output.
4. **Excitation, Overvoltage Protection, Firing Angle/Characteristic** —
   each individually small; needed together for the Design Data report.
5. **Design Data report** — assembles 1-4 into the customer-facing
   summary document.
6. **Detailed Simulation** — largest remaining domain (waveform
   synthesis, device currents, motor-side/source-side harmonics, the
   multi-speed sweep); worth its own dedicated phase given its size in
   the MATLAB source.
7. **Engineering Data report** — once the parts-catalog question above
   is resolved.

Each phase should follow the pattern this slice established: port the
calc module 1:1 with the MATLAB source's own docstring notes preserved,
write pytest cases against the same reference values the MATLAB test
already validated (never re-derive new expected values), then wire up
the API endpoint, PDF template (if applicable), and React page.
