class ZonesController < ApplicationController
  before_action :set_zone, only: [:show, :series, :history, :change_boundary, :merge]

  # GET /api/zones
  def index
    zones = Zone.includes(:material, :zone_versions).order(:code)
    render json: zones.map { |z| Serializers.zone(z) }
  end

  # GET /api/zones/:id
  def show
    versions = @zone.zone_versions.map { |v| Serializers.zone_version(v) }
    render json: Serializers.zone(@zone).merge(versions: versions)
  end

  # GET /api/zones/:id/series?hours=24&bucket=5m
  # 长周期走 TimescaleDB 连续聚合（小时桶），短周期走实时 time_bucket
  def series
    hours = (params[:hours] || 24).to_i.clamp(1, 720)
    use_hourly = hours > 72

    if use_hourly
      sql = <<~SQL
        SELECT bucket AS t,
               avg_temp_c, min_temp_c, max_temp_c,
               avg_humi_pct, min_humi_pct, max_humi_pct,
               avg_dew_point_c AS avg_dew_c, sample_count AS samples
        FROM zone_readings_hourly
        WHERE zone_id = #{@zone.id.to_i}
          AND bucket > now() - INTERVAL '#{hours.to_i} hours'
        ORDER BY bucket
      SQL
    else
      sql = <<~SQL
        SELECT time_bucket(INTERVAL '5 minutes', observed_at) AS t,
               AVG(temp_c)      AS avg_temp_c,
               MIN(temp_c)      AS min_temp_c,
               MAX(temp_c)      AS max_temp_c,
               AVG(humi_pct)    AS avg_humi_pct,
               MIN(humi_pct)    AS min_humi_pct,
               MAX(humi_pct)    AS max_humi_pct,
               AVG(dew_point_c) AS avg_dew_c,
               COUNT(*)         AS samples
        FROM sensor_readings
        WHERE zone_id = #{@zone.id.to_i}
          AND observed_at > now() - INTERVAL '#{hours.to_i} hours'
        GROUP BY t ORDER BY t
      SQL
    end
    rows = ActiveRecord::Base.connection.select_all(sql).to_a
    render json: rows.map { |r|
      { t: r["t"],
        temp_c: r["avg_temp_c"]&.to_f&.round(2),
        temp_min: r["min_temp_c"]&.to_f&.round(2),
        temp_max: r["max_temp_c"]&.to_f&.round(2),
        humi_pct: r["avg_humi_pct"]&.to_f&.round(2),
        humi_min: r["min_humi_pct"]&.to_f&.round(2),
        humi_max: r["max_humi_pct"]&.to_f&.round(2),
        dew_point_c: r["avg_dew_c"]&.to_f&.round(2),
        samples: r["samples"].to_i }
    }
  end

  # GET /api/zones/:id/history —— 边界版本与设备履历
  def history
    assignments = SensorAssignment.where(zone_id: @zone.id)
      .includes(:sensor).order(:valid_from)
    render json: {
      zone: Serializers.zone(@zone),
      versions: @zone.zone_versions.map { |v| Serializers.zone_version(v) },
      assignments: assignments.map { |a|
        { sensor_code: a.sensor.code, sensor_name: a.sensor.name,
          location_desc: a.location_desc,
          valid_from: a.valid_from.iso8601,
          valid_to: a.valid_to&.iso8601 }
      }
    }
  end

  # POST /api/zones/:id/boundary —— 登记边界变更
  # body: { boundary: {...}, reason: "...", moved_sensor_codes: [["S1","Z-2"]] }
  def change_boundary
    moved = Array(params[:moved_sensor_codes]).map do |pair|
      sensor = Sensor.find_by!(code: pair.first)
      target = Zone.find_by!(code: pair.last)
      [sensor, target]
    end

    result = Risk::ZoneService.change_boundary!(
      zone: @zone, boundary: param_hash(:boundary),
      changed_by: actor_name, reason: params.require(:reason),
      moved_sensors: moved
    )
    render json: { version: Serializers.zone_version(result[:version]),
                   moved: result[:moved] }, status: :created
  end

  # POST /api/zones/:id/merge  body: { target_zone_id: 12, reason: "..." }
  def merge
    target = Zone.find(params.require(:target_zone_id))
    result = Risk::ZoneService.merge!(
      source_zone: @zone, target_zone: target,
      changed_by: actor_name, reason: params.require(:reason)
    )
    render json: { merged: true, version: result[:version].version },
           status: :created
  end

  private

  def set_zone
    @zone = Zone.find(params[:id])
  end
end
