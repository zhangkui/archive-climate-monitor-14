export interface Material {
  id: number;
  code: string;
  name: string;
  description?: string;
}

export interface Zone {
  id: number;
  code: string;
  name: string;
  status: "active" | "merged" | "closed";
  area_m2?: number;
  established_at?: string;
  material: Material;
  boundary_version?: number;
  boundary?: Record<string, unknown>;
}

export interface ZoneVersion {
  id: number;
  version: number;
  change_type: "created" | "boundary" | "merge" | "rename" | "close";
  boundary: Record<string, unknown>;
  related_zone_id?: number;
  changed_by?: string;
  change_reason?: string;
  effective_at: string;
}

export interface Sensor {
  id: number;
  code: string;
  name: string;
  sensor_type: "temp" | "humi" | "combi";
  manufacturer?: string;
  model?: string;
  firmware_version?: string;
  status: "active" | "offline" | "replaced" | "retired";
  commissioned_on?: string;
  current_zone: { id: number; code: string; name: string } | null;
}

export interface RiskRule {
  id: number;
  version: number;
  name: string;
  material: Material | null;
  is_default: boolean;
  thresholds: Record<string, unknown>;
  detectors: Record<string, unknown>;
  status: "draft" | "active" | "superseded";
  change_summary?: string;
  created_by?: string;
  activated_at?: string;
  superseded_at?: string;
  created_at: string;
}

export type Severity = "info" | "warning" | "critical";
export type EventType =
  | "sustained_threshold"
  | "drift"
  | "missing"
  | "boundary_transition";
export type EventStatus =
  | "open"
  | "confirmed"
  | "resolved"
  | "dismissed"
  | "false_positive";

export interface RiskEvent {
  id: number;
  event_type: EventType;
  severity: Severity;
  status: EventStatus;
  zone: { id: number; code: string; name: string };
  sensor: { id: number; code: string; name: string } | null;
  risk_rule_id?: number;
  risk_rule_version?: number;
  metric?: string;
  peak_value?: number;
  latest_value?: number;
  latest_seen_at?: string;
  started_at: string;
  ended_at?: string;
  detected_at: string;
  confirmed_at?: string;
  confirmed_by?: string;
  resolution?: string;
  resolution_note?: string;
  evidence: Record<string, unknown>;
}

export interface AuditEvent {
  id: number;
  category:
    | "anomaly_confirmation"
    | "rule_change"
    | "device_replacement"
    | "zone_change"
    | "system";
  action: string;
  actor_name?: string;
  auditable_type?: string;
  auditable_id?: number;
  before_data: Record<string, unknown>;
  after_data: Record<string, unknown>;
  note?: string;
  occurred_at: string;
}

export interface SeriesPoint {
  t: string;
  temp_c?: number;
  temp_min?: number;
  temp_max?: number;
  humi_pct?: number;
  humi_min?: number;
  humi_max?: number;
  dew_point_c?: number;
  samples: number;
}

export interface DashboardData {
  generated_at: string;
  summary: {
    zones_total: number;
    sensors_total: number;
    sensors_offline: number;
    open_events: number;
    critical: number;
    warning: number;
  };
  zones: Array<{
    id: number;
    code: string;
    name: string;
    material: Material;
    last_reading_at?: string;
    avg_temp_c?: number;
    avg_humi_pct?: number;
    avg_dew_point_c?: number;
    open_event_count: number;
  }>;
  open_events: RiskEvent[];
}

export interface ReportRecord {
  id: number;
  kind: string;
  status: "pending" | "running" | "done" | "failed";
  zone_id?: number;
  period_from: string;
  period_to: string;
  object_key?: string;
  size_bytes?: number;
  content_type?: string;
  created_by?: string;
  error_message?: string;
  generated_at?: string;
  created_at: string;
}
