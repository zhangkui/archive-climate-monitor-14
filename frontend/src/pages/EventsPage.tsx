import { useEffect, useState } from "react";
import { api } from "../api";
import type { RiskEvent } from "../types";
import {
  EVENT_TYPE_LABEL,
  METRIC_LABEL,
  SeverityTag,
  StatusTag
} from "../labels";
import { Modal, fmtMinute } from "../ui";
import { useToast } from "../toast";

const OUTCOMES = [
  { value: "confirmed", label: "确认异常" },
  { value: "resolved", label: "确认并处置完成" },
  { value: "false_positive", label: "标记误报" },
  { value: "dismissed", label: "忽略" }
];

export default function EventsPage() {
  const toast = useToast();
  const [events, setEvents] = useState<RiskEvent[]>([]);
  const [status, setStatus] = useState("");
  const [type, setType] = useState("");
  const [loading, setLoading] = useState(true);
  const [active, setActive] = useState<RiskEvent | null>(null);
  const [evidenceFor, setEvidenceFor] = useState<RiskEvent | null>(null);
  const [outcome, setOutcome] = useState("confirmed");
  const [note, setNote] = useState("");

  const load = () => {
    setLoading(true);
    api
      .events({ status: status || undefined, event_type: type || undefined })
      .then(setEvents)
      .catch((e) => toast(e.message, "error"))
      .finally(() => setLoading(false));
  };

  useEffect(load, [status, type]);

  const submit = async () => {
    if (!active) return;
    try {
      await api.confirmEvent(active.id, { outcome, note });
      toast("处置已记录，并写入审计日志");
      setActive(null);
      setNote("");
      load();
    } catch (e) {
      toast((e as Error).message, "error");
    }
  };

  return (
    <>
      <h2 className="page-title">风险事件工作台</h2>
      <p className="page-desc">
        事件结论（级别、规则版本、起始时刻、证据）在数据库层冻结；规则升级不会改写历史判定。
      </p>

      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">全部状态</option>
          <option value="open">待确认</option>
          <option value="confirmed">已确认</option>
          <option value="resolved">已处置</option>
          <option value="false_positive">误报</option>
          <option value="dismissed">已忽略</option>
        </select>
        <select value={type} onChange={(e) => setType(e.target.value)}>
          <option value="">全部类型</option>
          {Object.entries(EVENT_TYPE_LABEL).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </select>
        <span className="muted-text">{loading ? "加载中…" : `${events.length} 条`}</span>
      </div>

      <div className="card" style={{ overflow: "auto" }}>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>级别</th>
              <th>类型</th>
              <th>库区</th>
              <th>设备</th>
              <th>指标</th>
              <th>峰值/当前</th>
              <th>规则版本</th>
              <th>起始时刻</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {events.map((e) => (
              <tr key={e.id}>
                <td>{e.id}</td>
                <td>
                  <SeverityTag severity={e.severity} />
                </td>
                <td>{EVENT_TYPE_LABEL[e.event_type]}</td>
                <td>{e.zone.code}</td>
                <td>{e.sensor?.code ?? "—"}</td>
                <td>{METRIC_LABEL[e.metric ?? ""] ?? e.metric}</td>
                <td className="metric-num">
                  {e.peak_value ?? "—"}
                  {e.latest_value != null && e.status === "open" && (
                    <span className="muted-text"> / {e.latest_value}</span>
                  )}
                </td>
                <td>
                  {e.risk_rule_version ? (
                    <span className="badge-rule">v{e.risk_rule_version}</span>
                  ) : (
                    <span className="muted-text">—</span>
                  )}
                </td>
                <td className="metric-num">{fmtMinute(e.started_at)}</td>
                <td>
                  <StatusTag status={e.status} />
                </td>
                <td>
                  <div className="row-actions">
                    <button onClick={() => setEvidenceFor(e)}>证据</button>
                    {(e.status === "open" || e.status === "confirmed") && (
                      <button className="primary" onClick={() => setActive(e)}>
                        处置
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {active && (
        <Modal title={`处置事件 #${active.id}`} onClose={() => setActive(null)}>
          <dl className="kv">
            <dt>类型</dt>
            <dd>{EVENT_TYPE_LABEL[active.event_type]}</dd>
            <dt>库区/设备</dt>
            <dd>
              {active.zone.code} / {active.sensor?.code ?? "—"}
            </dd>
            <dt>判定规则</dt>
            <dd>
              v{active.risk_rule_version}（历史结论已冻结，不受当前规则版本影响）
            </dd>
            <dt>处置人</dt>
            <dd>
              <span className="muted-text">
                由请求头 X-Actor 传递，演示环境默认 system
              </span>
            </dd>
          </dl>
          <div className="field" style={{ marginTop: 12 }}>
            <label>处置结论</label>
            <select value={outcome} onChange={(e) => setOutcome(e.target.value)}>
              {OUTCOMES.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>处置说明（记入审计）</label>
            <textarea
              rows={3}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="例如：已开启除湿机，2 小时后恢复，纸张无霉变痕迹"
            />
          </div>
          <div className="modal-actions">
            <button onClick={() => setActive(null)}>取消</button>
            <button className="primary" onClick={submit}>
              提交处置
            </button>
          </div>
        </Modal>
      )}

      {evidenceFor && (
        <Modal title={`事件 #${evidenceFor.id} 判定证据`} onClose={() => setEvidenceFor(null)}>
          <dl className="kv">
            <dt>检测时间</dt>
            <dd>{fmtMinute(evidenceFor.detected_at)}</dd>
            <dt>起始时刻</dt>
            <dd>{fmtMinute(evidenceFor.started_at)}</dd>
            <dt>确认信息</dt>
            <dd>
              {evidenceFor.confirmed_by
                ? `${evidenceFor.confirmed_by} @ ${fmtMinute(evidenceFor.confirmed_at)}`
                : "—"}
            </dd>
          </dl>
          <div className="field" style={{ marginTop: 12 }}>
            <label>冻结证据（含当时阈值快照）</label>
            <div className="evidence">
              {JSON.stringify(evidenceFor.evidence, null, 2)}
            </div>
          </div>
        </Modal>
      )}
    </>
  );
}
