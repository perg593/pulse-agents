# frozen_string_literal: true

module Control
  class PageEventsController < BaseController
    before_action :require_full_access_user!, only: :delete_all

    def index
      @page_events_per_name = current_account.page_events.select(<<-SQL).group('page_events.name').order(latest_created_at: :desc)
        page_events.name,
        COUNT(*) event_count,
        MAX(page_events.created_at) latest_created_at
      SQL
    end

    def delete_all
      current_account.page_events.where(name: params[:event_name]).delete_all
      render json: :ok
    rescue => e
      Rollbar.error e
      render json: { error_message: 'Failed to delete all' }, status: 500
    end
  end
end
