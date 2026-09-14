// Types mirror backend/app/models/busbar.py exactly -- keep the two in
// sync by hand for now (see the project README's "keeping frontend
// types in sync" note for why this isn't yet generated automatically).

export type Location = "indoor" | "outdoor";
export type BandGapRule = "conservative" | "error";

export interface BusbarCheckRequest {
  IM: number;
  u_L: number;
  n_nom: number;
  pole_pairs: number;
  fL: number;
  altitude_m?: number | null;
  threshold?: number;
  location?: Location;
  k1?: number | null;
  k2?: number | null;
  k5?: number | null;
  band_gap_rule?: BandGapRule;
}

export interface SectionResultOut {
  section: string;
  section_en: string;
  profile: string;
  i_load_a: number;
  f_hz: number;
  band: string;
  k1: number;
  k2: number;
  k3: number;
  k4: number;
  k5: number;
  k_total: number;
  i_base_a: number;
  i_max_a: number;
  reserve_pu: number;
  ok: boolean;
  k3_source: string;
  k3_rule: string;
  k5_source: string;
  k5_rule: string;
}

export interface CurrentsOut {
  i_motor_a: number;
  i_motor_formula: string;
  i_line_a: number;
  i_line_formula: string;
  i_stack_a: number;
  i_stack_formula: string;
  f_motor_hz: number;
  f_motor_formula: string;
  f_line_hz: number;
  f_line_formula: string;
}

export interface BusbarCheckResponse {
  bare: SectionResultOut[];
  painted: SectionResultOut[];
  currents: CurrentsOut;
  threshold: number;
  altitude_m: number;
  location: Location;
  all_ok: boolean;
  paint_required: boolean;
  paint_required_note: string;
  warnings: string[];
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

export async function runBusbarCheck(
  req: BusbarCheckRequest,
): Promise<BusbarCheckResponse> {
  const res = await fetch("/api/busbar/check", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
  });
  if (!res.ok) throw new Error(await parseErrorDetail(res));
  return res.json();
}

export async function downloadBusbarReportDocx(
  req: BusbarCheckRequest,
): Promise<Blob> {
  const res = await fetch("/api/busbar/check/report.docx", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
  });
  if (!res.ok) throw new Error(await parseErrorDetail(res));
  return res.blob();
}
