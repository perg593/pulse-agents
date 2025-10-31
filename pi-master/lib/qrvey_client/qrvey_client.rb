# frozen_string_literal: true

module QrveyClient
  require_relative "http"

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/b6zlqq2hz9byi-create-application
  # ---------------------------------------------------------------------------
  def self.create_application(qrvey_user_id, body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/user/#{qrvey_user_id}/app"

    HTTP.json_post(url, body, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/1930941cbe8d5-create-user
  # ---------------------------------------------------------------------------
  def self.create_user(body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/core/user"

    user = HTTP.json_post(url, body, logger)

    user["userid"] if user
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/ff0303fef339a-generate-token-for-creators
  # ---------------------------------------------------------------------------
  def self.generate_token(body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/core/login/token"

    response = HTTP.json_post(url, body, logger)

    response["token"] if response
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/9djgu1rw9tgck-share-application
  # ---------------------------------------------------------------------------
  def self.share_application(qrvey_user_id, body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/user/#{qrvey_user_id}/app/share"

    response = HTTP.post(url, body, logger)

    response.nil? ? nil : true
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/2ff17959232b9-get-dataset
  # ---------------------------------------------------------------------------
  def self.get_dataset(qrvey_user_id, qrvey_app_id, dataset_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/user/#{qrvey_user_id}/app/#{qrvey_app_id}/qollect/dataset/#{dataset_id}"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/ae33c9e237eb3-get-all-datasets
  # ---------------------------------------------------------------------------
  def self.get_all_datasets(qrvey_user_id, qrvey_app_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/user/#{qrvey_user_id}/app/#{qrvey_app_id}/qollect/dataset/all"

    HTTP.json_post(url, {}, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/90xuu7wvqw6i8-get-application
  # ---------------------------------------------------------------------------
  def self.get_application(qrvey_user_id, qrvey_app_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/user/#{qrvey_user_id}/app/#{qrvey_app_id}"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/1125d13073f84-get-user
  # ---------------------------------------------------------------------------
  def self.get_user(qrvey_user_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/core/user/#{qrvey_user_id}"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/2f4a96d989b65-get-all-users
  # ---------------------------------------------------------------------------
  def self.get_all_users(limit: 100, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/core/user/all"

    # There's an undocumented default limit of 10, which is too low
    HTTP.json_post(url, {limit: limit}, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/e596c4c71a810-delete-user
  # ---------------------------------------------------------------------------
  def self.delete_user(qrvey_user_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/core/user/#{qrvey_user_id}"

    HTTP.json_delete(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/2vx01ajpecwrm-delete-application
  # ---------------------------------------------------------------------------
  def self.delete_application(qrvey_user_id, qrvey_app_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/user/#{qrvey_user_id}/app/#{qrvey_app_id}"

    HTTP.json_delete(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/0zn6gccz471gg-get-all-dashboards
  # ---------------------------------------------------------------------------
  def self.get_all_dashboards(qrvey_user_id, qrvey_app_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/o837kyj8eyt2v-get-published-dashboards
  # ---------------------------------------------------------------------------
  def self.get_published_dashboards(qrvey_user_id, qrvey_app_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/history/publishednow"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/3768900528a63-get-a-single-dashboard
  # ---------------------------------------------------------------------------
  def self.get_single_dashboard(qrvey_user_id, qrvey_app_id, dashboard_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v6/page/builder/#{dashboard_id}?userId=#{qrvey_user_id}&appId=#{qrvey_app_id}"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/ds1qdph0xwexi-dashboard-view-get-dashboard
  # ---------------------------------------------------------------------------
  def self.get_dashboard_view_dashboard(qrvey_user_id, qrvey_app_id, dashboard_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v4/user/#{qrvey_user_id}/app/#{qrvey_app_id}/page/view/#{dashboard_id}"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/1vtzmr7akk5oh-get-a-dashboard
  # ---------------------------------------------------------------------------
  def self.get_dashboard(qrvey_user_id, qrvey_app_id, dashboard_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{dashboard_id}"

    HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/o7o8z6g9vkfcy-create-a-dashboard
  # ---------------------------------------------------------------------------
  def self.create_dashboard(qrvey_user_id, qrvey_app_id, body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/"

    HTTP.json_post(url, body, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/3r8ftympgwers-clone-dashboard
  # ---------------------------------------------------------------------------
  def self.clone_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{qrvey_dashboard_id}/clone"

    HTTP.json_post(url, body, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/4fx133eyqoejl-delete-a-dashboard
  # ---------------------------------------------------------------------------
  def self.delete_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{qrvey_dashboard_id}"

    HTTP.json_delete(url, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/dlnvm1i3pijtd-update-a-dashboard
  # ---------------------------------------------------------------------------
  def self.update_dashboard(qrvey_user_id, qrvey_app_id, dashboard_id, body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{dashboard_id}"

    HTTP.json_put(url, body, logger)
  end

  # ---------------------------------------------------------------------------
  # https://qrvey.stoplight.io/docs/qrvey-api-doc/e98d47b95ae9b-update-specific-attributes-of-a-dashboard
  # ---------------------------------------------------------------------------
  def self.patch_dashboard(qrvey_user_id, qrvey_app_id, dashboard_id, body, logger: Rails.logger)
    url = "#{QRVEY_CONFIG[:domain]}/devapi/v6/page/builder/#{dashboard_id}?userId=#{qrvey_user_id}&appId=#{qrvey_app_id}"

    HTTP.json_patch(url, body, logger)
  end
end
