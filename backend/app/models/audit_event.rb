class AuditEvent < ApplicationRecord
  CATEGORIES = %w[anomaly_confirmation rule_change device_replacement zone_change system].freeze

  validates :category, inclusion: { in: CATEGORIES }
  validates :action, :occurred_at, presence: true

  # 数据库触发器禁止 UPDATE/DELETE；模型层同样设防
  def readonly?
    persisted?
  end
end
