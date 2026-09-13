import type {
  AuditEvent,
  DashboardData,
  ReportRecord,
  RiskEvent,
  RiskRule,
  Sensor,
  SeriesPoint,
  Zone,
  ZoneVersion
} from "./types";

const BASE = import.meta.env.VITE_API_BASE ?? "/api";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string
  ) {
    super(message);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "content-type": "application/json", ...(init?.headers ?? {}) },
    ...init
  });
  if (!res.ok) {
    let message = res.statusText;
    try {
      const body = await res.json();
      message = body.message ?? body.error ?? message;
    } catch {
      /* ignore */
    }
    throw new ApiError(res.status, message);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

const qs = (params: Record<string, string | number | undefined | null>) => {
  const usp = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== "") usp.set(k, String(v));
  });
  const s = usp.toString();
  return s ? `?${s}` : "";
};

export const api = {
  dashboard: () => request<DashboardData>(`/dashboard`),

  zones: () => request<Zone[]>(`/zones`),
  zone: (id: number) => request<Zone & { versions: ZoneVersion[] }>(`/zones/${id}`),
  zoneSeries: (id: number, hours: number) =>
    request<SeriesPoint[]>(`/zones/${id}/series${qs({ hours })}`),
  zoneHistory: (id: number) =>
    request<{
      zone: Zone;
      versions: ZoneVersion[];
      assignments: Array<{
        sensor_code: string;
        sensor_name: string;
        location_desc?: string;
        valid_from: string;
        valid_to?: string;
      }>;
    }>(`/zones/${id}/history`),
  changeBoundary: (
    id: number,
    body: { reason: string; boundary: unknown; moved_sensor_codes: string[][] }
  ) =>
    request(`/zones/${id}/boundary`, {
      method: "POST",
      body: JSON.stringify(body)
    }),

  sensors: () => request<Sensor[]>(`/sensors`),
  replaceSensor: (
    id: number,
    body: {
      code: string;
      name: string;
      sensor_type: string;
      manufacturer?: string;
      model?: string;
      zone_id?: number;
      note?: string;
    }
  ) =>
    request<Sensor>(`/sensors/${id}/replace`, {
      method: "POST",
      body: JSON.stringify(body)
    }),

  rules: () => request<RiskRule[]>(`/rules`),
  createRule: (body: Record<string, unknown>) =>
    request<RiskRule>(`/rules`, { method: "POST", body: JSON.stringify(body) }),
  activateRule: (id: number) =>
    request<RiskRule>(`/rules/${id}/activate`, { method: "POST" }),

  events: (filters: Record<string, string | undefined>) =>
    request<RiskEvent[]>(`/events${qs(filters)}`),
  confirmEvent: (
    id: number,
    body: { outcome: string; note?: string }
  ) =>
    request<RiskEvent>(`/events/${id}/confirm`, {
      method: "POST",
      body: JSON.stringify(body)
    }),

  audit: (filters: Record<string, string | undefined>) =>
    request<AuditEvent[]>(`/audit${qs(filters)}`),

  reports: () => request<ReportRecord[]>(`/reports`),
  createReport: (body: {
    kind: string;
    zone_id?: number;
    period_from: string;
    period_to: string;
  }) =>
    request<ReportRecord>(`/reports`, {
      method: "POST",
      body: JSON.stringify(body)
    }),
  reportDownload: (id: number) =>
    request<{ url: string; expires_in: number }>(`/reports/${id}/download`)
};
