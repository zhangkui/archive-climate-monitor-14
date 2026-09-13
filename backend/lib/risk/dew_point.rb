module Risk
  # Magnus 公式近似计算露点温度（°C）。
  # 传感器未直接上报 dew_point_c 时由温湿度反算。
  module DewPoint
    A = 17.625
    B = 243.04

    module_function

    def calc(temp_c, humi_pct)
      return nil if temp_c.nil? || humi_pct.nil?
      rh = humi_pct.to_f.clamp(0.1, 100.0)
      t = temp_c.to_f
      gamma = (A * t) / (B + t) + Math.log(rh / 100.0)
      (B * gamma) / (A - gamma)
    end

    # 露点裕度 = 气温 - 露点；越小越接近结露
    def margin(temp_c, humi_pct)
      d = calc(temp_c, humi_pct)
      d && temp_c ? temp_c.to_f - d : nil
    end
  end
end
