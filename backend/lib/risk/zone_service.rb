module Risk
  # 库区边界/合并变更的事务化处理：
  # 1. 追加不可变 zone_version；
  # 2. 结束受影响传感器的旧安装履历、按需要开启新库区履历；
  # 3. 为每个受影响传感器生成 boundary_transition 事件（审计可追溯）；
  # 4. 历史测点的 zone_id 快照保持不变——不回改、不重算。
  class ZoneService
    Error = Class.new(StandardError)

    def self.change_boundary!(zone:, boundary:, changed_by:, reason:,
                              moved_sensors: [], effective_at: Time.current)
      new(zone).change_boundary!(
        boundary:, changed_by:, reason:, moved_sensors:, effective_at:
      )
    end

    def self.merge!(source_zone:, target_zone:, changed_by:, reason:,
                    effective_at: Time.current)
      new(source_zone).merge_into!(
        target_zone, changed_by:, reason:, effective_at:
      )
    end

    def initialize(zone)
      @zone = zone
    end

    def change_boundary!(boundary:, changed_by:, reason:, moved_sensors:, effective_at:)
      ApplicationRecord.transaction do
        version = append_version!(
          change_type: "boundary", boundary: boundary,
          changed_by: changed_by, reason: reason, effective_at: effective_at
        )

        moved = Array(moved_sensors).map do |item|
          sensor, new_zone = item
          reassign!(sensor, new_zone, effective_at, reason)
        end

        Risk.audit!(
          category: "zone_change", action: "boundary_change",
          actor_name: changed_by, auditable: @zone,
          after_data: {
            version: version.version, boundary: boundary,
            moved_sensor_ids: moved.map { |m| m[:sensor_id] },
            target_zone_ids: moved.map { |m| m[:to_zone_id] }
          },
          note: reason
        )

        { version: version, moved: moved }
      end
    end

    def merge_into!(target_zone, changed_by:, reason:, effective_at:)
      raise Error, "目标库区不可用" unless target_zone.status == "active"

      ApplicationRecord.transaction do
        boundary = target_zone.current_version&.boundary || {}

        version = append_version!(
          change_type: "merge", boundary: boundary,
          related_zone: target_zone, changed_by: changed_by,
          reason: reason, effective_at: effective_at
        )

        moved = @zone.sensor_assignments.active_at(effective_at).map do |asn|
          reassign!(asn.sensor, target_zone, effective_at, reason)
        end

        @zone.update!(status: "merged")

        Risk.audit!(
          category: "zone_change", action: "merge",
          actor_name: changed_by, auditable: @zone,
          after_data: { merged_into_zone_id: target_zone.id,
                        version: version.version,
                        moved_sensor_ids: moved.map { |m| m[:sensor_id] } },
          note: reason
        )

        { version: version, moved: moved }
      end
    end

    private

    def append_version!(change_type:, boundary:, changed_by:, reason:,
                        effective_at:, related_zone: nil)
      last_no = @zone.zone_versions.maximum(:version) || 0
      ZoneVersion.create!(
        zone: @zone,
        version: last_no + 1,
        change_type: change_type,
        boundary: boundary || {},
        related_zone: related_zone,
        changed_by: changed_by,
        change_reason: reason,
        effective_at: effective_at
      )
    end

    def reassign!(sensor, new_zone, at, reason)
      current = SensorAssignment
        .where(sensor_id: sensor.id)
        .where("valid_from <= ? AND (valid_to IS NULL OR valid_to > ?)", at, at)
        .order(valid_from: :desc).first

      raise Error, "传感器 #{sensor.code} 当前无有效安装履历" unless current

      from_zone = current.zone

      if new_zone && new_zone.id != from_zone.id
        current.update!(valid_to: at)
        SensorAssignment.create!(
          sensor: sensor, zone: new_zone,
          location_desc: current.location_desc,
          valid_from: at
        )
        record_transition!(sensor, from_zone, new_zone, at, reason)
      end

      { sensor_id: sensor.id, from_zone_id: from_zone.id,
        to_zone_id: new_zone&.id }
    end

    def record_transition!(sensor, from_zone, to_zone, at, reason)
      finding = EventService::Finding.new(
        event_type: "boundary_transition", severity: "info",
        zone_id: to_zone.id, sensor_id: sensor.id, rule: nil,
        metric: "zone_assignment",
        started_at: at, ended_at: at,
        peak_value: nil, latest_value: nil, latest_seen_at: at,
        evidence: {
          "from_zone_id" => from_zone.id, "from_zone_code" => from_zone.code,
          "to_zone_id" => to_zone.id, "to_zone_code" => to_zone.code,
          "effective_at" => at.utc.iso8601,
          "reason" => reason
        }
      )
      EventService.new.persist!(finding)
    end
  end
end
