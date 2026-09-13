class DashboardController < ApplicationController
  # GET /api/dashboard —— 看板总览：库区卡片、当前测点、未结事件
  def index
    zones = Zone.where(status: "active").includes(:material).order(:code)
    latest = latest_readings
    open_events = RiskEvent.openish.includes(:zone, :sensor, :risk_rule)
                           .order(:severity, started_at: :desc).to_a

    render json: {
      generated_at: Time.current.iso8601,
      summary: {
        zones_total: zones.size,
        sensors_total: Sensor.where(status: "active").count,
        sensors_offline: Sensor.where(status: "offline").count,
        open_events: open_events.size,
        critical: open_events.count { |e| e.severity == "critical" },
        warning: open_events.count { |e| e.severity == "warning" }
      },
      zones: zones.map { |z| zone_card(z, latest[z.id]) },
      open_events: open_events.map { |e| Serializers.event(e) }
    }
  end

  private

  # 每库区最近一个 5 分钟桶的均值（避免不同传感器秒级不对齐）
  def latest_readings
    sql = <<~SQL
      WITH buckets AS (
        SELECT zone_id,
               time_bucket(INTERVAL '5 minutes', observed_at) AS bucket,
               AVG(temp_c)      AS avg_temp_c,
               AVG(humi_pct)    AS avg_humi_pct,
               AVG(dew_point_c) AS avg_dew_c,
               COUNT(*)         AS samples
        FROM sensor_readings
        WHERE observed_at > now() - INTERVAL '3 hours'
        GROUP BY zone_id, bucket
      ),
      ranked AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY zone_id ORDER BY bucket DESC) rn
        FROM buckets
      )
      SELECT zone_id, bucket AS observed_at, avg_temp_c, avg_humi_pct, avg_dew_c, samples
      FROM ranked WHERE rn = 1
    SQL
    ActiveRecord::Base.connection.select_all(sql).to_a.index_by { |r| r["zone_id"] }
  end

  def zone_card(zone, row)
    {
      id: zone.id, code: zone.code, name: zone.name,
      material: Serializers.material(zone.material),
      last_reading_at: row&.dig("observed_at"),
      avg_temp_c: row&.dig("avg_temp_c")&.to_f&.round(2),
      avg_humi_pct: row&.dig("avg_humi_pct")&.to_f&.round(2),
      avg_dew_point_c: row&.dig("avg_dew_c")&.to_f&.round(2),
      open_event_count: RiskEvent.openish.where(zone_id: zone.id).count
    }
  end
end
