import { Link } from "react-router-dom";

export default function Home() {
  return (
    <div>
      <h2>CycloTool Web</h2>
      <p className="muted">
        Python/FastAPI + React rebuild of the MATLAB CycloTool cycloconverter
        dimensioning/analysis suite. This is an in-progress port -- see the
        project README (cyclotool-web/README.md) for the full architecture
        and roadmap.
      </p>
      <div className="card">
        <strong>Working now:</strong>
        <ul>
          <li>
            <Link to="/busbar">Busbar Check</Link> &mdash; thermal ampacity
            check of the SR-module busbars, with a Word report matching the
            reference "Thermal Busbar Design" report.
          </li>
          <li>
            <Link to="/engineering-data">Engineering Data</Link> &mdash;
            nameplate ratings and editable bill-of-materials (thyristor
            unit, overvoltage protection, crowbar, excitation rectifier),
            with a Word report matching the reference "Engineering Data"
            report. Part numbers are plain editable fields &mdash; this tool
            has no parts catalog.
          </li>
        </ul>
        <strong>Planned next</strong> (see sidebar for the full module list):
        Dimensioning, Harmonics, Losses, Excitation, Overvoltage Protection,
        Cooling, Detailed Simulation, Design Data / Water Cooling reports.
      </div>
    </div>
  );
}
