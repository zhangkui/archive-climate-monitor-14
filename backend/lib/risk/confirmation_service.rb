module Risk
  # 异常确认/误报/处置工作流。状态流转字段可更新，结论字段保持冻结。
  class ConfirmationService
    TRANSITIONS = {
      "open" => %w[confirmed dismissed false_positive resolved],
      "confirmed" => %w[resolved false_positive]
    }.freeze

    def self.confirm!(event:, actor_name:, outcome:, note: nil, at: Time.current)
      new(event).call(actor_name:, outcome:, note:, at:)
    end

    def initialize(event)
      @event = event
    end

    def call(actor_name:, outcome:, note:, at:)
      unless TRANSITIONS.fetch(@event.status, []).include?(outcome)
        raise ZoneService::Error,
              "非法状态流转：#{@event.status} → #{outcome}"
      end

      before = @event.attributes.slice("status", "confirmed_by")

      @event.update!(
        status: outcome,
        confirmed_at: at,
        confirmed_by: actor_name,
        ended_at: %w[resolved false_positive dismissed].include?(outcome) ?
                    (@event.ended_at || at) : @event.ended_at,
        resolution: outcome == "resolved" ? "manual" : @event.resolution,
        resolution_note: note || @event.resolution_note
      )

      Risk.audit!(
        category: "anomaly_confirmation",
        action: outcome,
        actor_name: actor_name,
        auditable: @event,
        before_data: before,
        after_data: { status: outcome, note: note },
        note: "事件 ##{@event.id} (#{@event.event_type}) 处置为 #{outcome}"
      )

      @event
    end
  end
end
