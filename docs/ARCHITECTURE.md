# 架构与数据流

## 组件拓扑

```
          传感器/网关                  浏览器 React 19
              │ POST /api/ingest          │
              ▼                           ▼
     ┌───────────────────── Rails 8 (Puma, web) ────────────────────┐
     │ IngestService → 归属快照(sensor_assignments) → 露点补算        │
     │ Controllers: dashboard / zones / events / rules / sensors /   │
     │              audit / reports                                  │
     └───────┬───────────────────────────┬───────────────┬──────────┘
             │                           │               │
             ▼                           ▼               ▼
   TimescaleDB 2.15 (PG16)         Redis 7          MinIO (S3 API)
   sensor_readings(hypertable)      队列/锁           CSV 报表桶
   压缩策略 + 连续聚合               ▲
   risk_rules/risk_events/audit     │
             ▲                       │
             │ 周期 RiskSweepJob     │
     ┌───────┴──────── Sidekiq (worker) ───────────┐
     │ Risk::Sweep → Evaluator（每库区、按版本规则） │
     │ GenerateReportJob → CSV → MinIO             │
     └──────────────────────────────────────────────┘

前端 nginx 容器把 /api/* 反代到 web:3000
```

## 时间履历模型（SCD-2 风格）

- `sensor_assignments(valid_from, valid_to)` 表达「某传感器在某库区」的
  时间段。边界调整/设备移位 = 结束旧行 + 开启新行，从不删除。
- `zone_versions(version, effective_at, boundary jsonb)` 追加保存每一次
  边界/合并/改名。`Zone#version_at(time)` 可解析任意时刻的边界快照。
- 测点写入时 `IngestService` 解析该时刻归属并把 `zone_id` **冻结到行内**。
  边界变更后历史测点的 `zone_id` 不回改；归属迁移本身由
  `boundary_transition` 事件留痕。

## 规则版本化

- `risk_rules` 每行是一个不可变版本（阈值 `thresholds` + 检测参数
  `detectors` 整体快照），状态机 `draft → active → superseded`。
- 激活新版本时，同适用对象（材质专属或默认）的旧版本在同一事务内批量
  superseded，并写 `rule_change` 审计。
- 规则按时间点解析：`RiskRule.active_at(at)` + `for_material(material, at)`，
  回扫历史时段时使用当时生效的版本。
- `risk_events` 引用 `risk_rule_id/version`，证据 jsonb 内再冗余阈值快照；
  即使规则行将来被删除（当前限制删除），事件仍自解释。

## 事件生命周期与去重

```
检测 → Finding → EventService.persist!
  dedup_key = 类型:库区:传感器:指标:起始时刻(epoch)
  ├─ key 命中且未结 → 更新进展字段（peak/latest/ended_at）
  ├─ key 未命中但存在同传感器+指标的未结事件（滚动窗口锚点移动）→ 更新该事件
  └─ 否则 → 新建事件（冻结结论字段）
恢复 → open 事件 resolved(auto_recovered)
人工 → ConfirmationService: open/confirmed → confirmed|resolved|
                                             dismissed|false_positive
```

结论字段（类型/级别/规则版本/起始时刻/指标/归属/证据/dedup_key）由 PG 触发器
禁止更新；状态与处置字段正常流转。

## TimescaleDB 用法

| 对象 | 作用 |
|---|---|
| `sensor_readings` hypertable（7 天 chunk） | 高频测点只追加写入 |
| 压缩策略（30 天） | segmentby `sensor_id,zone_id`，orderby `observed_at DESC` |
| `zone_readings_hourly` 连续聚合 + 15 分钟刷新策略 | 长周期趋势（>72h）查询 |
| `time_bucket` 实时聚合 | 短周期（5 分钟桶）趋势与看板 |

## 调度与并发

- Sidekiq 启动钩子安装进程内定时器（`Risk::Scheduler`，周期
  `RISK_SWEEP_INTERVAL`，默认 300s）。
- `RiskSweepJob` 用 Redis `SET NX PX` + token 校验释放，防止多实例/重叠扫描。
- 迁移与种子仅由 `AV_ROLE=web` 的入口执行，worker 不重复迁移。
- 报表异步生成（`reports` 队列），MinIO 预签名 URL 15 分钟有效；
  预签名使用 `MINIO_PUBLIC_ENDPOINT`（宿主机可达地址），上传使用内部
  `MINIO_ENDPOINT`。
