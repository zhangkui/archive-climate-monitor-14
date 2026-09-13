class ReportsController < ApplicationController
  # GET /api/reports
  def index
    reports = Report.order(created_at: :desc).limit(100)
    render json: reports.map { |r| Serializers.report(r) }
  end

  # POST /api/reports
  # body: { kind: "event_export", zone_id: null,
  #         period_from: "2026-09-01T00:00:00+08:00",
  #         period_to:   "2026-09-12T23:59:59+08:00" }
  def create
    report = Report.create!(
      kind: params[:kind] || "event_export",
      zone_id: params[:zone_id],
      period_from: Time.iso8601(params.require(:period_from)),
      period_to: Time.iso8601(params.require(:period_to)),
      created_by: actor_name
    )
    GenerateReportJob.perform_later(report.id)
    render json: Serializers.report(report), status: :created
  end

  def show
    render json: Serializers.report(Report.find(params[:id]))
  end

  # GET /api/reports/:id/download —— 跳转 MinIO 预签名 URL
  def download
    report = Report.find(params[:id])
    raise ActiveRecord::RecordNotFound, "报表尚未生成" unless report.status == "done"
    url = Reports::EventExportService.new(report).presigned_url
    render json: { url: url, expires_in: 900 }
  end
end
