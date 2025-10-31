# frozen_string_literal: true
module Control
  # TODO: Rename to "MyAccount" - It's not consistent and #render can't look up templates from paths
  class MyAccountsController < BaseController
    before_action :set_account, only: %i(data_integrations set_user_level user_management global_targeting update_global_targeting)
    before_action :set_user, except: :data_integrations
    before_action :set_users, only: [:user_management]
    before_action :require_full_access_user!, except: [:edit, :update, :get_code_snippet]

    def update
      case params[:type]
      when 'info'
        if user_params.keys.include?("account_name") && !@user.admin?
          flash.now.alert = "Only superadmins may edit account names. Please contact support@pulseinsights.com"
          render :edit and return
        else
          @user.update(user_params)
        end
      when 'cancel'
        @user.account.try(:cancel!)
      end

      if @user.errors.blank?
        flash.now.notice = 'Update contact info successful!' if params[:type] == 'info'
        flash.now.notice = 'Cancel account successful!' if params[:type] == 'cancel'
      else
        flash.now.alert = current_user.errors.full_messages.join(", ")
      end

      render :edit
    end

    def update_email
      # TODO: Consider doing this through Devise
      new_token = SecureRandom.hex(10)
      current_user.update(reset_email_token: new_token, reset_email_sent_at: Time.current)
      UserMailer.reset_email(current_user.email, params[:user][:email], new_token).deliver_now
      redirect_back fallback_location: root_path, notice: "Confirmation email sent!"
    end

    def update_password
      user_params = params[:user]
      password_params = {current_password: user_params[:current_password], password: user_params[:new_password]}

      if current_user.update_with_password(password_params)
        redirect_to sign_in_url, notice: 'Change password successful!'
      else
        flash.now.alert = current_user.errors.full_messages
        render :edit
      end
    end

    def invite
      if params[:invitation][:account_id].to_i == @user.account_id
        invitation = Invitation.where(invitation_params).first_or_create

        if invitation.persisted?
          invitation.invite_new_user_to_account
          flash.notice = "Sent invitation to #{invitation.email}"
        else
          flash.alert = if current_user.admin?
            "Failed to invite. #{invitation.errors.full_messages.join(',')}"
          else
            "Invalid e-mail address. Please try a different one."
          end
        end
      else
        flash.alert = "Error inviting user."
      end

      redirect_to user_management_my_account_path
    end

    def data_integrations
      patch_data_integrations if request.patch?

      @audits = @account.audits.descending if current_user.admin?
    end

    def patch_data_integrations
      @account.update(params.require(:account).permit(:custom_data_enabled, :custom_data_snippet,
                                                      :onview_callback_enabled, :onview_callback_code,
                                                      :onclose_callback_enabled, :onclose_callback_code,
                                                      :oncomplete_callback_enabled, :oncomplete_callback_code,
                                                      :onanswer_callback_enabled, :onanswer_callback_code,
                                                      :onclick_callback_enabled, :onclick_callback_code))
      if @account.errors.blank?
        flash.now.notice = 'Analytics setting was successfully updated.'
      else
        flash.now.alert = @account.errors.full_messages.join(',')
      end
    end

    # Used by the user level dropdown
    def set_user_level
      @user = @account.users.find(params[:id])
      if @user == current_user
        respond_to do |format|
          format.json { render json: :forbidden, status: 403 }
        end
      else
        @user.update(level: params[:user][:level].to_i)
        respond_to do |format|
          format.json { render json: :ok }
        end
      end
    rescue ActiveRecord::RecordNotFound => e
      respond_to do |format|
        format.json { render json: :not_found, status: 404 }
      end
    end

    def global_targeting
      @audits = @account.audits.descending if current_user.admin?
    end

    def update_global_targeting
      if @account.update(global_targeting_params)
        flash.now.notice = "Update global targeting successful!"
      else
        flash.now.alert = "Failed to update global targeting: #{@account.errors.full_messages}"
      end

      redirect_to global_targeting_my_account_path, notice: 'Update global targeting successful!'
    end

    def update_frequency_capping
      if user_params[:frequency_cap_enabled] == '1' # true
        @user.account.update(frequency_cap_enabled: user_params[:frequency_cap_enabled],
                             frequency_cap_limit: user_params[:frequency_cap_limit],
                             frequency_cap_duration: user_params[:frequency_cap_duration],
                             frequency_cap_type: user_params[:frequency_cap_type])
      else
        @user.account.update(frequency_cap_enabled: user_params[:frequency_cap_enabled],
                             frequency_cap_limit: nil,
                             frequency_cap_duration: nil,
                             frequency_cap_type: nil)
      end

      redirect_to global_targeting_my_account_path, notice: 'Update frequency capping successful!'
    end

    def update_ai_summaries_enabled
      @user.account.update(ai_summaries_enabled: user_params[:ai_summaries_enabled] == '1')

      redirect_to global_targeting_my_account_path, notice: "Update successful!"
    end

    def audit
      @account = current_user.account
    end

    def edit
      # rubocop:disable Style/GuardClause
      # obeying this rule here would be more complicated than breaking it
      if current_user.admin?
        @audits = []

        @audits << @user.account.audits
        @audits << @user.account.primary_user.audits

        @audits = @audits.flatten.compact.sort_by(&:created_at).reverse
      end
    end

    def user_management
      @audits = @user.account.associated_audits.where(auditable_type: %w(Invitation User)).descending if current_user.admin?
    end

    private

    def invitation_params
      params_whitelist = [:email, :level, :account_id]

      params.require(:invitation).permit(params_whitelist)
    end

    def global_targeting_params
      permitted_params = params.require(:account).permit(:ips_to_block, :domains_to_allow_for_redirection)

      if permitted_params[:domains_to_allow_for_redirection]
        permitted_params[:domains_to_allow_for_redirection] = permitted_params[:domains_to_allow_for_redirection].split(/\r?\n/)
      end

      permitted_params
    end

    def user_params
      params.require(:user).permit(
        :first_name, :last_name, :account_name, :current_password, :new_password, :ips_to_block,
        :frequency_cap_enabled, :frequency_cap_limit, :frequency_cap_duration, :frequency_cap_type,
        :ai_summaries_enabled
      )
    end

    def set_user
      @user = current_user
    end

    def set_account
      @account = current_user.account
    end

    def set_users
      @users = @user.account ? @user.account.users.select([:id, :email, :first_name, :last_name, :level, :created_at, :admin]) : []
    end
  end
end
