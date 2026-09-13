class RiskRulesController < ApplicationController
  # GET /api/rules —— 全部版本（含历史），默认按版本倒序
  def index
    rules = RiskRule.includes(:material).order(version: :desc)
    rules = rules.where(status: params[:status]) if params[:status].present?
    render json: rules.map { |r| Serializers.rule(r) }
  end

  # GET /api/rules/:id
  def show
    render json: Serializers.rule(RiskRule.find(params[:id]))
  end

  # POST /api/rules —— 新建版本（初始为 draft）
  # body: { name:, thresholds:{...}, detectors:{...}, material_code: nil,
  #         is_default: true, change_summary: "v2 收紧湿度上限" }
  def create
    material = params[:material_code] ?
      Material.find_by!(code: params[:material_code]) : nil

    rule = nil
    RiskRule.transaction do
      version = (RiskRule.maximum(:version) || 0) + 1
      rule = RiskRule.create!(
        version: version,
        name: params.require(:name),
        material: material,
        is_default: params[:is_default].nil? ? true : ActiveModel::Type::Boolean.new.cast(params[:is_default]),
        thresholds: param_hash(:thresholds),
        detectors: param_hash(:detectors),
        change_summary: params[:change_summary],
        created_by: actor_name,
        status: "draft"
      )
      Risk.audit!(category: "rule_change", action: "create_version",
                  actor_name: actor_name, auditable: rule,
                  after_data: rule.snapshot,
                  note: "规则 v#{version} 草稿创建")
    end

    # 约定：创建即激活（也可先建草稿再 POST activate）
    rule.activate!(actor: actor_name) if ActiveModel::Type::Boolean.new.cast(params[:activate])
    render json: Serializers.rule(rule.reload), status: :created
  end

  # POST /api/rules/:id/activate
  def activate
    rule = RiskRule.find(params[:id])
    rule.activate!(actor: actor_name)
    render json: Serializers.rule(rule.reload)
  end
end
