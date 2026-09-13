import { useEffect, useState } from "react";
import { api } from "../api";
import type { ReportRecord, Zone } from "../types";
import { Tag } from "../ui";
import { useToast } from "../toast";

function isoLocal(d: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}`;
}

export default function ReportsPage() {
  const toast = useToast();
  const [reports, setReports] = useState<ReportRecord[]>([]);
  const [zones, setZones] = useState<Zone[]>([]);
  const [zoneId, setZoneId] = useState("");
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 86_400_000);
  const [from, setFrom] = useState(isoLocal(weekAgo));
  const [to, setTo] = useState(isoLocal(now));
  const [busy, setBusy] = useState(false);

  const load = () =>
    api.reports().then(setReports).catch((e) => toast(e.message, "error"));

  useEffect(() => {
    load();
    api.zones().then(setZones).catch(() => {});
  }, []);

  const create = async () => {
    setBusy(true);
    try {
      await api.createReport({
        kind: "event_export",
        zone_id: zoneId ? Number(zoneId) : undefined,
        period_from: new Date(from).toISOString(),
        period_to: new Date(to).toISOString()
      });
      toast("导出任务已提交，完成后可下载 CSV");
      setTimeout(load, 1500);
    } catch (e) {
      toast((e as Error).message, "error");
    } finally {
      setBusy(false);
    }
  };

  const download = async (r: ReportRecord) => {
    try {
      const { url } = await api.reportDownload(r.id);
      window.open(url, "_blank");
    } catch (e) {
      toast((e as Error).message, "error");
    }
  };

  return (
    <>
      <h2 className="page-title">报表导出（MinIO 对象存储）</h2>
      <p className="page-desc">
        风险事件按时间窗导出为 CSV，由 Sidekiq 异步生成并上传 MinIO，下载链接为 15
        分钟有效的预签名 URL。
      </p>

      <div className="card" style={{ marginBottom: 14 }}>
        <div className="toolbar" style={{ marginBottom: 0 }}>
          <select value={zoneId} onChange={(e) => setZoneId(e.target.value)}>
            <option value="">全部库区</option>
            {zones.map((z) => (
              <option key={z.id} value={z.id}>
                {z.code} · {z.name}
              </option>
            ))}
          </select>
          <input
            type="datetime-local"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
          />
          <span className="muted-text">至</span>
          <input
            type="datetime-local"
            value={to}
            onChange={(e) => setTo(e.target.value)}
          />
          <button className="primary" disabled={busy} onClick={create}>
            生成导出
          </button>
        </div>
      </div>

      <div className="card" style={{ overflow: "auto" }}>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>状态</th>
              <th>区间</th>
              <th>大小</th>
              <th>创建人</th>
              <th>生成时间</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {reports.map((r) => (
              <tr key={r.id}>
                <td>{r.id}</td>
                <td>
                  {r.status === "done" ? (
                    <Tag tone="good">完成</Tag>
                  ) : r.status === "failed" ? (
                    <Tag tone="critical">失败</Tag>
                  ) : (
                    <Tag tone="warning">{r.status}</Tag>
                  )}
                </td>
                <td className="metric-num">
                  {fmt(r.period_from)} ~ {fmt(r.period_to)}
                </td>
                <td>{r.size_bytes ? `${(r.size_bytes / 1024).toFixed(1)} KB` : "—"}</td>
                <td>{r.created_by ?? "—"}</td>
                <td className="metric-num">
                  {r.generated_at ? new Date(r.generated_at).toLocaleString("zh-CN", { hour12: false }) : "—"}
                </td>
                <td>
                  {r.status === "done" ? (
                    <button onClick={() => download(r)}>下载 CSV</button>
                  ) : r.status === "failed" ? (
                    <span className="muted-text">{r.error_message}</span>
                  ) : (
                    <span className="muted-text">生成中…</span>
                  )}
                </td>
              </tr>
            ))}
            {reports.length === 0 && (
              <tr>
                <td colSpan={7} className="muted-text">
                  暂无导出记录
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

const fmt = (s: string) =>
  new Date(s).toLocaleString("zh-CN", {
    hour12: false,
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  });
