# frozen_string_literal: true

module ClientReports
  module StatusLogger
    def record_success(report_data_start_date)
      ClientReports::ClientReportHistory.for_job_class(self.class).succeeded.create(data_start_time: report_data_start_date)
    end

    def record_failure(report_data_start_date)
      ClientReports::ClientReportHistory.for_job_class(self.class).failed.create(data_start_time: report_data_start_date)
    end
  end
end
