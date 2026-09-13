class Report < ApplicationRecord
  belongs_to :zone, optional: true

  KINDS = %w[zone_risk event_export].freeze
  STATUSES = %w[pending running done failed].freeze
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
end
