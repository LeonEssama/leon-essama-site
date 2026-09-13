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
            check of the SR-module busbars, with PDF report generation
            matching the reference "Thermal Busbar Design" report.
          </li>
        </ul>
        <strong>Planned next</strong> (see sidebar for the full module list):
        Dimensioning, Harmonics, Losses, Excitation, Overvoltage Protection,
        Cooling, Detailed Simulation, Design/Engineering Data reports.
      </div>
    </div>
  );
}
