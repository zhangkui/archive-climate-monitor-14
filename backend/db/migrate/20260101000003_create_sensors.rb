class CreateSensors < ActiveRecord::Migration[8.0]
  def change
    create_table :sensors do |t|
      t.string :code, null: false
      t.string :name, null: false
      # temp / humi / combi（温湿度一体）
      t.string :sensor_type, null: false
      t.string :manufacturer
      t.string :model
      t.string :firmware_version
      # active / offline / replaced / retired
      t.string :status, null: false, default: "active"
      t.date :commissioned_on
      t.timestamps
    end
    add_index :sensors, :code, unique: true
    add_index :sensors, :status

    # 传感器在库区上的安装履历：边界调整/设备移位时结束旧行、开启新行
    create_table :sensor_assignments do |t|
      t.references :sensor, null: false, foreign_key: true
      t.references :zone, null: false, foreign_key: true
      t.string :location_desc
      t.timestamptz :valid_from, null: false
      t.timestamptz :valid_to
      t.timestamps
    end
    add_index :sensor_assignments, [:sensor_id, :valid_from]
    add_index :sensor_assignments, [:zone_id, :valid_from]
    add_index :sensor_assignments, :valid_to

    create_table :device_events do |t|
      t.references :sensor, null: false, foreign_key: true
      # online / offline / battery_low / fault / calibration / replaced
      t.string :event_kind, null: false
      t.timestamptz :occurred_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.text :note
      t.timestamps
    end
    add_index :device_events, [:sensor_id, :occurred_at]
    add_index :device_events, :event_kind
  end
end
