import { useEffect, useState } from "react";
import { api } from "../api";
import type { AuditEvent } from "../types";
import { CATEGORY_LABEL } from "../labels";
import { fmtMinute } from "../ui";
import { useToast } from "../toast";

const CATEGORIES = [
  "anomaly_confirmation",
  "rule_change",
  "device_replacement",
  "zone_change",
  "system"
];

export default function AuditPage() {
  const toast = useToast();
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [category, setCategory] = useState("");
  const [openPayload, setOpenPayload] = useState<AuditEvent | null>(null);

  useEffect(() => {
    api
      .audit({ category: category || undefined })
      .then(setEvents)
      .catch((e) => toast(e.message, "error"));
  }, [category]);

  return (
    <>
      <h2 className="page-title">审计日志</h2>
      <p className="page-desc">
        异常确认、规则调整、设备替换、库区边界变更全部落审计流水。
        数据库触发器禁止 UPDATE/DELETE，只允许追加。
      </p>

      <div className="toolbar">
        <select value={category} onChange={(e) => setCategory(e.target.value)}>
          <option value="">全部类别</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {CATEGORY_LABEL[c]}
            </option>
          ))}
        </select>
        <span className="muted-text">{events.length} 条（最近 300 条）</span>
      </div>

      <div className="card" style={{ overflow: "auto" }}>
        <table>
          <thead>
            <tr>
              <th>时间</th>
              <th>类别</th>
              <th>动作</th>
              <th>操作人</th>
              <th>对象</th>
              <th>说明</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {events.map((a) => (
              <tr key={a.id}>
                <td className="metric-num">{fmtMinute(a.occurred_at)}</td>
                <td>{CATEGORY_LABEL[a.category] ?? a.category}</td>
                <td>{a.action}</td>
                <td>{a.actor_name ?? "—"}</td>
                <td className="muted-text">
                  {a.auditable_type ? `${a.auditable_type}#${a.auditable_id}` : "—"}
                </td>
                <td style={{ maxWidth: 340 }}>{a.note ?? "—"}</td>
                <td>
                  <button onClick={() => setOpenPayload(a)}>明细</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {openPayload && (
        <div className="modal-backdrop" onClick={() => setOpenPayload(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>
              审计明细 #{openPayload.id}
            </h2>
            <dl className="kv">
              <dt>变更前</dt>
              <dd>
                <pre className="evidence">
                  {JSON.stringify(openPayload.before_data, null, 2)}
                </pre>
              </dd>
              <dt>变更后</dt>
              <dd>
                <pre className="evidence">
                  {JSON.stringify(openPayload.after_data, null, 2)}
                </pre>
              </dd>
            </dl>
            <div className="modal-actions">
              <button className="primary" onClick={() => setOpenPayload(null)}>
                关闭
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
