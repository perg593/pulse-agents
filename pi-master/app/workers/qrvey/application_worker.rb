# frozen_string_literal: true

module Qrvey
  class ApplicationWorker
    include Sidekiq::Worker
    include Common

    def perform(qrvey_application_id)
      QrveyApplication.find(qrvey_application_id).register_with_qrvey
    end
  end
end
