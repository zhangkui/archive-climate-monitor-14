module Risk
  # 审计流水唯一入口。audit_events 由数据库触发器保证只追加。
  module Audit
    module_function

    def log!(category:, action:, actor_name: nil, auditable: nil,
            before_data: {}, after_data: {}, note: nil, request_id: nil,
            occurred_at: Time.current)
      AuditEvent.create!(
        category: category,
        action: action,
        actor_name: actor_name,
        auditable_type: auditable&.class&.name,
        auditable_id: auditable&.id,
        before_data: before_data || {},
        after_data: after_data || {},
        note: note,
        request_id: request_id,
        occurred_at: occurred_at
      )
    end
  end

  # 顶层便捷方法
  def self.audit!(...) = Audit.log!(...)
end
