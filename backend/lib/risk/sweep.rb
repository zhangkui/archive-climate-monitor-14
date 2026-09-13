module Risk
  # 定时全库扫描：按库区解析当前生效规则版本，逐区评估。
  # 由 Sidekiq 的 RiskSweepJob 周期触发；也可在控制台手动 Sweep.run!。
  class Sweep
    Result = Struct.new(:zones_scanned, :created, :updated, :resolved,
                        keyword_init: true) do
      def to_h
        { zones_scanned: zones_scanned, created: created, updated: updated,
          resolved: resolved }
      end
    end

    def self.run!(now: Time.current)
      new(now:).run!
    end

    def initialize(now: Time.current)
      @now = now
    end

    def run!
      totals = { zones_scanned: 0, created: 0, updated: 0, resolved: 0 }

      Zone.where(status: "active").includes(:material).find_each do |zone|
        rule = RiskRule.for_material(zone.material_id, @now)
        unless rule
          Rails.logger.warn("[risk] 库区 #{zone.code} 无生效规则，跳过")
          next
        end

        evaluator = Evaluator.new(zone:, rule:, now: @now)
        evaluator.evaluate!
        totals[:zones_scanned] += 1
        totals[:created] += evaluator.totals[:created]
        totals[:updated] += evaluator.totals[:updated]
        totals[:resolved] += evaluator.totals[:resolved]
      end

      Result.new(**totals)
    end
  end
end
