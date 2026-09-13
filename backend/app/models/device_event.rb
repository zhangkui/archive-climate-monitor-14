class DeviceEvent < ApplicationRecord
  belongs_to :sensor

  KINDS = %w[online offline battery_low fault calibration replaced].freeze
  validates :event_kind, inclusion: { in: KINDS }
  validates :occurred_at, presence: true
end
