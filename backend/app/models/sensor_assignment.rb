class SensorAssignment < ApplicationRecord
  belongs_to :sensor
  belongs_to :zone

  validates :valid_from, presence: true

  scope :active_at, ->(time) {
    where("valid_from <= ? AND (valid_to IS NULL OR valid_to > ?)", time, time)
  }
end
