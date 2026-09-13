class RiskEvent < ApplicationRecord
  belongs_to :sensor, optional: true
  belongs_to :zone
  # boundary_transition 非规则推导，允许为空
  belongs_to :risk_rule, optional: true

  TYPES = %w[sustained_threshold drift missing boundary_transition].freeze
  SEVERITIES = %w[info warning critical].freeze
  STATUSES = %w[open confirmed resolved dismissed false_positive].freeze

  validates :event_type, inclusion: { in: TYPES }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, :detected_at, :dedup_key, presence: true

  scope :openish, -> { where(status: %w[open confirmed]) }

  def open?
    %w[open confirmed].include?(status)
  end
end
