class ZoneVersion < ApplicationRecord
  belongs_to :zone
  belongs_to :related_zone, class_name: "Zone", optional: true

  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :change_type, inclusion: {
    in: %w[created boundary merge rename close]
  }
  validates :effective_at, presence: true

  def immutable?
    true
  end
end
