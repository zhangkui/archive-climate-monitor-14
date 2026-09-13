class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from ArgumentError, with: :bad_request
  rescue_from Risk::ZoneService::Error, with: :conflict

  private

  # 演示系统未接统一认证，操作员身份由 X-Actor 头或 actor_name 参数传递
  def actor_name
    request.headers["X-Actor"].presence || params[:actor_name].presence || "system"
  end

  def not_found(e)
    render json: { error: "not_found", message: e.message }, status: :not_found
  end

  def unprocessable(e)
    render json: { error: "validation_failed",
                   message: e.record.errors.full_messages.join("; ") },
           status: :unprocessable_entity
  end

  def bad_request(e)
    render json: { error: "bad_request", message: e.message }, status: :bad_request
  end

  def conflict(e)
    render json: { error: "conflict", message: e.message }, status: :conflict
  end

  # 取 JSON 对象参数；缺省/为 nil 时返回空 Hash
  def param_hash(key)
    v = params[key]
    v.respond_to?(:to_unsafe_h) ? v.to_unsafe_h : (v.is_a?(Hash) ? v : {})
  end
end
