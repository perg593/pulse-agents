# frozen_string_literal: true

# A helper class to make parsing and working with Qrvey API responses easier
class QrveyDashboardResponse
  attr_accessor :raw

  def initialize(raw)
    @raw = raw
  end

  def dashboard_name
    @raw["name"]
  end

  def custom_attributes
    QrveyBridge::CustomAttributes.new(@raw["customAttributes"] || {})
  end

  # pageid vs pageOriginalid
  #
  # If the endpoint returns the original dashboard, the pageid will have
  # the ID we want. If the endpoint returns a published "version", then pageOriginalid will have the original dashboard.
  #
  # * There's more than one dashboard "version" out there. One represents the
  # "initial", unpublished, dashboard, and the other(s?) represent published
  # versions. pageOriginalid refers to the unpublished version.
  def dashboard_id
    @raw["pageOriginalid"] || @raw["pageid"] || @raw["pageId"]
  end

  def can_delete?(user_id)
    dashboard_owned_by_user?(user_id)
  end

  def can_share?(user_id)
    dashboard_owned_by_user?(user_id) || dashboard_shared_with_user?(user_id)
  end

  def can_copy?(_user_id)
    true
  end

  def can_edit?(user_id)
    dashboard_owned_by_user?(user_id) ||
      (dashboard_shared_with_user?(user_id) && user_access_level(user_id) == QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR)
  end

  def dashboard_shared_with_user?(user_id)
    !dashboard_owned_by_user?(user_id) && user_access_level(user_id).present?
  end

  def dashboard_owned_by_user?(user_id)
    custom_attributes.owner_id == user_id
  end

  def user_access_level(user_id)
    custom_attributes.access_level(user_id)
  end

  def built_in_dashboard?
    QrveyDashboardMapping.where(qrvey_name: dashboard_name).exists?
  end
end
