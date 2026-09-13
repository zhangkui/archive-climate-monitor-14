# 测点遥测：TimescaleDB hypertable。
# 注意：hypertable 不建外键约束，归属关系由应用层保证；
# zone_id 在入库时做快照，边界变更不回改历史数据。
class CreateSensorReadings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    create_table :sensor_readings, id: false, if_not_exists: true do |t|
      t.timestamptz :observed_at, null: false
      t.bigint :sensor_id, null: false
      t.bigint :zone_id, null: false
      t.decimal :temp_c, precision: 6, scale: 2
      t.decimal :humi_pct, precision: 6, scale: 2
      t.decimal :dew_point_c, precision: 6, scale: 2
      t.decimal :battery_pct, precision: 5, scale: 2
      # good / suspect / bad
      t.string :quality, null: false, default: "good"
      t.jsonb :raw, null: false, default: {}
    end

    execute <<~SQL
      SELECT create_hypertable(
        'sensor_readings', 'observed_at',
        chunk_time_interval => INTERVAL '7 days',
        if_not_exists => TRUE
      );
    SQL

    add_index :sensor_readings, [:sensor_id, :observed_at],
              name: "index_readings_on_sensor_time", if_not_exists: true
    add_index :sensor_readings, [:zone_id, :observed_at],
              name: "index_readings_on_zone_time", if_not_exists: true
    add_index :sensor_readings, :quality, if_not_exists: true

    execute <<~SQL
      ALTER TABLE sensor_readings SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'sensor_id,zone_id',
        timescaledb.compress_orderby = 'observed_at DESC'
      );
    SQL

    # 30 天前的块自动压缩
    execute <<~SQL
      SELECT add_compression_policy('sensor_readings', INTERVAL '30 days', if_not_exists => TRUE);
    SQL
  end

  def down
    execute "SELECT remove_compression_policy('sensor_readings', if_exists => TRUE)"
    drop_table :sensor_readings
  end
end
