require "csv"

module Reports
  # 生成风险事件/库区微气候 CSV 并上传 MinIO；生成预签名下载 URL
  class EventExportService
    PRESIGN_EXPIRES = 900 # 15 分钟

    def self.generate!(report)
      new(report).generate!
    end

    def initialize(report)
      @report = report
    end

    def generate!
      @report.update!(status: "running")
      csv = build_csv
      key = object_key
      upload(key, csv)
      @report.update!(
        status: "done", object_key: key,
        size_bytes: csv.bytesize, content_type: "text/csv; charset=utf-8",
        generated_at: Time.current, error_message: nil
      )
    rescue => e
      @report.update!(status: "failed", error_message: "#{e.class}: #{e.message}")
      raise
    end

    def presigned_url
      signer = Aws::S3::Presigner.new(client: OBJECT_STORAGE_PUBLIC)
      signer.presigned_url(:get_object,
        bucket: REPORT_BUCKET, key: @report.object_key,
        expires_in: PRESIGN_EXPIRES,
        response_content_disposition: "attachment; filename=#{download_name}")
    end

    private

    def scope
      s = RiskEvent.includes(:zone, :sensor, :risk_rule)
                   .where(started_at: @report.period_from..@report.period_to)
      s = s.where(zone_id: @report.zone_id) if @report.zone_id
      s.order(:started_at)
    end

    def build_csv
      CSV.generate(force_quotes: true) do |csv|
        csv << %w[event_id type severity status zone_code sensor_code
                  metric peak_value latest_value rule_version started_at
                  ended_at detected_at confirmed_by resolution note]
        scope.find_each do |e|
          csv << [e.id, e.event_type, e.severity, e.status,
                  e.zone&.code, e.sensor&.code, e.metric,
                  e.peak_value&.to_f, e.latest_value&.to_f,
                  e.risk_rule_version,
                  e.started_at.iso8601, e.ended_at&.iso8601,
                  e.detected_at.iso8601, e.confirmed_by,
                  e.resolution, e.resolution_note]
        end
      end
    end

    def object_key
      ts = @report.created_at.strftime("%Y%m%dT%H%M%S")
      "exports/#{@report.kind}-#{@report.id}-#{ts}.csv"
    end

    def download_name
      "risk-events-#{@report.id}.csv"
    end

    def upload(key, body)
      OBJECT_STORAGE.put_object(
        bucket: REPORT_BUCKET, key: key, body: body,
        content_type: "text/csv; charset=utf-8"
      )
    end
  end
end
