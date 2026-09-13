class Zone < ApplicationRecord
  belongs_to :material
  has_many :zone_versions, -> { order(:version) }, dependent: :restrict_with_error
  has_many :sensor_assignments, dependent: :restrict_with_error
  has_many :risk_events, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, inclusion: { in: %w[active merged closed] }

  # 按时间点解析边界快照；不传时间则取当前版本
  def version_at(time = Time.current)
    zone_versions.where("effective_at <= ?", time).order(version: :desc).first ||
      zone_versions.order(:version).first
  end

  def current_version
    version_at
  end
end
