# frozen_string_literal: true
module Control
  class PersonalDataSettingsController < BaseController
    before_action :set_setting

    def edit
      redirect_to root_path if current_user.reporting?
    end

    def update
      head :not_found if current_user.reporting?

      if @setting.update(setting_params)
        flash[:notice] = 'Successfully Updated.'
      else
        flash[:alert] = 'Update failed.'
      end

      redirect_back(fallback_location: root_path)
    end

    private

    def setting_params
      params.require(:setting).permit(:masking_enabled, :phone_number_masked, :email_masked)
    end

    def set_setting
      @setting = current_user.account.personal_data_setting
    end
  end
end
