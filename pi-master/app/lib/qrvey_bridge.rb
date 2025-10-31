# frozen_string_literal: true

# A bridge between QrveyClient and our application code
module QrveyBridge
  require_relative "../../lib/qrvey_client/qrvey_client"

  class CustomAttributes
    ACCESS_LEVEL_VIEWER = 0
    ACCESS_LEVEL_EDITOR = 1
    ACCESS_LEVEL_OWNER = 2

    def initialize(custom_attributes_hash = {})
      @users_and_access_levels = custom_attributes_hash["authorization"]
      @users_and_access_levels ||= {}
    end

    def ==(other)
      to_h == other.to_h
    end

    def to_h
      {
        "customAttributes" => {
          "version" => "1.0.0",
          "authorization" => @users_and_access_levels
        }
      }
    end

    def owner_id=(new_owner_id)
      raise ArgumentError, "Invalid owner ID #{new_owner_id}" unless User.where(id: new_owner_id).exists?

      # nil if creating record from scratch
      @users_and_access_levels.delete(owner_id&.to_s)

      @users_and_access_levels[new_owner_id.to_s] = {
        "accessLevel" => ACCESS_LEVEL_OWNER
      }
    end

    def owner_id
      owner = @users_and_access_levels.find { |_user_id, authorization| authorization["accessLevel"] == ACCESS_LEVEL_OWNER }

      owner ? owner[0].to_i : nil
    end

    def access_level_change_allowed?(user_making_change, user_being_changed, requested_change)
      # nil if revoking access
      if requested_change.nil?
        user_making_change == owner_id
      else
        other_current_level = access_level(user_being_changed)

        (other_current_level.nil? || other_current_level <= access_level(user_making_change)) &&
          (requested_change <= access_level(user_making_change))
      end
    end

    def revoke_access(user_id)
      @users_and_access_levels.delete(user_id.to_s)
    end

    def share_with(user_id, access_level)
      raise ArgumentError, "Invalid access level #{access_level}" unless [ACCESS_LEVEL_VIEWER, ACCESS_LEVEL_EDITOR].include? access_level

      @users_and_access_levels[user_id.to_s] = { "accessLevel" => access_level }

      access_level
    end

    def share_with_many(user_ids_with_access_level)
      user_ids_with_access_level.each do |user_id, access_level|
        share_with(user_id, access_level)
      end

      @users_and_access_levels
    end

    def access_level(user_id)
      @users_and_access_levels.dig(user_id.to_s, "accessLevel")
    end

    def valid?
      owner_id.present?
    end
  end

  def self.get_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id)
    response = QrveyClient.get_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id)

    QrveyDashboardResponse.new(response)
  end

  def self.get_all_dashboards(qrvey_user_id, qrvey_application_id)
    response = QrveyClient.get_all_dashboards(qrvey_user_id, qrvey_application_id)

    response["Items"].map { |item| QrveyDashboardResponse.new(item) }
  end

  def self.clone_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, name_for_clone)
    body = {
      "pageName" => name_for_clone
    }

    result = QrveyClient.clone_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, body)

    QrveyDashboardResponse.new(result)
  end

  def self.create_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_name, qrvey_dashboard_description, custom_attributes)
    body = {
      "name" => qrvey_dashboard_name,
      "description" => qrvey_dashboard_description,
      **custom_attributes.to_h
    }

    result = QrveyClient.create_dashboard(qrvey_user_id, qrvey_application_id, body)

    QrveyDashboardResponse.new(result)
  end

  def self.update_custom_attributes(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, custom_attributes)
    raise ArgumentError, "Invalid custom attributes #{custom_attributes.to_h}" unless custom_attributes.valid?

    body = custom_attributes.to_h

    result = QrveyClient.patch_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, body)

    QrveyDashboardResponse.new(result)
  end
end
