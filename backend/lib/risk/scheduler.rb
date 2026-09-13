module Risk
  # Sidekiq 启动时安装周期扫描调度（进程内定时，无需额外 cron 组件）
  class Scheduler
    INTERVAL = ENV.fetch("RISK_SWEEP_INTERVAL", 300).to_i

    def self.install!
      Thread.new do
        loop do
          sleep INTERVAL
          begin
            RiskSweepJob.perform_async
          rescue => e
            Rails.logger.error("[risk-scheduler] #{e.class}: #{e.message}")
          end
        end
      end
    end
  end
end
