// Types mirror backend/app/models/engineering_data.py.

export interface BomItem {
  quantity: string;
  description: string;
  part_number: string;
  note: string;
}

export interface BomSection {
  title: string;
  items: BomItem[];
}

export interface NameplateRatings {
  input_phases: string;
  input_voltage_v: number;
  input_voltage_count: number;
  input_current_a: number;
  input_frequency_hz: number;
  input_apparent_power_kva: number;
  input_apparent_power_count: number;
  output_voltage_min_v: number;
  output_voltage_base_v: number;
  output_voltage_max_v: number;
  output_current_a: number;
  output_frequency_min_hz: number;
  output_frequency_base_hz: number;
  output_frequency_max_hz: number;
  output_apparent_power_kva: number;
  overload_cycles: string;
  overload_pu: number;
  excitation_input_voltage_v: number;
  excitation_input_frequency_hz: number;
  excitation_input_apparent_power_kva: number;
  excitation_output_voltage_v: number;
  excitation_output_current_a: number;
  excitation_output_overload_current_a: number;
}

export interface VoltageDutyInput {
  uv0_kv: number;
  series_count: number;
  line_overvoltage_factor: number;
  firing_peak_factor: number;
  utest_kv_rms: number;
  utest_duration_s: number;
  utest_frequency_hz: number;
}

export interface VoltageDutyResult {
  uwork_kv_peak: number;
  formula: string;
}

export interface ProjectMeta {
  name: string;
  equipment: string;
  client: string;
  contractor: string;
  project_no: string;
  customer_po: string;
  prepared_by: string;
  date: string;
}

export interface EngineeringDataRequest {
  project: ProjectMeta;
  nameplate: NameplateRatings;
  test_voltage: VoltageDutyInput;
  bom_sections: BomSection[];
}

async function parseErrorDetail(res: Response): Promise<string> {
  try {
    const body = await res.json();
    if (typeof body.detail === "string") return body.detail;
    return JSON.stringify(body.detail ?? body);
  } catch {
    return res.statusText;
  }
}

export async function fetchEngineeringDataDefaults(): Promise<EngineeringDataRequest> {
  const res = await fetch("/api/engineering-data/defaults");
  if (!res.ok) throw new Error(await parseErrorDetail(res));
  return res.json();
}

export async function calculateVoltageDuty(
  req: VoltageDutyInput,
): Promise<VoltageDutyResult> {
  const res = await fetch("/api/engineering-data/test-voltage", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
  });
  if (!res.ok) throw new Error(await parseErrorDetail(res));
  return res.json();
}

export async function downloadEngineeringDataReportDocx(
  req: EngineeringDataRequest,
): Promise<Blob> {
  const res = await fetch("/api/engineering-data/report.docx", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
  });
  if (!res.ok) throw new Error(await parseErrorDetail(res));
  return res.blob();
}
