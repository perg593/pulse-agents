# frozen_string_literal: true

module QrveySynchronization
  extend ActiveSupport::Concern

  included do
    after_destroy :destroy_also_on_qrvey
  end

  private

  def destroy_also_on_qrvey
    Qrvey::FullDeleteWorker.perform_async(self.class.to_s, id)
  end
end
