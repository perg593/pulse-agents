# frozen_string_literal: true
class CustomAudit < Audited::Audit
  before_validation :prune_nonchanges
  # TODO: Enable this validation when it does not prevent the audited record from saving
  # e.g. A survey shouldn't fail to update because its audit record was invalid.
  # validates :audited_changes, presence: true
  before_create :handle_anonymity

  scope :for_index, ->(controller) { where(auditable_type: controller, action: %w(create destroy)).descending }
  scope :with_attribute, ->(attribute) { where("audited_changes ->> ? IS NOT NULL", attribute) }
  scope :changes_attribute_to, lambda { |changed_attribute, new_value|
    updates.where("(audited_changes -> ? ->> 1) = ?", changed_attribute.to_s, new_value.to_s)
  }

  def prune_nonchanges
    audited_changes.reject! do |_key, value|
      if value.is_a?(Array)
        value[0] == value[1]
      else
        false
      end
    end
  end

  def handle_anonymity
    return unless user_id.nil?

    # check for async worker name
    worker_name = /workers\/(.*).rb/.match(caller.detect { |line| line.include? "workers/" }).try(:[], 1)

    username = worker_name || ENV["SUDO_USER"] || ENV["USER"]

    if username.nil?
      username ||= "Automated Process"
      Rollbar.warning("Could not determine name for CustomAudit", auditable_type: auditable_type, audited_changes: audited_changes, auditable_id: auditable_id)
    end

    self.username ||= username
    self.comment ||= "An automated process"
  end
end

# == Schema Information
#
# Table name: audits
#
#  id              :integer          not null, primary key
#  action          :string
#  associated_type :string
#  auditable_type  :string
#  audited_changes :jsonb
#  comment         :string
#  remote_address  :string
#  request_uuid    :string
#  user_type       :string
#  username        :string
#  version         :integer          default(0)
#  created_at      :datetime
#  associated_id   :integer
#  auditable_id    :integer
#  user_id         :integer
#
# Indexes
#
#  associated_index              (associated_type,associated_id)
#  auditable_index               (auditable_type,auditable_id,version)
#  index_audits_on_created_at    (created_at)
#  index_audits_on_request_uuid  (request_uuid)
#  user_index                    (user_id,user_type)
#
