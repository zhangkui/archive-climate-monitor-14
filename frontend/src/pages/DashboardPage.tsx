import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";
import type { DashboardData } from "../types";
import { SeverityTag, StatusTag, EVENT_TYPE_LABEL, METRIC_LABEL } from "../labels";
import { fmtMinute } from "../ui";

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = () =>
    api
      .dashboard()
      .then(setData)
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    const timer = setInterval(load, 60_000);
    return () => clearInterval(timer);
  }, []);

  if (error) return <div className="card">加载失败：{error}（请确认后端已启动）</div>;
  if (!data) return <div className="card">加载中…</div>;

  const s = data.summary;

  return (
    <>
      <h2 className="page-title">风险总览</h2>
      <p className="page-desc">
        数据截至 {fmtMinute(data.generated_at)}，每 60 秒自动刷新
      </p>

      <div className="grid cols-4" style={{ marginBottom: 14 }}>
        <div className="card stat critical">
          <div className="value">
            {s.critical}
            <span className="unit">项严重</span>
          </div>
          <div className="label">进行中严重异常</div>
        </div>
        <div className="card stat warning">
          <div className="value">
            {s.warning}
            <span className="unit">项预警</span>
          </div>
          <div className="label">进行中预警</div>
        </div>
        <div className="card stat">
          <div className="value">
            {s.zones_total}
            <span className="unit">个库区</span>
          </div>
          <div className="label">在管库区</div>
        </div>
        <div className="card stat">
          <div className="value">
            {s.sensors_total}
            <span className="unit">在线</span>
            {" / "}
            <span className={s.sensors_offline ? "" : "muted-text"}>
              {s.sensors_offline} 离线
            </span>
          </div>
          <div className="label">传感器设备</div>
        </div>
      </div>

      <div className="grid cols-2">
        <div className="card">
          <h3>库区当前微气候（5 分钟均值）</h3>
          <table>
            <thead>
              <tr>
                <th>库区</th>
                <th>材质</th>
                <th>温度 °C</th>
                <th>湿度 %RH</th>
                <th>露点 °C</th>
                <th>未结事件</th>
              </tr>
            </thead>
            <tbody>
              {data.zones.map((z) => (
                <tr key={z.id}>
                  <td>
                    <Link to={`/zones?zone=${z.id}`}>{z.code}</Link>
                    <div className="muted-text">{z.name}</div>
                  </td>
                  <td>{z.material.name}</td>
                  <td className="temp metric-num">{z.avg_temp_c ?? "—"}</td>
                  <td className="humi metric-num">{z.avg_humi_pct ?? "—"}</td>
                  <td className="metric-num">{z.avg_dew_point_c ?? "—"}</td>
                  <td>
                    {z.open_event_count > 0 ? (
                      <span className="tag warning">{z.open_event_count}</span>
                    ) : (
                      <span className="tag good">正常</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="chart-hint">蓝=温度系列色，橙=湿度系列色，状态色不用于系列编码</div>
        </div>

        <div className="card">
          <h3>未结风险事件（{data.open_events.length}）</h3>
          <table>
            <thead>
              <tr>
                <th>级别</th>
                <th>类型</th>
                <th>库区/设备</th>
                <th>指标</th>
                <th>起始</th>
                <th>状态</th>
              </tr>
            </thead>
            <tbody>
              {data.open_events.slice(0, 12).map((e) => (
                <tr key={e.id}>
                  <td>
                    <SeverityTag severity={e.severity} />
                  </td>
                  <td>{EVENT_TYPE_LABEL[e.event_type]}</td>
                  <td>
                    {e.zone.code}
                    {e.sensor && (
                      <div className="muted-text">{e.sensor.code}</div>
                    )}
                  </td>
                  <td>{METRIC_LABEL[e.metric ?? ""] ?? e.metric}</td>
                  <td className="metric-num">{fmtMinute(e.started_at)}</td>
                  <td>
                    <StatusTag status={e.status} />
                  </td>
                </tr>
              ))}
              {data.open_events.length === 0 && (
                <tr>
                  <td colSpan={6} className="muted-text">
                    当前无未结事件
                  </td>
                </tr>
              )}
            </tbody>
          </table>
          <p style={{ marginTop: 10 }}>
            <Link to="/events">前往事件工作台 →</Link>
          </p>
        </div>
      </div>
    </>
  );
}
