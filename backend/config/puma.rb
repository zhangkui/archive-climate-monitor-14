threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
threads threads_count, threads_count
port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "production")
workers ENV.fetch("WEB_CONCURRENCY", 2).to_i
preload_app!
plugin :tmp_restart
