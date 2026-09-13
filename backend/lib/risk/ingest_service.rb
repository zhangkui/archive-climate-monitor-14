module Risk
  # 设备遥测接入：校验、归属快照、露点补算、批量写入 hypertable。
  # 入库时把 zone_id 解析并冻结到每行，之后边界变更不影响历史行。
  class IngestService
    Result = Struct.new(:accepted, :rejected, :errors, keyword_init: true)

    # payload:
    # { sensor_code: "S-T01", readings: [
    #     { observed_at: "2026-09-12T08:00:00+08:00",
    #       temp_c: 22.1, humi_pct: 55.2, battery_pct: 88 } ] }
    def self.ingest!(payload)
      new.ingest!(payload)
    end

    def ingest!(payload)
      sensor = Sensor.find_by!(code: payload.fetch(:sensor_code))
      readings = Array(payload[:readings])
      raise ArgumentError, "readings 不能为空" if readings.empty?

      rows = []
      errors = []

      readings.each do |r|
        observed_at = Time.iso8601(r[:observed_at].to_s)
        zone = sensor.zone_at(observed_at)
        unless zone
          errors << { observed_at: r[:observed_at], error: "该时刻无有效库区归属" }
          next
        end

        temp = r[:temp_c]&.to_f
        humi = r[:humi_pct]&.to_f
        dew = r[:dew_point_c]&.to_f || DewPoint.calc(temp, humi)

        quality, qmsg = quality_check(temp, humi, r[:battery_pct]&.to_f)
        errors << { observed_at: r[:observed_at], error: qmsg } if qmsg

        rows << {
          observed_at: observed_at, sensor_id: sensor.id, zone_id: zone.id,
          temp_c: temp, humi_pct: humi, dew_point_c: dew,
          battery_pct: r[:battery_pct]&.to_f, quality: quality,
          raw: r.except(:observed_at).as_json
        }
      rescue ArgumentError => e
        errors << { observed_at: r[:observed_at], error: e.message }
      end

      SensorReading.insert_all(rows) if rows.any?

      Result.new(accepted: rows.size, rejected: errors.size, errors: errors)
    end

    private

    def quality_check(temp, humi, battery)
      if (temp && (temp < -40 || temp > 85)) || (humi && (humi < 0 || humi > 100))
        ["bad", "量程外数据，标记 bad"]
      elsif battery && battery < 10
        ["suspect", "电量低于 10%，数据存疑"]
      else
        ["good", nil]
      end
    end
  end
end
