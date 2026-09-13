import type { EventStatus, EventType, Severity } from "./types";
import { Tag } from "./ui";

export const EVENT_TYPE_LABEL: Record<EventType, string> = {
  sustained_threshold: "连续超阈值",
  drift: "传感器漂移",
  missing: "缺测",
  boundary_transition: "边界变更"
};

export const METRIC_LABEL: Record<string, string> = {
  temp_c: "温度",
  humi_pct: "湿度",
  dew_margin_c: "露点裕度",
  availability: "数据可用性",
  zone_assignment: "库区归属"
};

export const CATEGORY_LABEL: Record<string, string> = {
  anomaly_confirmation: "异常确认",
  rule_change: "规则调整",
  device_replacement: "设备替换",
  zone_change: "库区变更",
  system: "系统"
};

export function SeverityTag({ severity }: { severity: Severity }) {
  if (severity === "critical") return <Tag tone="critical">严重</Tag>;
  if (severity === "warning") return <Tag tone="warning">预警</Tag>;
  return <Tag tone="info">提示</Tag>;
}

const STATUS_MAP: Record<EventStatus, { tone: "warning" | "info" | "resolved" | "false_positive"; label: string }> = {
  open: { tone: "warning", label: "待确认" },
  confirmed: { tone: "info", label: "已确认" },
  resolved: { tone: "resolved", label: "已处置" },
  dismissed: { tone: "false_positive", label: "已忽略" },
  false_positive: { tone: "false_positive", label: "误报" }
};

export function StatusTag({ status }: { status: EventStatus }) {
  const s = STATUS_MAP[status] ?? { tone: "muted" as const, label: status };
  return <Tag tone={s.tone}>{s.label}</Tag>;
}
