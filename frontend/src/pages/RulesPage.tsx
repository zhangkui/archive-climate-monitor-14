import { useEffect, useState } from "react";
import { api } from "../api";
import type { RiskRule } from "../types";
import { Tag } from "../ui";
import { Modal } from "../ui";
import { useToast } from "../toast";

export default function RulesPage() {
  const toast = useToast();
  const [rules, setRules] = useState<RiskRule[]>([]);
  const [creating, setCreating] = useState(false);

  const load = () => api.rules().then(setRules).catch((e) => toast(e.message, "error"));
  useEffect(() => {
    load();
  }, []);

  const activate = async (r: RiskRule) => {
    try {
      await api.activateRule(r.id);
      toast(`v${r.version} 已激活，旧版本转为 superseded；历史事件仍引用旧版本`);
      load();
    } catch (e) {
      toast((e as Error).message, "error");
    }
  };

  return (
    <>
      <h2 className="page-title">风险规则版本</h2>
      <p className="page-desc">
        规则只增不改：每次调整生成新版本并整体快照阈值。风险事件冻结当时的
        rule_version 与阈值，因此规则收紧/放宽都不会覆盖历史结论。
      </p>

      <div className="toolbar">
        <button className="primary" onClick={() => setCreating(true)}>
          新建规则版本
        </button>
      </div>

      <div className="grid cols-2">
        {rules.map((r) => (
          <div className="card" key={r.id}>
            <h3 style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
              <span>
                <span className="badge-rule">v{r.version}</span> {r.name}
              </span>
              {r.status === "active" ? (
                <Tag tone="good">生效中</Tag>
              ) : r.status === "draft" ? (
                <Tag tone="warning">草稿</Tag>
              ) : (
                <Tag tone="muted">已取代</Tag>
              )}
            </h3>
            <dl className="kv">
              <dt>适用材质</dt>
              <dd>{r.is_default ? "全库默认" : r.material?.name ?? "—"}</dd>
              <dt>温度区间</dt>
              <dd className="metric-num">
                {JSON.stringify(r.thresholds.temp)}
              </dd>
              <dt>湿度区间</dt>
              <dd className="metric-num">
                {JSON.stringify(r.thresholds.humi)}
              </dd>
              <dt>检测参数</dt>
              <dd className="metric-num">
                {JSON.stringify(r.detectors)}
              </dd>
              <dt>变更说明</dt>
              <dd>{r.change_summary ?? "—"}</dd>
              <dt>创建/激活</dt>
              <dd className="metric-num">
                {r.created_by ?? "—"} ·{" "}
                {r.activated_at
                  ? new Date(r.activated_at).toLocaleDateString("zh-CN")
                  : "—"}
              </dd>
            </dl>
            {r.status !== "active" && (
              <div style={{ marginTop: 10 }}>
                <button onClick={() => activate(r)}>激活此版本</button>
              </div>
            )}
          </div>
        ))}
      </div>

      {creating && (
        <NewRuleModal
          onClose={() => setCreating(false)}
          onCreated={() => {
            setCreating(false);
            load();
          }}
        />
      )}
    </>
  );
}

function NewRuleModal({
  onClose,
  onCreated
}: {
  onClose: () => void;
  onCreated: () => void;
}) {
  const toast = useToast();
  const [name, setName] = useState("全库通用微气候规则 v3 修订");
  const [tempMax, setTempMax] = useState("24");
  const [humiMax, setHumiMax] = useState("55");
  const [sustained, setSustained] = useState("30");
  const [summary, setSummary] = useState("");

  const submit = async () => {
    const body = {
      name,
      is_default: true,
      activate: true,
      change_summary: summary,
      thresholds: {
        temp: { min: 14, max: Number(tempMax), critical_min: 10, critical_max: 30 },
        humi: { min: 45, max: Number(humiMax), critical_min: 35, critical_max: 65 },
        dew_proximity_c: 2.0
      },
      detectors: {
        sustained_minutes: Number(sustained),
        missing_gap_minutes: 60,
        drift_window_hours: 24,
        drift_slope_c_per_day: 0.8,
        drift_peer_diff_c: 1.5,
        lookback_hours: 3
      }
    };
    try {
      await api.createRule(body);
      toast("新版本已创建并激活，调整已进入审计日志");
      onCreated();
    } catch (e) {
      toast((e as Error).message, "error");
    }
  };

  return (
    <Modal title="新建规则版本（基于当前默认值快速调整）" onClose={onClose}>
      <div className="field">
        <label>版本名称</label>
        <input value={name} onChange={(e) => setName(e.target.value)} />
      </div>
      <div className="grid cols-3">
        <div className="field">
          <label>温度上限 °C</label>
          <input value={tempMax} onChange={(e) => setTempMax(e.target.value)} />
        </div>
        <div className="field">
          <label>湿度上限 %RH</label>
          <input value={humiMax} onChange={(e) => setHumiMax(e.target.value)} />
        </div>
        <div className="field">
          <label>连续超标分钟</label>
          <input value={sustained} onChange={(e) => setSustained(e.target.value)} />
        </div>
      </div>
      <div className="field">
        <label>变更说明</label>
        <textarea
          rows={2}
          value={summary}
          onChange={(e) => setSummary(e.target.value)}
          placeholder="例如：入梅前湿度上限收紧到 55%RH"
        />
      </div>
      <div className="modal-actions">
        <button onClick={onClose}>取消</button>
        <button className="primary" onClick={submit}>
          创建并激活
        </button>
      </div>
    </Modal>
  );
}
