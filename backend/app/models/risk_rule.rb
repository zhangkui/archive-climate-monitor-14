class RiskRule < ApplicationRecord
  belongs_to :material, optional: true

  validates :version, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, inclusion: { in: %w[draft active superseded] }
  validate :thresholds_shape

  scope :active, -> { where(status: "active") }

  # 按时间点解析当时生效的规则（依据激活/取代时间，而非当前 status），
  # 使“回扫历史”得到的事件引用当时的规则版本。
  def self.active_at(at)
    where("activated_at <= :at AND (superseded_at IS NULL OR superseded_at > :at)",
          at: at)
  end

  # 按材质解析生效规则：材质专属 → 默认规则
  def self.for_material(material_id, at = Time.current)
    active_at(at).where(material_id: material_id).order(activated_at: :desc).first ||
      active_at(at).where(is_default: true).order(activated_at: :desc).first
  end

  # 供风险引擎直接读取的带类型访问
  def spec
    @spec ||= Risk::RuleSpec.new(thresholds, detectors)
  end

  def thresholds_shape
    return if thresholds.is_a?(Hash)
    errors.add(:thresholds, "must be an object")
  end

  # 激活新版本：在事务内将既有生效规则整体置为 superseded
  def activate!(actor:)
    RiskRule.transaction do
      RiskRule.active.where(
        "material_id IS NOT DISTINCT FROM ?", material_id
      ).where.not(id: id).find_each do |other|
        other.update!(status: "superseded", superseded_at: Time.current)
      end
      update!(status: "active", activated_at: Time.current)
      Risk.audit!(
        category: "rule_change",
        action: "activate",
        actor_name: actor,
        auditable: self,
        after_data: snapshot,
        note: "规则 v#{version}《#{name}》激活"
      )
    end
  end

  def snapshot
    {
      version: version, name: name, material_id: material_id,
      is_default: is_default, thresholds: thresholds, detectors: detectors
    }
  end
end
