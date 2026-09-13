module Risk
  # 规则阈值与检测器参数的带类型视图，带档案保管默认值兜底。
  # 入库时规则内容整体快照到 risk_rules 行；事件再引用该行，
  # 因此规则升级对历史结论零影响。
  class RuleSpec
    DEFAULTS = {
      thresholds: {
        "temp" => { "min" => 14.0, "max" => 24.0,
                    "critical_min" => 10.0, "critical_max" => 30.0 },
        "humi" => { "min" => 45.0, "max" => 60.0,
                    "critical_min" => 35.0, "critical_max" => 70.0 },
        # 露点与库房温度接近到该差值（°C）时，结露风险升高
        "dew_proximity_c" => 2.0
      },
      detectors: {
        # 连续超阈值持续时间（分钟）
        "sustained_minutes" => 30,
        # 相邻测点最大允许间隔（分钟），超过即缺测
        "missing_gap_minutes" => 60,
        # 漂移检测窗口、窗口内允许斜率、与同伴传感器允许偏差
        "drift_window_hours" => 24,
        "drift_slope_c_per_day" => 0.8,
        "drift_peer_diff_c" => 1.5,
        # 单次扫描回看窗口（小时）
        "lookback_hours" => 3
      }
    }.freeze

    attr_reader :thresholds, :detectors

    def initialize(thresholds, detectors)
      @thresholds = DEFAULTS[:thresholds].deep_dup
        .deep_merge((thresholds || {}).deep_stringify_keys)
      @detectors = DEFAULTS[:detectors].deep_dup
        .merge((detectors || {}).deep_stringify_keys)
    end

    def temp_bounds
      thresholds["temp"].values_at("min", "max", "critical_min", "critical_max").map(&:to_f)
    end

    def humi_bounds
      thresholds["humi"].values_at("min", "max", "critical_min", "critical_max").map(&:to_f)
    end

    def dew_proximity_c = thresholds["dew_proximity_c"].to_f
    def sustained_seconds = detectors["sustained_minutes"].to_i * 60
    def missing_gap_seconds = detectors["missing_gap_minutes"].to_i * 60
    def drift_window_seconds = detectors["drift_window_hours"].to_i * 3600
    def drift_slope_per_day = detectors["drift_slope_c_per_day"].to_f
    def drift_peer_diff = detectors["drift_peer_diff_c"].to_f
    def lookback_seconds = detectors["lookback_hours"].to_i * 3600
  end
end
