# frozen_string_literal: true
module Admin
  class AccountsController < BaseController
    before_action :set_account, only: %i(activate audit deactivate destroy edit observe update register_with_qrvey block_qrvey_access restore_qrvey_access)

    def register_with_qrvey
      @account.register_with_qrvey

      flash.notice = "Registering with Qrvey, please wait a minute"

      redirect_to edit_admin_account_path(@account.id)
    end

    def index
      @objects =
        if params[:keyword].present?
          Account.search(params[:keyword])
        else
          Account.joins('LEFT JOIN users ON users.account_id = accounts.id').joins('LEFT JOIN account_stats ON account_stats.account_id = accounts.id')
        end

      template_name     = CUSTOMS[:account_for_prepopulated_surveys]
      @objects          = select_objects
      template_account  = @objects.where('accounts.name = ?', template_name)
      @objects = [@objects.where('accounts.name != ? OR accounts.name IS NULL', template_name)].unshift(template_account).flatten if template_account.any?
    end

    def fetch_submissions
      caches = SurveySubmissionCache.joins(survey: :account).select(<<-SQL).group('accounts.id')
        accounts.id account_id,
        COALESCE(SUM(submission_count), 0) submissions_size,
        COALESCE(SUM(CASE
          WHEN applies_to_date < DATE(accounts.viewed_impressions_enabled_at) + INTERVAL '1 day'
            THEN impression_count
          ELSE viewed_impression_count
        END), 0) AS impressions_size
      SQL
      render json: caches.to_json
    end

    def edit
      @impression_count = @account.surveys.sum(&:cached_blended_impressions_count)
      @submission_count = @account.submission_caches.sum(:submission_count)
    end

    def destroy
      @account.destroy
      redirect_to admin_accounts_url, notice: 'Account was successfully destroyed.'
    end

    def invite
      invitation = Invitation.where(invitation_params).first_or_create

      if invitation.persisted?
        invitation.invite_new_user_to_account
        flash.notice = "Sent invitation to #{invitation.email}"
      else
        flash.alert = "Failed to invite. #{invitation.errors.full_messages.join(',')}"
      end

      @account = Account.find_by_id(params[:invitation][:account_id])

      redirect_to edit_admin_account_path(@account.id)
    end

    def update
      @account.update(account_params)
      flash.now.notice = 'update successful!' if @account.errors.blank?
      render :edit
    end

    def settings
      @all_disabled = Account.where(enabled: true).empty?
      @all_blocked_from_qrvey = Account.where(qrvey_enabled: true).empty?
    end

    def block_qrvey_access
      @account.update(qrvey_enabled: false)

      redirect_to admin_accounts_path, flash: { notice: "Blocked from Qrvey!" }
    end

    def restore_qrvey_access
      @account.update(qrvey_enabled: true)

      redirect_to admin_accounts_path, flash: { notice: "Allowed to see Qrvey!" }
    end

    def update_all_qrvey_access
      block_all = params[:block_all] == "true"

      error_messages = []
      # Updating individually for the audit records
      Account.all.each do |account|
        account.update(qrvey_enabled: !block_all)

        error_messages << "#{account.id}: #{account.errors.full_messages.join(",")}" if account.errors.present?
      end

      if error_messages.present?
        flash.alert = "Update failed for accounts #{error_messages.join(",")}"
      else
        flash.notice = "Update successful!"
      end

      redirect_to settings_admin_accounts_path
    end

    def update_settings
      case settings_params['disable_all']
      when '1'
        Account.update_all(enabled: false)
      when '0'
        Account.update_all(enabled: true)
      end

      redirect_to settings_admin_accounts_path, flash: { notice: 'Update successful!' }
    end

    def activate
      @account.update(enabled: true)

      redirect_to admin_accounts_path, flash: { notice: 'Update successful!' }
    end

    def deactivate
      @account.update(enabled: false)

      redirect_to admin_accounts_path, flash: { notice: 'Update successful!' }
    end

    def observe
      @account.update(is_observed: params[:is_observed])

      redirect_to admin_accounts_path, flash: { notice: 'Update successful!' }
    end

    def audit
      @audits = gather_audits(@account)
    end

    def audit_all
      @audits = {}

      Account.all.each do |account|
        @audits[account.id] = gather_audits(account)
      end
    end

    private

    def invitation_params
      params_whitelist = [:email, :level, :account_id]

      params.require(:invitation).permit(params_whitelist)
    end

    def gather_audits(account)
      audits = []

      audits << account.own_and_associated_audits
      audits << account.users.map(&:associated_audits)
      audits << account.surveys.map(&:associated_audits)
      audits << account.surveys.map(&:questions).flatten.map(&:associated_audits)
      audits << account.scheduled_reports.map(&:associated_audits)
      audits << account.automations.map(&:associated_audits)

      audits.flatten.compact.sort_by(&:created_at).reverse
    end

    def select_objects
      @objects.select(
        "accounts.id, MAX(account_stats.calls_count), accounts.name, accounts.identifier,
        accounts.enabled, accounts.qrvey_enabled, accounts.is_observed, COUNT(users.id) AS users_size,
        MIN(users.created_at) AS users_join_date, MAX(users.sign_in_count) AS users_sign_in_count, MAX(users.last_sign_in_at) AS users_last_sign_in_at,
        MIN(users.id) AS primary_user_id,
        (SELECT users.first_name AS primary_user_first_name FROM users WHERE users.account_id = accounts.id ORDER BY users.created_at LIMIT 1),
        (SELECT users.last_name AS primary_user_last_name FROM users WHERE users.account_id = accounts.id ORDER BY users.created_at LIMIT 1),
        (SELECT users.email AS primary_user_email FROM users WHERE users.account_id = accounts.id ORDER BY users.created_at LIMIT 1),
        (SELECT COUNT(surveys.id) FROM surveys WHERE surveys.account_id = accounts.id) AS surveys_size,
        (SELECT COUNT(surveys.id) FROM surveys WHERE surveys.account_id = accounts.id AND surveys.status = 1 AND
          (surveys.starts_at IS NULL OR ((surveys.starts_at AT TIME ZONE 'UTC') < (NOW() AT TIME ZONE 'UTC'))) AND
          (surveys.ends_at IS NULL OR ((surveys.ends_at AT TIME ZONE 'UTC') > (NOW() AT TIME ZONE 'UTC')))) AS live_surveys_size"
      ).group('accounts.id')
    end

    def set_account
      @account = Account.find_by(id: params[:id])
      redirect_to dashboard_path and return unless @account

      @user = @account.primary_user
    end

    def account_params
      params.require(:account).permit(
        :name, :identifier, :pulse_insights_branding, :max_submissions, :max_submissions_per_month, :cancelled_at, :cancelled, :region,
        :ip_storage_policy, :use_new_spa_behaviour, :tag_automation_enabled, :custom_content_link_click_enabled,
        :tag_js_version
      ).tap do |account_params|
        ip_storage_policy = account_params[:ip_storage_policy]
        account_params[:ip_storage_policy] = ip_storage_policy.to_i if ip_storage_policy.present? && ip_storage_policy.to_i.to_s == ip_storage_policy
      end
    end

    def settings_params
      params.require(:settings).permit(:disable_all)
    end
  end
end
