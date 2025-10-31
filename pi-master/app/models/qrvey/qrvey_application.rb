# frozen_string_literal: true
require_relative "../../../lib/qrvey_client/qrvey_client"

#------------------------------------------------------------------------------
# Used to register and track an application on Qrvey.
# Qrvey applications are like containers for dashboards and other things.
# A Qrvey application is owned by a qrvey user.
# Qrvey applications can be shared with other qrvey users by ID or by "role/group"
# Applications have a unique identifier which is used in Qrvey API calls.
#------------------------------------------------------------------------------
class QrveyApplication < ActiveRecord::Base
  audited

  belongs_to :qrvey_user
  has_many :qrvey_datasets

  after_create :queue_qrvey_registration

  def registered_with_qrvey?
    qrvey_application_id.present? && shared?
  end

  def register_with_qrvey
    return if qrvey_application_id.present?

    account = qrvey_user.account

    body = {
      name: "#{account.identifier} #{account.name} Tenant App",
      description: "A tenant application for #{account.name}. ID: #{account.id}. #{account.identifier}"
    }

    qrvey_application_id = QrveyClient.create_application(qrvey_user.qrvey_user_id, body).try(:[], "appid")

    update(qrvey_application_id: qrvey_application_id)

    body = {
      isPublic: false,
      groupIds: ["EhIqB-JdL"], # TenantAppAdmin
      userIds: [],
      appId: qrvey_application_id
    }

    update(shared: QrveyClient.share_application(qrvey_application_id, body))
  end

  private

  def queue_qrvey_registration
    Qrvey::ApplicationWorker.perform_async(id)
  end
end

# == Schema Information
#
# Table name: qrvey_applications
#
#  id                   :bigint           not null, primary key
#  shared               :boolean          default(FALSE)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  qrvey_application_id :string
#  qrvey_user_id        :bigint
#
# Indexes
#
#  index_qrvey_applications_on_qrvey_user_id  (qrvey_user_id)
#
