class RiskEventsController < ApplicationController
  ALLOWED_FILTERS = %w[status event_type severity zone_id sensor_id].freeze

  # GET /api/events?status=open&event_type=...&zone_id=..&from=..&to=..
  def index
    scope = RiskEvent.includes(:zone, :sensor, :risk_rule)
    ALLOWED_FILTERS.each do |f|
      scope = scope.where(f => params[f]) if params[f].present?
    end
    scope = scope.where("started_at >= ?", Time.iso8601(params[:from])) if params[:from].present?
    scope = scope.where("started_at <= ?", Time.iso8601(params[:to])) if params[:to].present?

    render json: scope.order(started_at: :desc).limit(500).map { |e|
      Serializers.event(e)
    }
  end

  def show
    render json: Serializers.event(RiskEvent.find(params[:id]))
  end

  # POST /api/events/:id/confirm
  # body: { outcome: "confirmed|resolved|dismissed|false_positive", note: "..." }
  def confirm
    event = RiskEvent.find(params[:id])
    updated = Risk::ConfirmationService.confirm!(
      event: event, actor_name: actor_name,
      outcome: params.require(:outcome), note: params[:note]
    )
    render json: Serializers.event(updated)
  end

  # POST /api/events/:id/resolve —— 确认并处置完成的简写
  def resolve
    event = RiskEvent.find(params[:id])
    updated = Risk::ConfirmationService.confirm!(
      event: event, actor_name: actor_name,
      outcome: "resolved", note: params[:note]
    )
    render json: Serializers.event(updated)
  end
end
