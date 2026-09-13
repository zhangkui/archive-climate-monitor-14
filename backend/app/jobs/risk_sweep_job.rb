class RiskSweepJob < ApplicationJob
  queue_as :risk

  LOCK_KEY = "risk:sweep-lock"
  LOCK_TTL_MS = 60_000

  # 防止调度重叠：同一时刻只跑一轮全库扫描
  def perform
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    token = SecureRandom.hex(8)

    unless redis.call("SET", LOCK_KEY, token, "NX", "PX", LOCK_TTL_MS)
      Rails.logger.info("[risk-sweep] 上一轮尚未结束，跳过")
      return
    end

    begin
      result = Risk::Sweep.run!
      Rails.logger.info("[risk-sweep] #{result.to_h}")
    ensure
      release_lock(redis, token)
      redis.close
    end
  end

  private

  # 仅在 token 仍是自己时释放，避免误删他人锁
  def release_lock(redis, token)
    redis.eval(
      "if redis.call('get', KEYS[1]) == ARGV[1] then " \
      "return redis.call('del', KEYS[1]) else return 0 end",
      keys: [LOCK_KEY], argv: [token]
    )
  end
end
