import { HashRouter, Routes, Route, NavLink } from "react-router-dom";
import Home from "./pages/Home";
import BusbarCheck from "./pages/BusbarCheck";
import Placeholder from "./pages/Placeholder";

const PLANNED_MODULES = [
  "Dimensioning",
  "Harmonics",
  "Losses",
  "Excitation",
  "Overvoltage Protection",
  "Cooling",
  "Detailed Simulation",
  "Design Data Report",
  "Engineering Data Report",
];

export default function App() {
  return (
    <HashRouter>
      <div className="app-shell">
        <nav className="sidebar">
          <h1>CycloTool Web</h1>
          <div className="subtitle">Cycloconverter dimensioning &amp; analysis</div>

          <div className="nav-group">
            <div className="nav-group-label">Overview</div>
            <NavLink to="/" end className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}>
              Home
            </NavLink>
          </div>

          <div className="nav-group">
            <div className="nav-group-label">Working</div>
            <NavLink to="/busbar" className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}>
              Busbar Check
            </NavLink>
          </div>

          <div className="nav-group">
            <div className="nav-group-label">Planned</div>
            {PLANNED_MODULES.map((m) => (
              <NavLink
                key={m}
                to={`/planned/${encodeURIComponent(m)}`}
                className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}
              >
                {m}
              </NavLink>
            ))}
          </div>
        </nav>

        <main className="main">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/busbar" element={<BusbarCheck />} />
            <Route
              path="/planned/:name"
              element={<PlaceholderRoute />}
            />
          </Routes>
        </main>
      </div>
    </HashRouter>
  );
}

function PlaceholderRoute() {
  const name = decodeURIComponent(window.location.hash.split("/planned/")[1] ?? "Module");
  return <Placeholder name={name} />;
}
