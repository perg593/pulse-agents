# frozen_string_literal: true
module Admin
  class QrveyDashboardMappingsController < BaseController
    include Control::RedirectHelper

    before_action :set_qrvey_dashboard_mapping, only: %i(destroy update change_position)

    def change_position
      old_position = @qrvey_dashboard_mapping.position

      if params[:new_position].blank?
        render json: { error: "Invalid position #{params[:new_position]}" }, status: 400 and return
      end

      new_position = params[:new_position].to_i

      if old_position == new_position
        render json: { error: "Invalid position #{new_position}" }, status: 400 and return
      end

      ActiveRecord::Base.transaction do
        @qrvey_dashboard_mapping.update(position: -1)

        if new_position > old_position
          dashboards_to_slide = QrveyDashboardMapping.where(position: [old_position + 1..new_position]).order(position: :asc)

          dashboards_to_slide.each { |dashboard| dashboard.decrement!(:position) }
        else
          dashboards_to_slide = QrveyDashboardMapping.where(position: [new_position..old_position - 1]).order(position: :desc)

          dashboards_to_slide.each { |dashboard| dashboard.increment!(:position) }
        end

        @qrvey_dashboard_mapping.update(position: new_position)
      end

      qrvey_dashboard_mappings = QrveyDashboardMapping.all.order(:position).map do |qrvey_dashboard_mapping|
        qrvey_dashboard_mapping_response_object(qrvey_dashboard_mapping)
      end

      render json: { qrveyDashboardMappings: qrvey_dashboard_mappings }, status: :ok
    end

    def create
      qrvey_dashboard_mapping = QrveyDashboardMapping.new(qrvey_dashboard_params)
      qrvey_dashboard_mapping.position = (QrveyDashboardMapping.maximum(:position) || 0) + 1

      if qrvey_dashboard_mapping.save
        render json: { qrveyDashboardMapping: qrvey_dashboard_mapping_response_object(qrvey_dashboard_mapping) }, status: :ok
      else
        render json: { error: qrvey_dashboard_mapping.errors.full_messages.join(',') }, status: 500
      end
    end

    def destroy
      old_position = @qrvey_dashboard_mapping.position

      if @qrvey_dashboard_mapping.destroy
        QrveyDashboardMapping.where("position > ?", old_position).order(:position).each do |qrvey_dashboard_mapping|
          qrvey_dashboard_mapping.update(position: qrvey_dashboard_mapping.position - 1)
        end

        qrvey_dashboard_mappings = QrveyDashboardMapping.all.order(:position).map do |qrvey_dashboard_mapping|
          qrvey_dashboard_mapping_response_object(qrvey_dashboard_mapping)
        end

        render json: { qrveyDashboardMappings: qrvey_dashboard_mappings }, status: :ok
      else
        render json: { error: @qrvey_dashboard_mapping.errors.full_messages.join(',') }, status: 500
      end
    end

    def update
      if @qrvey_dashboard_mapping.update(qrvey_dashboard_params)
        render json: { qrveyDashboardMapping: qrvey_dashboard_mapping_response_object(@qrvey_dashboard_mapping) }, status: :ok
      else
        render json: { error: @qrvey_dashboard_mapping.errors.full_messages.join(',') }, status: 500
      end
    end

    def index
      qrvey_dashboard_mappings = QrveyDashboardMapping.all.order(:position).map do |qrvey_dashboard_mapping|
        qrvey_dashboard_mapping_response_object(qrvey_dashboard_mapping)
      end

      @props = { qrveyDashboardMappings: qrvey_dashboard_mappings }
    end

    private

    def set_qrvey_dashboard_mapping
      @qrvey_dashboard_mapping = QrveyDashboardMapping.find_by(id: params[:id])

      handle_missing_record unless @qrvey_dashboard_mapping
    end

    def qrvey_dashboard_params
      params.require(:qrvey_dashboard_mapping).permit(:qrvey_name, :pi_name, :position)
    end

    def qrvey_dashboard_mapping_response_object(qrvey_dashboard_mapping)
      {
        id: qrvey_dashboard_mapping.id,
        qrveyName: qrvey_dashboard_mapping.qrvey_name,
        piName: qrvey_dashboard_mapping.pi_name,
        position: qrvey_dashboard_mapping.position
      }
    end
  end
end
