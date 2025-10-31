# frozen_string_literal: true

module Qrvey
  class UserWorker
    include Sidekiq::Worker
    include Common

    def perform(qrvey_user_id)
      qrvey_user = QrveyUser.find(qrvey_user_id)
      qrvey_user.register_with_qrvey

      QrveyApplication.create(qrvey_user_id: qrvey_user_id) unless qrvey_user.qrvey_applications.exists?
    end
  end
end
