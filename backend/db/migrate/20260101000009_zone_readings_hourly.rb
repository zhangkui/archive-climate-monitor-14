# 连续聚合：库区小时级温湿度统计，供趋势图与回扫使用
class ZoneReadingsHourlyAggregate < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS zone_readings_hourly
      WITH (timescaledb.continuous) AS
      SELECT
        time_bucket(INTERVAL '1 hour', observed_at) AS bucket,
        zone_id,
        avg(temp_c)      AS avg_temp_c,
        min(temp_c)      AS min_temp_c,
        max(temp_c)      AS max_temp_c,
        avg(humi_pct)    AS avg_humi_pct,
        min(humi_pct)    AS min_humi_pct,
        max(humi_pct)    AS max_humi_pct,
        avg(dew_point_c) AS avg_dew_point_c,
        count(*)         AS sample_count
      FROM sensor_readings
      GROUP BY bucket, zone_id
      WITH NO DATA;
    SQL

    execute <<~SQL
      SELECT add_continuous_aggregate_policy('zone_readings_hourly',
        start_offset      => INTERVAL '7 days',
        end_offset        => INTERVAL '1 hour',
        schedule_interval => INTERVAL '15 minutes',
        if_not_exists     => TRUE);
    SQL
  end

  def down
    execute "SELECT remove_continuous_aggregate_policy('zone_readings_hourly', if_exists => TRUE)"
    execute "DROP MATERIALIZED VIEW IF EXISTS zone_readings_hourly"
  end
end
