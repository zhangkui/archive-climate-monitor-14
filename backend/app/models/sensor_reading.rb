# 只读语义的测点模型。sensor_readings 是 hypertable，无主键、无外键，
# 因此不使用 updated_at/timestamps，归属关系由写入路径保证。
class SensorReading < ApplicationRecord
  self.primary_key = nil
  belongs_to :sensor
  belongs_to :zone

  validates :observed_at, presence: true

  scope :for_sensor, ->(sensor) { where(sensor_id: sensor) }
  scope :between, ->(from, to) { where(observed_at: from..to) }

  # hypertable 不支持更新/删除单条（压缩块），统一只追加
  def readonly?
    persisted?
  end
end
