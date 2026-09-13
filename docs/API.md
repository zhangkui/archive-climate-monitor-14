# API 契约

Base path：`/api`，JSON 收发。操作员身份用请求头 `X-Actor: <姓名>` 传递
（演示系统，默认 `system`）。时间统一 ISO-8601（带时区）。

## 数据接入

### POST /ingest
批量上报测点；缺失 `dew_point_c` 时由温湿度按 Magnus 公式反算。
入库时按 `observed_at` 解析库区归属并冻结 `zone_id`。

```json
{
  "sensor_code": "S-A01",
  "readings": [
    {
      "observed_at": "2026-09-12T08:00:00+08:00",
      "temp_c": 22.1,
      "humi_pct": 53.4,
      "battery_pct": 86.0
    }
  ]
}
```

→ `201 {"accepted":1,"rejected":0,"errors":[]}`

### POST /device-events
设备状态事件：`online/offline/battery_low/fault/calibration/replaced`。

```json
{ "sensor_code": "S-B02", "event_kind": "offline",
  "occurred_at": "2026-09-12T05:00:00+08:00",
  "payload": {"battery_pct": 7}, "note": "供电模块故障" }
```

## 看板与库区

| 方法/路径 | 说明 |
|---|---|
| GET /dashboard | 汇总指标、各库区 5 分钟桶当前温湿度/露点、未结事件 |
| GET /zones | 库区列表（含材质、当前边界版本） |
| GET /zones/:id | 库区详情 + 边界版本履历 |
| GET /zones/:id/series?hours=24 | 趋势：≤72h 走 5 分钟实时桶，>72h 走小时连续聚合 |
| GET /zones/:id/history | 边界版本 + 传感器安装履历 |
| POST /zones/:id/boundary | 登记边界变更（见下） |
| POST /zones/:id/merge | 并入另一库区 `{target_zone_id, reason}` |

边界变更：

```json
{
  "boundary": {"floor": 1, "polygon": [[0,2],[10,2],[10,8],[0,8]]},
  "reason": "西墙缓冲间移交影像库",
  "moved_sensor_codes": [["S-D02", "Z-C"]]
}
```

## 传感器与替换

| 方法/路径 | 说明 |
|---|---|
| GET /sensors | 设备列表（含当前库区） |
| POST /sensors | 建档（可带 `zone_id`、`location_desc`） |
| PATCH /sensors/:id | 改名/固件/状态 |
| POST /sensors/:id/replace | 设备替换（见下） |

```json
POST /sensors/5/replace
{ "code": "S-B03", "name": "二区南窗（新）", "sensor_type": "combi",
  "manufacturer": "Sensirion", "model": "SHT4x demo",
  "zone_id": 2, "note": "供电故障更换" }
```

旧设备置 `replaced` 并保留全部历史测点；新设备延续安装履历；
旧设备未结的 drift/missing 以 `device_replaced` 收口；写审计。

## 规则版本

| 方法/路径 | 说明 |
|---|---|
| GET /rules | 全部版本（`?status=active` 过滤） |
| GET /rules/:id | 单版本 |
| POST /rules | 新建版本（自动递增 version，初始 draft；`"activate": true` 即建即激活） |
| POST /rules/:id/activate | 激活：同适用对象旧版本事务内 superseded，写审计 |

```json
POST /rules
{ "name": "全库通用规则 v4", "is_default": true, "activate": true,
  "change_summary": "入梅前湿度上限收紧",
  "thresholds": {
    "temp": {"min":14,"max":24,"critical_min":10,"critical_max":30},
    "humi": {"min":45,"max":53,"critical_min":35,"critical_max":65},
    "dew_proximity_c": 2.0 },
  "detectors": { "sustained_minutes":30, "missing_gap_minutes":60,
    "drift_window_hours":24, "drift_slope_c_per_day":0.8,
    "drift_peer_diff_c":1.5, "lookback_hours":3 } }
```

## 风险事件

| 方法/路径 | 说明 |
|---|---|
| GET /events | 过滤：`status/event_type/severity/zone_id/sensor_id/from/to` |
| GET /events/:id | 详情（含冻结证据 `evidence`） |
| POST /events/:id/confirm | 处置（见下） |
| POST /events/:id/resolve | `confirm` 的 `resolved` 简写 |

```json
POST /events/12/confirm
{ "outcome": "resolved", "note": "开启除湿机 2 小时后恢复，纸张无霉变" }
```

`outcome` 取值：`confirmed / resolved / dismissed / false_positive`
（合法流转：open → 四种；confirmed → resolved / false_positive）。

事件对象关键字段：

```json
{
  "id": 12, "event_type": "sustained_threshold", "severity": "warning",
  "status": "open", "metric": "temp_c",
  "risk_rule_version": 3,
  "peak_value": 27.4, "latest_value": 27.0,
  "started_at": "2026-09-12T06:05:00+08:00",
  "evidence": { "direction": "high", "duration_seconds": 5400,
                "rule_thresholds": {"temp": {"min":14,"max":24}} }
}
```

事件类型：`sustained_threshold`（连续超阈值/露点逼近）、`drift`（漂移）、
`missing`（缺测）、`boundary_transition`（边界变更）。
级别：`info / warning / critical`。

## 审计

| 方法/路径 | 说明 |
|---|---|
| GET /audit | 过滤：`category`、`auditable_type`+`auditable_id`、`from/to`（限 300 条） |
| GET /audit/:id | 单条（before/after jsonb） |

`category`：`anomaly_confirmation / rule_change / device_replacement /
zone_change / system`。表级触发器禁止 UPDATE/DELETE。

## 报表（MinIO）

| 方法/路径 | 说明 |
|---|---|
| GET /reports | 任务列表 |
| POST /reports | 创建导出任务（Sidekiq 异步生成 CSV 并上传） |
| GET /reports/:id | 任务状态 |
| GET /reports/:id/download | 返回 15 分钟有效的预签名 URL |

```json
POST /reports
{ "kind": "event_export", "zone_id": null,
  "period_from": "2026-09-01T00:00:00+08:00",
  "period_to":   "2026-09-12T23:59:59+08:00" }

GET /reports/1/download
{ "url": "http://localhost:9000/archive-reports/exports/...?...", "expires_in": 900 }
```

## 错误格式

```json
{ "error": "validation_failed", "message": "Name can't be blank" }
```

状态码：400 bad_request / 404 not_found / 409 conflict（非法状态流转等）/
422 validation_failed。
