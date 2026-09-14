import { useEffect, useState } from "react";
import {
  EngineeringDataRequest,
  NameplateRatings,
  VoltageDutyInput,
  VoltageDutyResult,
  calculateVoltageDuty,
  downloadEngineeringDataReportDocx,
  fetchEngineeringDataDefaults,
} from "../api/engineeringData";
import BomSectionEditor from "../components/BomSectionEditor";

function NameplateField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string | number;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <label>{label}</label>
      <input value={value} onChange={(e) => onChange(e.target.value)} />
    </div>
  );
}

export default function EngineeringData() {
  const [data, setData] = useState<EngineeringDataRequest | null>(null);
  const [voltageDuty, setVoltageDuty] = useState<VoltageDutyResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [downloading, setDownloading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchEngineeringDataDefaults()
      .then((d) => {
        setData(d);
        return calculateVoltageDuty(d.test_voltage);
      })
      .then(setVoltageDuty)
      .catch((e) => setError(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, []);

  async function recalcVoltageDuty(next: VoltageDutyInput) {
    try {
      setVoltageDuty(await calculateVoltageDuty(next));
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  function updateNameplate<K extends keyof NameplateRatings>(
    key: K,
    raw: string,
  ) {
    if (!data) return;
    const isNumeric = typeof data.nameplate[key] === "number";
    const value = (isNumeric ? Number(raw) : raw) as NameplateRatings[K];
    setData({ ...data, nameplate: { ...data.nameplate, [key]: value } });
  }

  function updateVoltageDuty<K extends keyof VoltageDutyInput>(
    key: K,
    raw: string,
  ) {
    if (!data) return;
    const next = { ...data.test_voltage, [key]: Number(raw) };
    setData({ ...data, test_voltage: next });
    recalcVoltageDuty(next);
  }

  async function handleDownload() {
    if (!data) return;
    setDownloading(true);
    setError(null);
    try {
      const blob = await downloadEngineeringDataReportDocx(data);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "engineering_data.docx";
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setDownloading(false);
    }
  }

  if (loading) return <div>Loading...</div>;
  if (!data) return <div className="error-box">{error ?? "Failed to load."}</div>;

  return (
    <div>
      <h2>Engineering Data</h2>
      <p className="muted">
        Nameplate ratings and bill-of-materials (thyristor unit, overvoltage
        protection, crowbar, excitation rectifier). <strong>Every part
        number below is a plain editable field</strong> &mdash; this tool has
        no parts catalog to look them up from. The values shown are the
        Atalaya SAG Mill project's own numbers as a worked starting example;
        replace them for a new project.
      </p>

      {error && <div className="error-box">{error}</div>}

      <div className="card">
        <h2 style={{ marginTop: 0 }}>Nameplate ratings</h2>
        <div className="form-grid">
          <NameplateField
            label="Input phases"
            value={data.nameplate.input_phases}
            onChange={(v) => updateNameplate("input_phases", v)}
          />
          <NameplateField
            label="Input voltage [V] (per unit)"
            value={data.nameplate.input_voltage_v}
            onChange={(v) => updateNameplate("input_voltage_v", v)}
          />
          <NameplateField
            label="Input voltage count"
            value={data.nameplate.input_voltage_count}
            onChange={(v) => updateNameplate("input_voltage_count", v)}
          />
          <NameplateField
            label="Input current [A rms]"
            value={data.nameplate.input_current_a}
            onChange={(v) => updateNameplate("input_current_a", v)}
          />
          <NameplateField
            label="Input frequency [Hz]"
            value={data.nameplate.input_frequency_hz}
            onChange={(v) => updateNameplate("input_frequency_hz", v)}
          />
          <NameplateField
            label="Input apparent power [kVA] (per unit)"
            value={data.nameplate.input_apparent_power_kva}
            onChange={(v) => updateNameplate("input_apparent_power_kva", v)}
          />
          <NameplateField
            label="Output voltage min [V]"
            value={data.nameplate.output_voltage_min_v}
            onChange={(v) => updateNameplate("output_voltage_min_v", v)}
          />
          <NameplateField
            label="Output voltage base [V]"
            value={data.nameplate.output_voltage_base_v}
            onChange={(v) => updateNameplate("output_voltage_base_v", v)}
          />
          <NameplateField
            label="Output voltage max [V]"
            value={data.nameplate.output_voltage_max_v}
            onChange={(v) => updateNameplate("output_voltage_max_v", v)}
          />
          <NameplateField
            label="Output current [A rms]"
            value={data.nameplate.output_current_a}
            onChange={(v) => updateNameplate("output_current_a", v)}
          />
          <NameplateField
            label="Output frequency base [Hz]"
            value={data.nameplate.output_frequency_base_hz}
            onChange={(v) => updateNameplate("output_frequency_base_hz", v)}
          />
          <NameplateField
            label="Output frequency max [Hz]"
            value={data.nameplate.output_frequency_max_hz}
            onChange={(v) => updateNameplate("output_frequency_max_hz", v)}
          />
          <NameplateField
            label="Output apparent power [kVA]"
            value={data.nameplate.output_apparent_power_kva}
            onChange={(v) => updateNameplate("output_apparent_power_kva", v)}
          />
          <NameplateField
            label="Overload duty"
            value={data.nameplate.overload_cycles}
            onChange={(v) => updateNameplate("overload_cycles", v)}
          />
          <NameplateField
            label="Overload [p.u.]"
            value={data.nameplate.overload_pu}
            onChange={(v) => updateNameplate("overload_pu", v)}
          />
          <NameplateField
            label="Excitation input voltage [V]"
            value={data.nameplate.excitation_input_voltage_v}
            onChange={(v) => updateNameplate("excitation_input_voltage_v", v)}
          />
          <NameplateField
            label="Excitation input power [kVA]"
            value={data.nameplate.excitation_input_apparent_power_kva}
            onChange={(v) =>
              updateNameplate("excitation_input_apparent_power_kva", v)
            }
          />
          <NameplateField
            label="Excitation output voltage [V]"
            value={data.nameplate.excitation_output_voltage_v}
            onChange={(v) => updateNameplate("excitation_output_voltage_v", v)}
          />
          <NameplateField
            label="Excitation output current [A]"
            value={data.nameplate.excitation_output_current_a}
            onChange={(v) => updateNameplate("excitation_output_current_a", v)}
          />
          <NameplateField
            label="Excitation overload current [A]"
            value={data.nameplate.excitation_output_overload_current_a}
            onChange={(v) =>
              updateNameplate("excitation_output_overload_current_a", v)
            }
          />
        </div>
      </div>

      <div className="card">
        <h2 style={{ marginTop: 0 }}>
          Test voltage (Kurzschliesser, Wandler, Pr&uuml;fspannung)
        </h2>
        <div className="form-grid">
          <NameplateField
            label="Uv0 [kVrms]"
            value={data.test_voltage.uv0_kv}
            onChange={(v) => updateVoltageDuty("uv0_kv", v)}
          />
          <NameplateField
            label="Series count (n)"
            value={data.test_voltage.series_count}
            onChange={(v) => updateVoltageDuty("series_count", v)}
          />
          <NameplateField
            label="Line overvoltage factor"
            value={data.test_voltage.line_overvoltage_factor}
            onChange={(v) => updateVoltageDuty("line_overvoltage_factor", v)}
          />
          <NameplateField
            label="Firing peak factor"
            value={data.test_voltage.firing_peak_factor}
            onChange={(v) => updateVoltageDuty("firing_peak_factor", v)}
          />
          <NameplateField
            label="Utest [kVrms] (editable, not looked up)"
            value={data.test_voltage.utest_kv_rms}
            onChange={(v) => updateVoltageDuty("utest_kv_rms", v)}
          />
          <NameplateField
            label="Utest duration [s]"
            value={data.test_voltage.utest_duration_s}
            onChange={(v) => updateVoltageDuty("utest_duration_s", v)}
          />
        </div>
        {voltageDuty && (
          <p className="muted">
            {voltageDuty.formula} &mdash; per IEC 61800-5-1 Table 23, not
            digitised in this tool; Utest above is a value you supply, not a
            computed lookup.
          </p>
        )}
      </div>

      {data.bom_sections.map((section, i) => (
        <div className="card" key={section.title}>
          <BomSectionEditor
            section={section}
            onChange={(updated) => {
              const sections = data.bom_sections.map((s, idx) =>
                idx === i ? updated : s,
              );
              setData({ ...data, bom_sections: sections });
            }}
          />
        </div>
      ))}

      <div className="btn-row">
        <button onClick={handleDownload} disabled={downloading}>
          {downloading ? "Generating..." : "Download Word Report"}
        </button>
      </div>
    </div>
  );
}
