module Risk
  # 风险事件的落库与去重。
  # dedup_key 由 (类型, 库区/传感器, 指标, 起始时刻) 构成：
  # 同一轮异常只对应一个事件行；事件结束后再出现会得到新 key → 新事件。
  class EventService
    DEDUP_BUILDER = {
      "sustained_threshold" => ->(f) {
        ["st", f.zone_id, f.sensor_id, f.metric, f.started_at.to_i].join(":")
      },
      "drift" => ->(f) {
        ["dr", f.zone_id, f.sensor_id, f.metric, f.started_at.to_i].join(":")
      },
      "missing" => ->(f) {
        ["ms", f.zone_id, f.sensor_id, f.started_at.to_i].join(":")
      },
      "boundary_transition" => ->(f) {
        ["bd", f.zone_id, f.sensor_id, f.started_at.to_i].join(":")
      }
    }.freeze

    Finding = Struct.new(
      :event_type, :severity, :zone_id, :sensor_id, :rule, :metric,
      :started_at, :ended_at, :peak_value, :latest_value, :latest_seen_at,
      :evidence, keyword_init: true
    )

    # 返回 [:created|:updated|:noop, event]
    def persist!(finding)
      key = DEDUP_BUILDER.fetch(finding.event_type).call(finding)
      # 漂移检测使用滚动窗口，起始锚点会随窗口移动；
      # key 未命中时回退到该传感器“仍在进行中”的漂移事件，避免每轮产生新行
      existing = RiskEvent.find_by(dedup_key: key) || open_fallback(finding)

      if existing
        return [:noop, existing] unless existing.open?

        # 只更新“进展”字段；结论字段被数据库触发器冻结
        direction = finding.evidence["direction"]
        new_peak =
          if direction == "low"
            [existing.peak_value.to_f, finding.peak_value.to_f].min
          else
            [existing.peak_value.to_f, finding.peak_value.to_f].max
          end
        existing.update!(
          ended_at: finding.ended_at || existing.ended_at,
          peak_value: new_peak,
          latest_value: finding.latest_value,
          latest_seen_at: finding.latest_seen_at
        )
        [:updated, existing]
      else
        # 创建时已带结束时刻（瞬时边界事件、回补的已闭合缺口）直接落为已处置
        instant_done = finding.ended_at.present?
        event = RiskEvent.create!(
          event_type: finding.event_type,
          severity: finding.severity,
          status: instant_done ? "resolved" : "open",
          zone_id: finding.zone_id,
          sensor_id: finding.sensor_id,
          risk_rule_id: finding.rule&.id,
          risk_rule_version: finding.rule&.version,
          metric: finding.metric,
          peak_value: finding.peak_value,
          latest_value: finding.latest_value,
          latest_seen_at: finding.latest_seen_at,
          started_at: finding.started_at,
          ended_at: finding.ended_at,
          detected_at: Time.current,
          resolution: instant_done ? "boundary_adjusted" : nil,
          evidence: finding.evidence.merge(
            "rule_version" => finding.rule&.version,
            "rule_thresholds" => finding.rule&.thresholds,
            "rule_detectors" => finding.rule&.detectors
          ).compact,
          dedup_key: key
        )
        [:created, event]
      end
    end

    private

    def open_fallback(finding)
      return nil if finding.event_type == "boundary_transition" || finding.sensor_id.nil?
      # 滚动窗口会移动起始锚点（漂移 24h 窗口、超温/缺测回看窗口滑出旧点后
      # 起始基准变化）。精确 key 未命中时回退到同一传感器+指标的未结事件，
      # 保证同一轮持续异常只有一个事件行
      RiskEvent.openish.find_by(
        event_type: finding.event_type,
        sensor_id: finding.sensor_id,
        zone_id: finding.zone_id,
        metric: finding.metric
      )
    end

    # 异常恢复：关闭仍在进行中的事件
    def auto_resolve!(event, resolution: "auto_recovered", note: nil, at: Time.current)
      return unless event.open?
      event.update!(
        status: "resolved",
        ended_at: event.ended_at || at,
        resolution: resolution,
        resolution_note: note
      )
      event
    end
  end

  # 引擎各检测器统一使用的待入库结构
  Finding = EventService::Finding
end
