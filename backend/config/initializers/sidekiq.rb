require "sidekiq"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.on(:startup) do
    # lib 由 Zeitwerk 自动加载，无需 require
    Risk::Scheduler.install!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
