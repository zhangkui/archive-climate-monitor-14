module Risk
  # 对单个库区执行四类检测：连续超阈值、传感器漂移、缺测、露点逼近。
  # 边界变更在 ZoneService 中按事件驱动，不在这里轮询。
  #
  # 设计原则：
  # - 只读测点、只写风险事件；所有阈值取自版本化 RiskRule 的快照 spec；
  # - 事件只追加：同一未结异常复用 open 事件（其起始时刻被冻结），
  #   恢复后 resolve；再次发生 → 新事件行，历史结论永不被覆盖。
  class Evaluator
    WARNING = "warning"
    CRITICAL = "critical"

    attr_reader :zone, :rule, :spec, :now, :events

    def initialize(zone:, rule:, now: Time.current)
      @zone = zone
      @rule = rule
      @spec = rule.spec
      @now = now
      @events = EventService.new
      @totals = Hash.new(0)
    end

    attr_reader :totals

    def evaluate!
      window_start = now - [spec.lookback_seconds,
                            spec.sustained_seconds + 900].max
      series = load_series(window_start)

      zone.sensor_assignments.includes(:sensor).active_at(now).each do |asn|
        sensor = asn.sensor
        # replaced/retired 与历史无关；offline 的缺测已由设备状态表达，
        # 不再重复制造 missing/drift 事件
        next if %w[replaced retired offline].include?(sensor.status)

        points = series[sensor.id] || []

        detect_sustained(sensor, points)
        detect_missing(sensor, points)
        detect_drift(sensor)
      end
    end

    private

    # 一次查询取回窗口内全部测点，按传感器分组
    def load_series(from)
      rows = SensorReading
        .where(zone_id: zone.id, observed_at: from..now)
        .order(:observed_at)
        .pluck(:sensor_id, :observed_at, :temp_c, :humi_pct, :dew_point_c)
      rows.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(sid, ts, t, h, dp), acc|
        acc[sid] << { t: ts, temp: t&.to_f, humi: h&.to_f, dew: dp&.to_f }
      end
    end

    # ---------- 1. 连续超阈值 ----------
    def detect_sustained(sensor, points)
      metrics_for(sensor).each do |metric|
        violating = walk_back_violating_run(sensor, points, metric)

        if violating.any?
          duration = violating.last[:t] - violating.first[:t]
          next unless duration >= spec.sustained_seconds

          severity = violating.any? { |p| p[:sev] == CRITICAL } ? CRITICAL : WARNING
          direction = violating.last[:dir]
          peak = peak_for(metric, violating, direction)
          finding = Finding.new(
            event_type: "sustained_threshold", severity: severity,
            zone_id: zone.id, sensor_id: sensor.id, rule: rule, metric: metric,
            started_at: violating.first[:t], ended_at: nil,
            peak_value: peak, latest_value: value_for(metric, violating.last),
            latest_seen_at: violating.last[:t],
            evidence: {
              "direction" => direction,
              "samples" => violating.map { |p| sample_payload(p, metric) }.last(20),
              "sample_count" => violating.size,
              "duration_seconds" => duration.round,
              "sustained_required_seconds" => spec.sustained_seconds
            }
          )
          record(@events.persist!(finding))
        else
          resolve_open!("sustained_threshold", sensor, metric, recovery_time(points, metric))
        end
      end
    end

    def metrics_for(sensor)
      case sensor.sensor_type
      when "combi" then %w[temp_c humi_pct dew_margin_c]
      when "temp"  then %w[temp_c]
      when "humi"  then %w[humi_pct]
      else []
      end
    end

    # 从最新点向前回溯连续违规段；遇到正常点或缺测缺口即停止
    def walk_back_violating_run(sensor, points, metric)
      run = []
      points.reverse_each do |p|
        val = value_for(metric, p)
        sev, dir = classify(metric, val)
        break if sev.nil?
        if run.any? && (run.last[:t] - p[:t]) > spec.missing_gap_seconds
          break
        end
        run << p.merge(sev: sev, dir: dir, val: val)
      end
      run.reverse
    end

    def classify(metric, val)
      return [nil] if val.nil?

      case metric
      when "temp_c"
        lo, hi, clo, chi = spec.temp_bounds
        band(val, lo, hi, clo, chi)
      when "humi_pct"
        lo, hi, clo, chi = spec.humi_bounds
        band(val, lo, hi, clo, chi)
      when "dew_margin_c"
        margin_proximity(val)
      end
    end

    def margin_proximity(margin)
      return [nil] if margin.nil?
      return [nil] unless margin < spec.dew_proximity_c
      sev = margin < spec.dew_proximity_c / 2.0 ? CRITICAL : WARNING
      [sev, "low"]
    end

    # 返回 [级别, 越限方向 high/low]
    def band(val, lo, hi, clo, chi)
      return [CRITICAL, val < clo ? "low" : "high"] if val < clo || val > chi
      return [WARNING, val < lo ? "low" : "high"] if val < lo || val > hi
      [nil]
    end

    def value_for(metric, p)
      case metric
      when "temp_c" then p[:temp]
      when "humi_pct" then p[:humi]
      when "dew_margin_c"
        t = p[:dew] || DewPoint.calc(p[:temp], p[:humi])
        t && p[:temp] ? (p[:temp] - t).round(3) : nil
      end
    end

    def peak_for(metric, run, direction)
      vals = run.map { |p| p[:val] }
      return vals.min if metric == "dew_margin_c" || direction == "low"
      vals.map(&:abs).max
    end

    def sample_payload(p, metric)
      { "at" => p[:t].utc.iso8601,
        "value" => p[:val],
        "level" => p[:sev] == CRITICAL ? "critical" : "warning" }
    end

    def recovery_time(points, _metric)
      points.last&.dig(:t)
    end

    # ---------- 2. 缺测 ----------

    def detect_missing(sensor, points)
      metric = "availability"

      # 窗口内没有任何测点：以窗口前最后一个好测点作为缺口起点
      if points.empty?
        # hypertable 无主键，不能用 .first（会生成 ORDER BY 主键）
        last_good_at = SensorReading.where(sensor_id: sensor.id)
          .where("observed_at <= ?", now).order(observed_at: :desc)
          .limit(1).pick(:observed_at)
        return unless last_good_at

        gap_seconds = now - last_good_at
        return unless gap_seconds > spec.missing_gap_seconds

        finding = build_missing(sensor, last_good_at, nil,
                                gap_seconds, spec.missing_gap_seconds)
        record(events.persist!(finding))
        return
      end

      expected = expected_interval(points)
      gaps = []

      points.each_cons(2) do |a, b|
        delta = b[:t] - a[:t]
        next unless delta > spec.missing_gap_seconds
        gaps << { from: a[:t], to: b[:t], seconds: delta, open: false }
      end

      # 末尾缺口（最近一个测点距现在过久）= 进行中缺测
      if (now - points.last[:t]) > spec.missing_gap_seconds
        gaps << { from: points.last[:t], to: nil,
                  seconds: now - points.last[:t], open: true }
      end

      if gaps.any?
        gap = gaps.last
        finding = build_missing(sensor, gap[:from], gap[:to],
                                gap[:seconds], expected)
        record(events.persist!(finding))
      else
        resolve_open!("missing", sensor, metric, points.last&.dig(:t))
      end
    end

    def build_missing(sensor, gap_from, gap_to, gap_seconds, expected)
      Finding.new(
        event_type: "missing", severity: WARNING,
        zone_id: zone.id, sensor_id: sensor.id, rule: rule, metric: "availability",
        started_at: gap_from + expected,
        ended_at: gap_to,
        peak_value: (gap_seconds / 60.0).round(1),
        latest_value: (gap_seconds / 60.0).round(1),
        latest_seen_at: gap_from,
        evidence: {
          "last_good_at" => gap_from.utc.iso8601,
          "gap_seconds" => gap_seconds.round,
          "missing_gap_threshold_seconds" => spec.missing_gap_seconds,
          "expected_interval_seconds" => expected.round
        }
      )
    end

    def expected_interval(points)
      gaps = points.each_cons(2).map { |a, b| b[:t] - a[:t] }.reject { |g| g <= 0 }
      return spec.missing_gap_seconds.to_f if gaps.empty?
      gaps.sort[gaps.size / 2].to_f
    end

    # ---------- 3. 传感器漂移 ----------

    def detect_drift(sensor)
      return if sensor.sensor_type == "humi"

      metric = "temp_c"
      from = now - spec.drift_window_seconds
      points = SensorReading
        .where(zone_id: zone.id, sensor_id: sensor.id, observed_at: from..now)
        .order(:observed_at)
        .pluck(:observed_at, :temp_c)
        .filter_map { |t, v| v && [t, v.to_f] }

      return if points.size < 12

      slope, intercept = linear_regression(points)
      slope_per_day = slope * 86_400
      own_mean = points.sum { |_, v| v } / points.size

      peers = peer_sensor_ids(sensor)
      peer_mean = peer_zone_mean(peers, from)
      return if peer_mean.nil? # 无同伴可比对，不轻易判漂移

      divergence = (own_mean - peer_mean).abs
      drifted = slope_per_day.abs >= spec.drift_slope_per_day &&
                divergence >= spec.drift_peer_diff

      if drifted
        severity = divergence >= spec.drift_peer_diff * 2 ? CRITICAL : WARNING
        finding = Finding.new(
          event_type: "drift", severity: severity,
          zone_id: zone.id, sensor_id: sensor.id, rule: rule, metric: metric,
          started_at: points.first[0], ended_at: nil,
          peak_value: divergence.round(3),
          latest_value: own_mean.round(3),
          latest_seen_at: points.last[0],
          evidence: {
            "window_hours" => spec.drift_window_seconds / 3600,
            "slope_c_per_day" => slope_per_day.round(4),
            "intercept_c" => intercept.round(3),
            "sensor_mean_c" => own_mean.round(3),
            "peer_mean_c" => peer_mean.round(3),
            "peer_sensor_ids" => peers,
            "divergence_c" => divergence.round(3),
            "slope_threshold_c_per_day" => spec.drift_slope_per_day,
            "peer_diff_threshold_c" => spec.drift_peer_diff,
            "sample_count" => points.size,
            "sample_tail" => points.last(10).map { |t, v|
              { "at" => t.utc.iso8601, "temp_c" => v }
            }
          }
        )
        record(events.persist!(finding))
      else
        resolve_open!("drift", sensor, metric, points.last[0])
      end
    end

    def peer_sensor_ids(sensor)
      zone.sensor_assignments.active_at(now)
        .includes(:sensor)
        .map(&:sensor)
        .reject { |s| s.id == sensor.id || %w[replaced retired offline].include?(s.status) }
        .select { |s| s.sensor_type != "humi" }
        .map(&:id)
    end

    # 同伴基线：先算每个同伴传感器的均值，再取中位数，
    # 避免单个自身异常的同伴把基线带偏
    def peer_zone_mean(peer_ids, from)
      return nil if peer_ids.empty?
      means = SensorReading
        .where(zone_id: zone.id, sensor_id: peer_ids, observed_at: from..now)
        .group(:sensor_id)
        .average(:temp_c)
        .values.map(&:to_f)
      return nil if means.empty?
      sorted = means.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end

    # y = a*x + b，x 为相对秒数
    def linear_regression(points)
      t0 = points.first[0].to_i.to_f
      xs = points.map { |t, _| t.to_i - t0 }
      ys = points.map { |_, v| v }
      n = xs.size
      mx = xs.sum / n
      my = ys.sum / n
      var = xs.sum { |x| (x - mx)**2 }
      return [0.0, my] if var.zero?
      cov = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
      slope = cov / var
      [slope, my - slope * mx]
    end

    # ---------- 恢复收尾 ----------

    def record(result)
      action, _event = result
      @totals[:created] += 1 if action == :created
      @totals[:updated] += 1 if action == :updated
    end

    def resolve_open!(type, sensor, metric, ended_at)
      open = RiskEvent.openish.find_by(
        event_type: type, sensor_id: sensor.id, zone_id: zone.id, metric: metric
      )
      return unless open
      events.auto_resolve!(open, at: ended_at || now)
      @totals[:resolved] += 1
    end
  end
end
