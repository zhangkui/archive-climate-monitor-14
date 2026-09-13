import { useEffect, useState } from "react";
import { api } from "../api";
import type { Sensor } from "../types";
import { Modal, Tag } from "../ui";
import { useToast } from "../toast";

export default function SensorsPage() {
  const toast = useToast();
  const [sensors, setSensors] = useState<Sensor[]>([]);
  const [replacing, setReplacing] = useState<Sensor | null>(null);

  const load = () =>
    api.sensors().then(setSensors).catch((e) => toast(e.message, "error"));
  useEffect(() => {
    load();
  }, []);

  return (
    <>
      <h2 className="page-title">传感器设备与安装履历</h2>
      <p className="page-desc">
        设备替换不停机：旧设备置为 replaced 并保留全部历史测点，新设备延续同点位安装履历；过程进入审计日志。
      </p>

      <div className="card" style={{ overflow: "auto" }}>
        <table>
          <thead>
            <tr>
              <th>编号</th>
              <th>名称</th>
              <th>类型</th>
              <th>型号 / 固件</th>
              <th>当前库区</th>
              <th>启用日期</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {sensors.map((s) => (
              <tr key={s.id}>
                <td className="metric-num">{s.code}</td>
                <td>{s.name}</td>
                <td>
                  {s.sensor_type === "combi"
                    ? "温湿度一体"
                    : s.sensor_type === "temp"
                      ? "温度"
                      : "湿度"}
                </td>
                <td className="muted-text">
                  {s.model} / {s.firmware_version}
                </td>
                <td>{s.current_zone ? `${s.current_zone.code}` : "—"}</td>
                <td className="muted-text">{s.commissioned_on}</td>
                <td>
                  {s.status === "active" ? (
                    <Tag tone="good">在线</Tag>
                  ) : s.status === "offline" ? (
                    <Tag tone="critical">离线</Tag>
                  ) : (
                    <Tag tone="muted">
                      {s.status === "replaced" ? "已替换" : s.status}
                    </Tag>
                  )}
                </td>
                <td>
                  {s.status !== "replaced" && s.status !== "retired" && (
                    <button onClick={() => setReplacing(s)}>替换设备</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {replacing && (
        <ReplaceModal
          sensor={replacing}
          onClose={() => setReplacing(null)}
          onDone={() => {
            setReplacing(null);
            load();
          }}
        />
      )}
    </>
  );
}

function ReplaceModal({
  sensor,
  onClose,
  onDone
}: {
  sensor: Sensor;
  onClose: () => void;
  onDone: () => void;
}) {
  const toast = useToast();
  const [code, setCode] = useState(`${sensor.code}-R`);
  const [name, setName] = useState(`${sensor.name}（新）`);
  const [note, setNote] = useState("漂移超标，例行更换");
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    setBusy(true);
    try {
      await api.replaceSensor(sensor.id, {
        code,
        name,
        sensor_type: sensor.sensor_type,
        manufacturer: sensor.manufacturer,
        model: sensor.model,
        note
      });
      toast("设备替换完成：旧设备下线、新设备上线，已写审计");
      onDone();
    } catch (e) {
      toast((e as Error).message, "error");
      setBusy(false);
    }
  };

  return (
    <Modal title={`替换设备 ${sensor.code}`} onClose={onClose}>
      <dl className="kv">
        <dt>旧设备</dt>
        <dd>
          {sensor.code} · {sensor.name}
        </dd>
        <dt>当前库区</dt>
        <dd>{sensor.current_zone?.code ?? "—"}（新设备自动延续安装位置）</dd>
      </dl>
      <div className="field" style={{ marginTop: 12 }}>
        <label>新设备编号</label>
        <input value={code} onChange={(e) => setCode(e.target.value)} />
      </div>
      <div className="field">
        <label>新设备名称</label>
        <input value={name} onChange={(e) => setName(e.target.value)} />
      </div>
      <div className="field">
        <label>替换原因（记入审计）</label>
        <textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} />
      </div>
      <div className="modal-actions">
        <button onClick={onClose}>取消</button>
        <button className="primary" disabled={busy} onClick={submit}>
          确认替换
        </button>
      </div>
    </Modal>
  );
}
