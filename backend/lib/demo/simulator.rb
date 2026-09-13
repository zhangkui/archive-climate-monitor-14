module Demo
  # 演示用实时模拟器：每个 active 传感器按库区材质目标随机游走产出一点。
  # 用法（容器内）：bundle exec rails risk:simulate INTERVAL=60
  class Simulator
    TARGETS = {
      "PAPER" => { temp: 20.0, humi: 53.0 },
      "PHOTO" => { temp: 17.0, humi: 35.0 },
      "SILK"  => { temp: 19.5, humi: 52.0 }
    }.freeze

    def initialize
      @rng = Random.new
    end

    def tick!(at: Time.current)
      accepted = 0
      Sensor.where(status: "active").find_each do |sensor|
        zone = sensor.zone_at(at)
        next unless zone

        target = TARGETS.fetch(zone.material.code, TARGETS["PAPER"])
        temp = target[:temp] + ((@rng.rand - 0.5) * 0.6)
        humi = target[:humi] + ((@rng.rand - 0.5) * 2.0)
        payload = {
          sensor_code: sensor.code,
          readings: [{
            observed_at: at.iso8601,
            temp_c: temp.round(2),
            humi_pct: sensor.sensor_type == "temp" ? nil : humi.round(2),
            battery_pct: (80 + @rng.rand * 19).round(1)
          }]
        }
        result = Risk::IngestService.ingest!(payload)
        accepted += result.accepted
      end
      accepted
    end
  end
end
