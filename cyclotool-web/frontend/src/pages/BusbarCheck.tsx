import { useState } from "react";
import {
  BusbarCheckRequest,
  BusbarCheckResponse,
  SectionResultOut,
  downloadBusbarReportDocx,
  runBusbarCheck,
} from "../api/busbar";

const DEFAULTS: BusbarCheckRequest = {
  IM: 2720,
  u_L: 0.95,
  n_nom: 14,
  pole_pairs: 30,
  fL: 50,
  altitude_m: 930,
  threshold: 1.0,
  location: "indoor",
};

function SectionTable({ title, rows }: { title: string; rows: SectionResultOut[] }) {
  return (
    <>
      <div className="section-title">{title}</div>
      <table>
        <thead>
          <tr>
            <th style={{ textAlign: "left" }}>Section</th>
            <th>I load [A]</th>
            <th>f [Hz]</th>
            <th>Band</th>
            <th>k1</th>
            <th>k2</th>
            <th>k3</th>
            <th>k4</th>
            <th>k5</th>
            <th style={{ textAlign: "left" }}>Profile</th>
            <th>I max [A]</th>
            <th>Reserve [pu]</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.section} className={r.ok ? "row-ok" : "row-fail"}>
              <td className="name">{r.section_en}</td>
              <td>{r.i_load_a.toFixed(0)}</td>
              <td>{r.f_hz.toFixed(1)}</td>
              <td>{r.band}</td>
              <td>{r.k1.toFixed(2)}</td>
              <td>{r.k2.toFixed(2)}</td>
              <td>{r.k3.toFixed(2)}</td>
              <td>{r.k4.toFixed(2)}</td>
              <td>{r.k5.toFixed(3)}</td>
              <td className="name">{r.profile}</td>
              <td>{r.i_max_a.toFixed(0)}</td>
              <td>{r.reserve_pu.toFixed(2)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

export default function BusbarCheck() {
  const [form, setForm] = useState<BusbarCheckRequest>(DEFAULTS);
  const [result, setResult] = useState<BusbarCheckResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [downloading, setDownloading] = useState(false);

  function setField<K extends keyof BusbarCheckRequest>(
    key: K,
    value: BusbarCheckRequest[K],
  ) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function handleRun() {
    setLoading(true);
    setError(null);
    try {
      const res = await runBusbarCheck(form);
      setResult(res);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setResult(null);
    } finally {
      setLoading(false);
    }
  }

  async function handleDownloadDocx() {
    setDownloading(true);
    setError(null);
    try {
      const blob = await downloadBusbarReportDocx(form);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "thermal_busbar_design.docx";
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setDownloading(false);
    }
  }

  return (
    <div>
      <h2>Busbar Check</h2>
      <p className="muted">
        Thermal ampacity check of the SR-module busbars (BBC/ABB
        Schaltanlagen-Handbuch ch. 13). Load currents use the uL,min
        undervoltage current basis (IM/u_L). No IEC/IEEE requirement found
        for this item &mdash; industry practice, not a standard requirement.
      </p>

      <div className="card">
        <div className="form-grid">
          <div>
            <label>Nominal machine current IM [A]</label>
            <input
              type="number"
              value={form.IM}
              onChange={(e) => setField("IM", Number(e.target.value))}
            />
          </div>
          <div>
            <label>uL,min [pu]</label>
            <input
              type="number"
              step="0.01"
              value={form.u_L}
              onChange={(e) => setField("u_L", Number(e.target.value))}
            />
          </div>
          <div>
            <label>Nominal speed n_nom [rpm]</label>
            <input
              type="number"
              value={form.n_nom}
              onChange={(e) => setField("n_nom", Number(e.target.value))}
            />
          </div>
          <div>
            <label>Pole pairs</label>
            <input
              type="number"
              value={form.pole_pairs}
              onChange={(e) => setField("pole_pairs", Number(e.target.value))}
            />
          </div>
          <div>
            <label>Line frequency fL [Hz]</label>
            <input
              type="number"
              value={form.fL}
              onChange={(e) => setField("fL", Number(e.target.value))}
            />
          </div>
          <div>
            <label>Site altitude [m]</label>
            <input
              type="number"
              value={form.altitude_m ?? ""}
              onChange={(e) =>
                setField(
                  "altitude_m",
                  e.target.value === "" ? null : Number(e.target.value),
                )
              }
            />
          </div>
          <div>
            <label>Minimum reserve [pu]</label>
            <input
              type="number"
              step="0.01"
              value={form.threshold}
              onChange={(e) => setField("threshold", Number(e.target.value))}
            />
          </div>
          <div>
            <label>Installation</label>
            <select
              value={form.location}
              onChange={(e) =>
                setField("location", e.target.value as BusbarCheckRequest["location"])
              }
            >
              <option value="indoor">indoor</option>
              <option value="outdoor">outdoor</option>
            </select>
          </div>
        </div>

        <div className="btn-row">
          <button onClick={handleRun} disabled={loading}>
            {loading ? "Running..." : "Run Busbar Check"}
          </button>
          <button
            className="secondary"
            onClick={handleDownloadDocx}
            disabled={downloading}
          >
            {downloading ? "Generating..." : "Download Word Report"}
          </button>
        </div>
      </div>

      {error && <div className="error-box">{error}</div>}

      {result && (
        <div className="card">
          <div
            className={`status-banner ${result.all_ok ? "ok" : "fail"}`}
          >
            {result.all_ok ? "PASS" : "FAIL"} &mdash; every section must reach
            {" "}
            {result.threshold.toFixed(2)} pu reserve
            {result.paint_required && ` | ${result.paint_required_note}`}
          </div>

          <p className="muted">
            I(motor) = {result.currents.i_motor_formula} ={" "}
            {result.currents.i_motor_a.toFixed(0)} A &nbsp;|&nbsp; I(line) ={" "}
            {result.currents.i_line_formula} ={" "}
            {result.currents.i_line_a.toFixed(0)} A &nbsp;|&nbsp; I(stack) ={" "}
            {result.currents.i_stack_formula} ={" "}
            {result.currents.i_stack_a.toFixed(0)} A
          </p>

          <SectionTable title="Bare finish" rows={result.bare} />
          <SectionTable title="Painted finish" rows={result.painted} />

          {result.warnings.length > 0 && (
            <>
              <div className="section-title">Warnings</div>
              <ul className="muted">
                {result.warnings.map((w, i) => (
                  <li key={i}>{w}</li>
                ))}
              </ul>
            </>
          )}
        </div>
      )}
    </div>
  );
}
