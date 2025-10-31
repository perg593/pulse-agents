# frozen_string_literal: true
require_relative "../../../lib/qrvey_client/qrvey_client"

#------------------------------------------------------------------------------
# Used to register and track a (service) user on Qrvey.
# Users own applications on Qrvey.
# Users have a unique identifier which is used in Qrvey API calls.
# We store login credentials, though these are generally only needed for advanced troubleshooting.
#------------------------------------------------------------------------------
class QrveyUser < ActiveRecord::Base
  audited
  encrypts :password

  belongs_to :account
  has_many :qrvey_applications

  before_create :set_password
  after_create :queue_qrvey_registration

  def registered_with_qrvey?
    qrvey_user_id.present?
  end

  def email_address
    "qrveyserviceuser+#{account.id}@pulseinsights.com"
  end

  def register_with_qrvey
    return if registered_with_qrvey?

    body = {
      first_name: "Pablo",
      last_name: "Insights",
      email: email_address,
      password: password,
      groupList: [
        {
          groupid: "c-WUhuurn",
          name: "Service User"
        }
      ]
    }

    update(qrvey_user_id: QrveyClient.create_user(body))
  end

  private

  def queue_qrvey_registration
    Qrvey::UserWorker.perform_async(id)
  end

  def set_password
    return if password.present?

    self.password = SecureRandom.uuid
  end
end

# == Schema Information
#
# Table name: qrvey_users
#
#  id            :bigint           not null, primary key
#  password      :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint
#  qrvey_user_id :string
#
# Indexes
#
#  index_qrvey_users_on_account_id  (account_id) UNIQUE
#
