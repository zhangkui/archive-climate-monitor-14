import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ReferenceArea,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis
} from "recharts";
import { api } from "../api";
import type { RiskRule, SeriesPoint, Zone, ZoneVersion } from "../types";
import { ink, series } from "../theme";
import { fmtMinute } from "../ui";
import { useToast } from "../toast";

type Band = { lo: number; hi: number };

// 双指标不同量纲 → 按规范拆成两张图，各自单轴（温度含露点，湿度单独）
function TempChart({ data, band }: { data: SeriesPoint[]; band?: Band }) {
  return (
    <ResponsiveContainer width="100%" height={260}>
      <LineChart data={data} margin={{ top: 8, right: 16, bottom: 0, left: -14 }}>
        <CartesianGrid stroke={ink.grid} />
        <XAxis
          dataKey="t"
          tickFormatter={(v) => fmtMinute(v)}
          tick={{ fontSize: 11, fill: ink.muted }}
          minTickGap={60}
        />
        <YAxis
          tick={{ fontSize: 11, fill: ink.muted }}
          domain={["auto", "auto"]}
          unit="°"
        />
        <Tooltip labelFormatter={(v) => fmtMinute(v as string)} />
        <Legend />
        {/* 该库区材质生效规则的推荐区间，作为背景带而非第二条轴 */}
        {band && (
          <ReferenceArea y1={band.lo} y2={band.hi} fill={series.temp} fillOpacity={0.06} />
        )}
        <Line
          name="温度 °C"
          dataKey="temp_c"
          stroke={series.temp}
          strokeWidth={2}
          dot={false}
          isAnimationActive={false}
        />
        <Line
          name="露点 °C"
          dataKey="dew_point_c"
          stroke={series.dew}
          strokeWidth={2}
          strokeDasharray="5 3"
          dot={false}
          isAnimationActive={false}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}

function HumiChart({ data, band }: { data: SeriesPoint[]; band?: Band }) {
  return (
    <ResponsiveContainer width="100%" height={260}>
      <LineChart data={data} margin={{ top: 8, right: 16, bottom: 0, left: -14 }}>
        <CartesianGrid stroke={ink.grid} />
        <XAxis
          dataKey="t"
          tickFormatter={(v) => fmtMinute(v)}
          tick={{ fontSize: 11, fill: ink.muted }}
          minTickGap={60}
        />
        <YAxis
          tick={{ fontSize: 11, fill: ink.muted }}
          domain={[0, 100]}
          unit="%"
        />
        <Tooltip labelFormatter={(v) => fmtMinute(v as string)} />
        <Legend />
        {band && (
          <ReferenceArea y1={band.lo} y2={band.hi} fill={series.humi} fillOpacity={0.07} />
        )}
        <Line
          name="湿度 %RH"
          dataKey="humi_pct"
          stroke={series.humi}
          strokeWidth={2}
          dot={false}
          isAnimationActive={false}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function ZonesPage() {
  const toast = useToast();
  const [params] = useSearchParams();
  const [zones, setZones] = useState<Zone[]>([]);
  const [zoneId, setZoneId] = useState<number>(Number(params.get("zone")) || 0);
  const [hours, setHours] = useState(24);
  const [seriesData, setSeriesData] = useState<SeriesPoint[]>([]);
  const [versions, setVersions] = useState<ZoneVersion[]>([]);
  const [rules, setRules] = useState<RiskRule[]>([]);

  useEffect(() => {
    api
      .zones()
      .then((zs) => {
        setZones(zs);
        if (!zoneId && zs.length) setZoneId(zs[0].id);
      })
      .catch((e) => toast(e.message, "error"));
    api.rules().then(setRules).catch(() => {});
  }, []);

  useEffect(() => {
    if (!zoneId) return;
    api.zoneSeries(zoneId, hours).then(setSeriesData).catch(() => {});
    api
      .zone(zoneId)
      .then((z) => setVersions(z.versions ?? []))
      .catch(() => {});
  }, [zoneId, hours]);

  const zone = zones.find((z) => z.id === zoneId);

  const activeRule = zone
    ? (rules.find(
        (r) => r.status === "active" && r.material?.id === zone.material.id
      ) ??
        rules.find((r) => r.status === "active" && r.is_default))
    : undefined;
  const t = activeRule?.thresholds as
    | { temp?: Band; humi?: Band }
    | undefined;
  const tempBand = t?.temp;
  const humiBand = t?.humi;

  return (
    <>
      <h2 className="page-title">库区与微气候趋势</h2>
      <p className="page-desc">
        温湿度分图展示（单轴，不使用双轴图）；背景色带为当前推荐区间。边界变更只追加版本，历史测点归属不回改。
      </p>

      <div className="toolbar">
        <select
          value={zoneId}
          onChange={(e) => setZoneId(Number(e.target.value))}
        >
          {zones.map((z) => (
            <option key={z.id} value={z.id}>
              {z.code} · {z.name}（{z.material.name}）
            </option>
          ))}
        </select>
        <select value={hours} onChange={(e) => setHours(Number(e.target.value))}>
          <option value={6}>近 6 小时</option>
          <option value={24}>近 24 小时</option>
          <option value={72}>近 72 小时</option>
          <option value={168}>近 7 天</option>
        </select>
      </div>

      <div className="grid cols-2">
        <div className="card">
          <h3>温度与露点</h3>
          <TempChart data={seriesData} band={tempBand} />
        </div>
        <div className="card">
          <h3>相对湿度</h3>
          <HumiChart data={seriesData} band={humiBand} />
        </div>
      </div>

      <div className="card" style={{ marginTop: 14 }}>
        <h3>
          边界版本履历
          {zone && (
            <span className="muted-text" style={{ fontWeight: 400 }}>
              {" "}
              — {zone.code} 当前 v{zone.boundary_version}
            </span>
          )}
        </h3>
        <table>
          <thead>
            <tr>
              <th>版本</th>
              <th>变更类型</th>
              <th>生效时间</th>
              <th>操作人</th>
              <th>原因</th>
            </tr>
          </thead>
          <tbody>
            {[...versions].reverse().map((v) => (
              <tr key={v.id}>
                <td>v{v.version}</td>
                <td>{v.change_type}</td>
                <td className="metric-num">{fmtMinute(v.effective_at)}</td>
                <td>{v.changed_by ?? "—"}</td>
                <td>{v.change_reason ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
