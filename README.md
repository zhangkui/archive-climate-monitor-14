# 纸质档案库房微气候风险监测系统（Archive Vault）

接收纸质档案库房的温度、湿度、露点与设备状态数据，按**库区**与**档案材质**
计算风险等级，识别连续超阈值、传感器漂移、缺测和库区边界变更。风险规则
**版本化**，历史结论不会因规则更新被覆盖；异常确认、规则调整、设备替换、
边界变更全部进入只追加的审计日志。

## 技术栈（固定）

| 层 | 选型 |
|---|---|
| 后端 | Ruby 3.3 + Rails 8（API-only） |
| 时序数据 | TimescaleDB 2.15（PostgreSQL 16）：hypertable、压缩、连续聚合 |
| 缓存/消息/锁 | Redis 7 + Sidekiq 7 |
| 对象存储 | MinIO（S3 兼容，CSV 报表 + 预签名下载） |
| 前端 | React 19 + TypeScript + Vite 6 + Recharts |
| 部署 | Docker Compose 一键启动 |

## 一键启动

```bash
docker compose up -d --build
```

启动后：

- 前端：<http://localhost:8080>
- 后端 API：<http://localhost:3000/api/dashboard>
- MinIO 控制台：<http://localhost:9001>（`archive-minio` / `archive-minio-secret`）

web 容器首次启动会自动执行迁移并灌入**幂等演示数据**（`SEED_ON_BOOT=true`，
正式部署请在 `docker-compose.yml` 中改为 `false`）。

演示数据包含：4 个库区、3 种材质、9 个传感器、3 个规则版本、72 小时
5 分钟粒度测点，以及一个锁定在 v1 规则上的 40 天前历史事件。

### 实时演示

```bash
# 每 60 秒为每个在线传感器补一个新测点
docker compose exec web bundle exec rails risk:simulate INTERVAL=60

# 立即手动触发一轮风险扫描（默认 worker 每 300 秒自动扫描）
docker compose exec web bundle exec rails risk:scan_once
```

## 风险检测如何工作

| 检测 | 判定方式 | 事件类型 |
|---|---|---|
| 连续超阈值 | 从最新点回溯连续越限段，持续 ≥ `sustained_minutes`（默认 30 分钟）；分级 warning / critical | `sustained_threshold` |
| 露点逼近 | 温湿度按 Magnus 公式反算露点，气温−露点 < `dew_proximity_c`（默认 2°C） | `sustained_threshold`（指标 `dew_margin_c`） |
| 缺测 | 相邻测点间隔 > `missing_gap_minutes`，或最近测点过久未更新 | `missing` |
| 传感器漂移 | 24h 窗口线性回归斜率 ≥ `drift_slope_c_per_day` **且** 与同库区同伴中位数偏差 ≥ `drift_peer_diff_c` | `drift` |
| 库区边界变更 | 边界/合并事件驱动：追加 `zone_versions`、重切安装履历、产生归属迁移事件 | `boundary_transition` |

阈值按**材质**解析：材质专属规则优先，其次全库默认规则。

### 历史结论为什么不会被覆盖（三道防线）

1. **规则不可变**：规则只增不改，调整 = 新建版本；激活新版本时旧版本整体
   转为 `superseded`。
2. **事件冻结快照**：每个 `risk_event` 写入 `risk_rule_id / risk_rule_version`
   以及当时的阈值/检测参数与证据（`evidence` jsonb）。
3. **数据库触发器兜底**：`trg_freeze_risk_event_history` 禁止修改事件的
   类型、级别、规则版本、起始时刻、指标、库区/设备、证据、去重键；
   只允许状态流转（确认/处置/误报）与进展字段更新。

### 审计

`audit_events` 只追加，并由触发器 `trg_audit_no_update/no_delete` 在
数据库层禁止 UPDATE/DELETE。记录四类动作：
异常确认（`anomaly_confirmation`）、规则调整（`rule_change`）、
设备替换（`device_replacement`）、库区变更（`zone_change`）。

操作员身份通过请求头 `X-Actor` 传递（演示系统默认 `system`）。

## 主要目录

```
backend/
  db/migrate/                 # 含 Timescale hypertable/压缩/连续聚合/冻结触发器
  app/models/                 # RiskRule 版本化、Zone/Sensor 时间履历
  lib/risk/                   # 风险引擎（evaluator/sweep/event_service…）
  lib/reports/                # CSV → MinIO
  app/controllers/            # JSON API
  app/jobs/                   # RiskSweepJob（周期扫描）、GenerateReportJob
frontend/src/pages/           # 总览/事件/库区趋势/规则/设备/审计/报表
docker-compose.yml            # timescale/redis/minio/web/worker/frontend
```

更多：[架构与数据流](docs/ARCHITECTURE.md)、[API 契约](docs/API.md)。

## 生产化待办（演示系统的有意简化）

- 未接入认证鉴权（`X-Actor` 占位），生产应接 SSO/OIDC 并由网关下发用户身份。
- `SECRET_KEY_BASE` 与 MinIO 密钥在 compose 中为演示值，部署时覆盖。
- 接入端未做按设备的 API Key/限流。
- 超温/漂移扫描为定时全库；测点量更大时建议改为接入时局部评估 + 定时复核。
