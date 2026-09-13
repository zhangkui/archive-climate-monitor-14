class Sensor < ApplicationRecord
  has_many :sensor_assignments, dependent: :restrict_with_error
  has_many :device_events, dependent: :restrict_with_error
  has_many :risk_events, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :sensor_type, inclusion: { in: %w[temp humi combi] }
  validates :status, inclusion: { in: %w[active offline replaced retired] }

  # 某时刻所在库区（按安装履历解析）
  def zone_at(time)
    assignment = sensor_assignments
      .where("valid_from <= ?", time)
      .where("valid_to IS NULL OR valid_to > ?", time)
      .order(valid_from: :desc).first
    assignment&.zone
  end

  def current_zone
    zone_at(Time.current)
  end
end
