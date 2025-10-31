# frozen_string_literal: true

module ClientReports
  class ClientReportHistory < ApplicationRecord
    enum status: {
      pending: 0,
      failed: 1,
      succeeded: 2
    }

    scope :for_job_class, ->(job_class) { where(job_class: job_class.name.underscore) }
  end
end

# == Schema Information
#
# Table name: client_report_histories
#
#  id              :bigint           not null, primary key
#  data_start_time :datetime         not null
#  job_class       :string           not null
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_client_report_histories_on_job_class                      (job_class)
#  index_client_report_histories_on_job_class_and_data_start_time  (job_class,data_start_time)
#
