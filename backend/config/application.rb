require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module ArchiveVault
  class Application < Rails::Application
    config.load_defaults 8.0

    config.api_only = true
    config.eager_load = true

    config.time_zone = "Asia/Shanghai"

    config.active_record.schema_format = :sql

    # 不使用 credentials/master.key，统一由环境变量注入
    config.secret_key_base = ENV["SECRET_KEY_BASE"] || (SecureRandom.hex(32) if Rails.env.development?)

    config.autoload_lib(ignore: %w[assets tasks generators templates])

    config.active_job.queue_adapter = :sidekiq

    config.generators do |g|
      g.orm :active_record, primary_key_type: :bigint
      g.test_framework false
      g.jbuilder false
      g.helper false
      g.stylesheets false
      g.javascripts false
    end
  end
end
