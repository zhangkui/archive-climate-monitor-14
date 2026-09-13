class AuditEventsController < ApplicationController
  # GET /api/audit?category=rule_change&auditable_type=RiskRule&auditable_id=5
  def index
    scope = AuditEvent.all
    scope = scope.where(category: params[:category]) if params[:category].present?
    if params[:auditable_type].present?
      scope = scope.where(auditable_type: params[:auditable_type],
                         auditable_id: params[:auditable_id])
    end
    scope = scope.where("occurred_at >= ?", Time.iso8601(params[:from])) if params[:from].present?
    scope = scope.where("occurred_at <= ?", Time.iso8601(params[:to])) if params[:to].present?

    render json: scope.order(occurred_at: :desc).limit(300)
                      .map { |a| Serializers.audit(a) }
  end

  def show
    render json: Serializers.audit(AuditEvent.find(params[:id]))
  end
end
