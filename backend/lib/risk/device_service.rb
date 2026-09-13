module Risk
  # 设备替换：旧设备下线并留痕，同点位新设备建档、延续安装履历；
  # 旧设备未结的漂移/缺测事件以 device_replaced 收口，全程写审计。
  class DeviceService
    def self.replace!(old_sensor:, new_attributes:, zone: nil,
                      actor_name:, note:, at: Time.current)
      new(old_sensor).replace!(
        new_attributes:, zone:, actor_name:, note:, at:
      )
    end

    def initialize(old_sensor)
      @old = old_sensor
    end

    def replace!(new_attributes:, zone:, actor_name:, note:, at:)
      ApplicationRecord.transaction do
        target_zone = zone || @old.zone_at(at)
        raise ZoneService::Error, "无法确定新设备所属库区" unless target_zone

        old_before = @old.attributes.slice(
          "code", "name", "status", "sensor_type", "model"
        )

        DeviceEvent.create!(
          sensor: @old, event_kind: "replaced", occurred_at: at,
          note: note,
          payload: { actor: actor_name }
        )
        @old.update!(status: "replaced")

        current = @old.sensor_assignments.active_at(at).first
        current&.update!(valid_to: at)

        new_sensor = Sensor.create!(new_attributes.merge(
          status: "active", commissioned_on: at.to_date
        ))
        SensorAssignment.create!(
          sensor: new_sensor, zone: target_zone,
          location_desc: current&.location_desc, valid_from: at
        )
        DeviceEvent.create!(
          sensor: new_sensor, event_kind: "online", occurred_at: at,
          note: "替换 #{@old.code} 后上线", payload: { replaces: @old.code }
        )

        # 旧设备未结的漂移/缺测随替换收口；超阈值类不自动关闭，
        # 因为环境本身可能仍然超标，需由新设备继续监测/人工确认
        RiskEvent.openish.where(sensor_id: @old.id,
                                event_type: %w[drift missing]).find_each do |ev|
          ev.update!(status: "resolved", ended_at: at,
                     resolution: "device_replaced",
                     resolution_note: "由 #{new_sensor.code} 替换：#{note}")
        end

        Risk.audit!(
          category: "device_replacement", action: "replace",
          actor_name: actor_name, auditable: @old,
          before_data: old_before,
          after_data: { new_sensor_id: new_sensor.id,
                        new_sensor_code: new_sensor.code,
                        zone_id: target_zone.id, note: note },
          note: "#{@old.code} → #{new_sensor.code}"
        )

        new_sensor
      end
    end
  end
end
