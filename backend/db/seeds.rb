# 演示种子（幂等）：4 库区 / 3 材质 / 9 传感器 / 3 个规则版本 / 72 小时测点，
# 并内置：进行中超温、进行中缺测、24h 漂移、已确认的历史湿度事件、一次库区边界调整。
puts "==> Seeding (idempotent)..."

now = Time.current

# ---------- 材质 ----------
paper = Material.find_or_create_by!(code: "PAPER") do |m|
  m.name = "纸质文书"
  m.description = "纸张、档案盒等纤维素材质"
end
photo = Material.find_or_create_by!(code: "PHOTO") do |m|
  m.name = "影像底片"
  m.description = "黑白/彩色胶片、照片"
end
silk = Material.find_or_create_by!(code: "SILK") do |m|
  m.name = "绢本善本"
  m.description = "丝绸、绢本绘卷等特藏"
end

# ---------- 规则版本（演示“历史结论不被新版本覆盖”） ----------
unless RiskRule.exists?
  v1 = RiskRule.create!(
    version: 1, name: "全库通用微气候规则 v1", is_default: true,
    status: "superseded", activated_at: 2.years.ago, superseded_at: 24.days.ago,
    created_by: "system",
    thresholds: {
      temp: { min: 14, max: 24, critical_min: 10, critical_max: 30 },
      humi: { min: 45, max: 60, critical_min: 35, critical_max: 70 },
      dew_proximity_c: 2.0
    },
    detectors: { sustained_minutes: 30, missing_gap_minutes: 60,
                 drift_window_hours: 24, drift_slope_c_per_day: 0.8,
                 drift_peer_diff_c: 1.5, lookback_hours: 3 },
    change_summary: "建库初版：DA/T 15 常规纸质档案区间"
  )

  RiskRule.create!(
    version: 2, name: "影像底片库专属规则", material: photo,
    is_default: false, status: "active", activated_at: 200.days.ago,
    created_by: "system",
    thresholds: {
      temp: { min: 13, max: 20, critical_min: 8, critical_max: 25 },
      humi: { min: 30, max: 40, critical_min: 20, critical_max: 50 },
      dew_proximity_c: 2.0
    },
    detectors: { sustained_minutes: 30, missing_gap_minutes: 60,
                 drift_window_hours: 24, drift_slope_c_per_day: 0.6,
                 drift_peer_diff_c: 1.2, lookback_hours: 3 },
    change_summary: "胶片材质湿度收紧至 30–40%RH"
  )

  RiskRule.create!(
    version: 3, name: "全库通用微气候规则 v2", is_default: true,
    status: "active", activated_at: 24.days.ago, created_by: "张三",
    thresholds: {
      temp: { min: 14, max: 24, critical_min: 10, critical_max: 30 },
      humi: { min: 45, max: 55, critical_min: 35, critical_max: 65 },
      dew_proximity_c: 2.0
    },
    detectors: { sustained_minutes: 30, missing_gap_minutes: 60,
                 drift_window_hours: 24, drift_slope_c_per_day: 0.8,
                 drift_peer_diff_c: 1.5, lookback_hours: 3 },
    change_summary: "纸质库湿度上限由 60% 收紧到 55%RH（仅影响此后新判定）"
  )

  Risk.audit!(category: "rule_change", action: "seed",
              actor_name: "system", auditable: v1,
              after_data: { versions: [1, 2, 3] },
              note: "种子：规则版本链 v1→v2(影像)→v3(默认)")
end

# ---------- 库区 ----------
def find_or_create_zone(code, name:, material:, area:)
  Zone.find_or_create_by!(code: code) do |z|
    z.name = name
    z.material = material
    z.area_m2 = area
    z.established_at = 3.years.ago
    z.status = "active"
  end
end

za = find_or_create_zone("Z-A", name: "纸质文书一区", material: paper, area: 220)
zb = find_or_create_zone("Z-B", name: "纸质文书二区", material: paper, area: 180)
zc = find_or_create_zone("Z-C", name: "影像底片库", material: photo, area: 90)
zd = find_or_create_zone("Z-D", name: "绢本特藏库", material: silk, area: 60)

[za, zb, zc, zd].each do |z|
  next if z.zone_versions.exists?
  ZoneVersion.create!(
    zone: z, version: 1, change_type: "created",
    boundary: { floor: 1, polygon: [[0, 0], [10, 0], [10, 8], [0, 8]] },
    changed_by: "system", change_reason: "库区建档",
    effective_at: z.established_at
  )
end

# ---------- 传感器 ----------
def find_or_create_sensor(code, name:, type:, zone:, location:)
  Sensor.find_or_create_by!(code: code) do |s|
    s.name = name
    s.sensor_type = type
    s.manufacturer = "Sensirion"
    s.model = "SHT4x demo"
    s.firmware_version = "1.4.2"
    s.status = "active"
    s.commissioned_on = Date.new(2024, 3, 1)
  end.tap do |s|
    unless s.sensor_assignments.exists?
      SensorAssignment.create!(sensor: s, zone: zone,
                               location_desc: location,
                               valid_from: 2.years.ago)
    end
  end
end

sa01 = find_or_create_sensor("S-A01", name: "一区东架", type: "combi", zone: za, location: "A区东侧第3架")
sa02 = find_or_create_sensor("S-A02", name: "一区西架", type: "combi", zone: za, location: "A区西侧第1架")
sa03 = find_or_create_sensor("S-A03", name: "一区入口", type: "temp",  zone: za, location: "A区入口缓冲间")
sb01 = find_or_create_sensor("S-B01", name: "二区中架", type: "combi", zone: zb, location: "B区中央第5架")
sb02 = find_or_create_sensor("S-B02", name: "二区南窗", type: "combi", zone: zb, location: "B区南窗侧")
sc01 = find_or_create_sensor("S-C01", name: "底片库内架", type: "combi", zone: zc, location: "C区防磁柜旁")
sc02 = find_or_create_sensor("S-C02", name: "底片库门口", type: "combi", zone: zc, location: "C库入口")
sd01 = find_or_create_sensor("S-D01", name: "特藏库主测点", type: "combi", zone: zd, location: "D区中心")
sd02 = find_or_create_sensor("S-D02", name: "特藏库西墙", type: "combi", zone: zd, location: "D区西墙")

# ---------- 边界调整：36 小时前 S-D02 由特藏库划入影像底片库 ----------
boundary_at = now - 36.hours
unless RiskEvent.exists?(event_type: "boundary_transition")
  Risk::ZoneService.change_boundary!(
    zone: zd,
    boundary: { floor: 1, polygon: [[0, 2], [10, 2], [10, 8], [0, 8]],
                note: "西墙缓冲区移交影像库" },
    changed_by: "李四", reason: "西墙缓冲间与底片库合并管理",
    moved_sensors: [[sd02, zc]], effective_at: boundary_at
  )
end

# 南窗测点 3 小时前离线
unless DeviceEvent.exists?(sensor: sb02, event_kind: "offline")
  DeviceEvent.create!(
    sensor: sb02, event_kind: "offline", occurred_at: now - 3.hours,
    note: "供电模块故障，等待替换",
    payload: { battery_pct: 7 }
  )
end
sb02.update!(status: "offline")

# ---------- 72 小时测点（5 分钟一点） ----------
if SensorReading.count.zero?
  STEP = 5.minutes
  START = now - 72.hours

  targets = {
    paper.id => { temp: 20.0, humi: 53.0 },
    photo.id => { temp: 17.0, humi: 35.0 },
    silk.id  => { temp: 19.5, humi: 52.0 }
  }

  # 确定性伪随机，保证种子可重复
  rng = Random.new(42)
  noise = -> { (rng.rand - 0.5) * 0.4 }

  sensors = [sa01, sa02, sa03, sb01, sb02, sc01, sc02, sd01, sd02]
  rows = []
  t = START
  while t <= now
    sensors.each do |s|
      zone = s.zone_at(t)
      tg = targets.fetch(zone.material_id)
      age_h = (t - START) / 3600.0

      temp = tg[:temp] + noise.call
      humi = tg[:humi] + noise.call * 2

      # 单温传感器不产出湿度
      humi = nil if s.sensor_type == "temp"

      case s.code
      when "S-A02"
        # 最近 2.5 小时持续超温（warning：>24°C）
        if t >= now - 2.5.hours
          temp = 26.6 + (t - (now - 2.5.hours)) / 3600.0 * 0.4 + noise.call
        end
      when "S-A03"
        # 最近 24h 单调漂移：~0.95°C/天，且基温显著高于同伴（>1.5°C）
        temp = 23.2 + 0.95 * ((t - now) / 86_400.0)
      when "S-B02"
        # 3 小时前起彻底缺测
        next if t >= now - 3.hours
      when "S-C01"
        # 48 小时前持续约 2 小时湿度超标（影像库 warning 线 40%）
        if t.between?(now - 49.hours, now - 47.hours)
          humi = 43.8 + noise.call
        end
      end

      # 轻微昼夜节律
      temp += 0.3 * Math.sin(age_h * 2 * Math::PI / 24.0)
      dew = Risk::DewPoint.calc(temp, humi)

      rows << {
        observed_at: t, sensor_id: s.id, zone_id: zone.id,
        temp_c: temp.round(2), humi_pct: humi.round(2),
        dew_point_c: dew&.round(2), battery_pct: s.code == "S-B02" ? 7.0 : 86.0,
        quality: "good", raw: { seed: true }
      }

      if rows.size >= 1000
        SensorReading.insert_all(rows)
        rows = []
      end
    end
    t += STEP
  end
  SensorReading.insert_all(rows) if rows.any?
  puts "==> #{SensorReading.count} readings seeded"
end

# ---------- 回放历史：48h 前的湿度异常已人工确认并结案 ----------
past = now - 48.hours
unless RiskEvent.exists?(event_type: "sustained_threshold",
                        metric: "humi_pct", sensor_id: sc01.id)
  Risk::Sweep.run!(now: past)
  historical = RiskEvent.where(event_type: "sustained_threshold",
                               metric: "humi_pct", sensor_id: sc01.id,
                               status: "open").first
  if historical
    Risk::ConfirmationService.confirm!(
      event: historical, actor_name: "王五",
      outcome: "resolved", note: "临时除湿机故障，修复后恢复，纸质无霉变",
      at: past + 90.minutes
    )
  end
end

# ---------- 当前扫描：生成进行中的超温/漂移事件 ----------
# B02 已登记为离线设备（其缺测不再由扫描重复报出），
# 但数据中断发生在离线登记之前，按真实时间线预置该缺测事件，保持未结状态
default_rule = RiskRule.find_by(version: 3)
unless RiskEvent.exists?(event_type: "missing", sensor_id: sb02.id)
  stop_at = now - 3.hours
  RiskEvent.create!(
    event_type: "missing", severity: "warning", status: "open",
    zone: zb, sensor: sb02, risk_rule: default_rule, risk_rule_version: 3,
    metric: "availability",
    peak_value: 180.0, latest_value: 180.0, latest_seen_at: stop_at,
    started_at: stop_at + 300, ended_at: nil, detected_at: stop_at + 310,
    evidence: {
      "last_good_at" => stop_at.utc.iso8601,
      "gap_seconds" => 3.hours.to_i,
      "note" => "数据先中断，随后登记设备离线（供电模块故障）"
    },
    dedup_key: "ms:#{zb.id}:#{sb02.id}:#{(stop_at + 300).to_i}"
  )
end

Risk::Sweep.run!

# ---------- 更早期的历史结论：锁定 v1 规则，v3 上线后不被改写 ----------
v1 = RiskRule.find_by(version: 1)
if v1 && !RiskEvent.exists?(risk_rule_id: v1.id)
  started = 40.days.ago
  key = "st:#{za.id}:#{sa01.id}:humi_pct:#{started.to_i}"
  RiskEvent.create!(
    event_type: "sustained_threshold", severity: "warning",
    status: "resolved", zone: za, sensor: sa01, risk_rule: v1,
    risk_rule_version: 1, metric: "humi_pct",
    peak_value: 63.2, latest_value: 53.0, latest_seen_at: started + 3.hours,
    started_at: started, ended_at: started + 5.hours, detected_at: started + 35.minutes,
    confirmed_at: started + 6.hours, confirmed_by: "赵六",
    resolution: "manual",
    resolution_note: "梅雨季湿度连续超标，启动除湿机后恢复（按 v1 上限 60%RH 判定）",
    evidence: {
      "rule_version" => 1,
      "note" => "该事件依据 v1（湿度上限 60%RH）判定；v3 上限收紧为 55%RH 后本结论保持不变",
      "rule_thresholds" => v1.thresholds
    },
    dedup_key: key
  )
end

puts "==> Done. risk_events=#{RiskEvent.count} audit_events=#{AuditEvent.count}"

# 立即回填连续聚合，7 天以上粒度趋势无需等后台调度
ActiveRecord::Base.connection.execute(
  "CALL refresh_continuous_aggregate('zone_readings_hourly', NULL, NULL)"
)
puts "==> Continuous aggregate refreshed."
