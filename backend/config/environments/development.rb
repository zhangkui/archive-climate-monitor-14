require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.cache_classes = false

  config.active_record.migration_error = :page_load
  config.logger = ActiveSupport::Logger.new($stdout)
end
