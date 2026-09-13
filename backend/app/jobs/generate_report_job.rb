class GenerateReportJob < ApplicationJob
  queue_as :reports

  def perform(report_id)
    report = Report.find(report_id)
    Reports::EventExportService.generate!(report)
  end
end
