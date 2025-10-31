# frozen_string_literal: true
class Account < ActiveRecord::Base
  audited
  has_associated_audits

  IDENTIFIER_PREFIX = 'PI-'
  IDENTIFIER_CHARS  = ('0'..'9').to_a
  IDENTIFIER_SIZE   = 8

  COMCAST_ACCOUNT_ID = 100

  alias_attribute :company_name, :name

  enum ip_storage_policy: { store_full: 0, store_obfuscated: 1, store_none: 2 }

  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_many :surveys, dependent: :destroy
  has_many :impressions, through: :surveys
  has_many :submissions, through: :surveys
  has_many :answers, through: :surveys
  has_many :device_datas
  has_many :scheduled_reports
  has_many :themes, dependent: :destroy
  has_many :survey_tags
  has_many :answer_images, as: :imageable
  has_many :automations, dependent: :destroy
  has_many :survey_locale_groups, foreign_key: :owner_record_id, inverse_of: :account
  has_many :question_locale_groups, through: :survey_locale_groups
  has_many :signin_activities, dependent: :destroy
  has_many :page_events, dependent: :destroy
  has_many :submission_caches, through: :surveys, class_name: 'SurveySubmissionCache'
  has_one  :invitation, dependent: :nullify
  has_one  :primary_account_user, -> { order(:created_at) }, class_name: "AccountUser"
  has_one  :primary_user, through: :primary_account_user, class_name: "User", source: :user
  has_one  :account_stat
  has_one  :personal_data_setting
  has_one  :qrvey_user

  before_save :set_identifier
  before_create :set_viewed_impressions_enabled_at
  after_create :create_surveys_from_template
  after_create :set_account_stat
  after_create :create_personal_data_setting

  scope :observed, -> { where(is_observed: true) }

  # Normal user can use special account name
  validates_exclusion_of :name,
                         in: [CUSTOMS[:account_for_prepopulated_surveys]],
                         if: ->(account) { account.name_was != CUSTOMS[:account_for_prepopulated_surveys] }

  validates :name, presence: true
  validates :tag_js_version, inclusion: { in: TagJsFileHelpers.tag_js_versions }
  validate :domains_to_allow_for_redirection, :validate_domain_characters

  delegate :email, to: :primary_user, allow_nil: true
  delegate :name, to: :primary_user, prefix: true, allow_nil: true
  delegate :join_date, to: :primary_user, allow_nil: true
  delegate :sign_in_count, to: :primary_user, allow_nil: true
  delegate :last_sign_in_at, to: :primary_user, allow_nil: true
  delegate :calls_count, to: :account_stat, allow_nil: true
  delegate :last_call_at, to: :account_stat, allow_nil: true

  accepts_nested_attributes_for :surveys

  def idp_set_up?
    id == COMCAST_ACCOUNT_ID
  end

  def idp_config(idp_name)
    Account.static_idp_config(idp_name)
  end

  IDP_CONFIGURATIONS = {
    'google_test' => {
      issuer: "console.pulseinsights.com",
      idp_sso_service_url: "https://accounts.google.com/o/saml2/idp?idpid=C02e9xugf",
      idp_entity_id: "https://accounts.google.com/o/saml2?idpid=C02e9xugf",
      idp_cert: Rails.application.credentials.saml[:idp_cert][:google_test],
      assertion_consumer_service_url: "https://staging.pulseinsights.com/auth/saml/pi_google_test/callback",
      sp_identity_id: "console.pulseinsights.com",
      idp_sso_service_binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
      name_identifier_format: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
    },
    'comcast' => {
      issuer: 'console.pulseinsights.com',
      idp_sso_service_url: 'https://login.microsoftonline.com/906aefe9-76a7-4f65-b82d-5ec20775d5aa/saml2',
      idp_entity_id: 'https://sts.windows.net/906aefe9-76a7-4f65-b82d-5ec20775d5aa/',
      idp_cert: Rails.application.credentials.saml[:idp_cert][:comcast],
      assertion_consumer_service_url: 'https://console.pulseinsights.com/auth/saml/906aefe9-76a7-4f65-b82d-5ec20775d5aa/callback',
      sp_identity_id: "console.pulseinsights.com",
      idp_sso_service_binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
      name_identifier_format: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
      attribute_statements: { # https://docs.microsoft.com/en-us/azure/active-directory/develop/single-sign-on-saml-protocol#response
        name: ["http://schemas.microsoft.com/identity/claims/displayname"],
        email: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"],
        first_name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"],
        last_name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"]
      },
      uid_attribute: "http://schemas.microsoft.com/identity/claims/objectidentifier"
    }
  }.freeze

  def self.static_idp_config(idp_name)
    IDP_CONFIGURATIONS[idp_name]
  end

  def self.generate_identifier
    suffix = (0...IDENTIFIER_SIZE).collect { IDENTIFIER_CHARS[Kernel.rand(IDENTIFIER_CHARS.length)] }.join
    "#{IDENTIFIER_PREFIX}#{suffix}"
  end

  def self.pick_a_valid_identifier
    loop do
      identifier = generate_identifier
      return identifier unless exists?(identifier: identifier)
    end
  end

  def self.template_account
    find_by(name: CUSTOMS[:account_for_prepopulated_surveys])
  end

  def frequency_cap_in_words
    if frequency_cap_enabled && frequency_cap_duration
      "Max #{frequency_cap_limit} #{'attempt'.pluralize(frequency_cap_limit)}
      to show survey per #{frequency_cap_duration} #{frequency_cap_type.pluralize(frequency_cap_duration)}"
    else
      "No limit"
    end
  end

  def template_account?
    name == CUSTOMS[:account_for_prepopulated_surveys]
  end

  def cancel!
    update_column(:cancelled_at, Time.now.utc)
  end

  def cancelled=(value)
    self.cancelled_at = Time.utc.now if value.is_a?(TrueClass)
  end

  def cancelled?
    cancelled_at?
  end
  alias cancelled cancelled?

  def tag_code(debug_mode: false)
    # See the file below to see all the bindings
    @survey_js_host = Rails.configuration.survey_js_host
    @survey_host = Rails.configuration.survey_host
    @identifier = identifier
    @debug_mode = debug_mode
    @use_new_spa_behaviour = use_new_spa_behaviour

    <<~JS
    <script>#{ERB.new(TagJsFileHelpers.tag_js(tag_js_version)).result(binding)}</script>
    JS
  end

  def company_name
    self[:name].presence || self[:identifier]
  end

  def status
    self[:cancelled_at].present? ? "Cancelled #{self[:cancelled_at]}" : 'Available'
  end

  # Used to search dataTables used by admin pages
  def self.search(keyword)
    @relation = all
    if keyword.present?
      @relation = @relation.joins('LEFT OUTER JOIN "users" ON "users"."account_id" = "accounts"."id"').
                  joins('LEFT JOIN account_stats ON account_stats.account_id = accounts.id').
                  where(User::WHERE_SQL, keyword: "%#{keyword}%").distinct(:id)
    end

    @relation
  end

  def autocomplete_name
    "#{name || "unnamed"} (#{identifier})"
  end

  # Viewed impressions are employed over served impressions the day after it was enabled, ensuring it was available for the entirety of a day
  def viewed_impressions_calculation_start_at
    viewed_impressions_enabled_at.beginning_of_day + 1.day
  end

  def login_count(time_range: nil, only_external: false)
    scope = signin_activities
    scope = scope.where(created_at: time_range) if time_range
    scope = scope.for_external_teams if only_external
    scope.count
  end

  def register_with_qrvey
    self.qrvey_user ||= QrveyUser.create(account: self)
  end

  def registered_with_qrvey?
    qrvey_user&.registered_with_qrvey? && qrvey_user.qrvey_applications&.first&.registered_with_qrvey?
  end

  def ai_agent_feature_flags
    attributes.select { |column_name, _enabled| column_name.end_with?("_agent_enabled") }
  end

  private

  def set_identifier
    self.identifier ||= Account.pick_a_valid_identifier
  end

  def create_surveys_from_template
    return true if template_account? || Survey.template_surveys.blank?
    template_account = Account.template_account
    return true unless template_account

    template_account.surveys.each do |survey|
      duplicated_survey = survey.duplicate
      duplicated_survey.account = self
      duplicated_survey.name = survey.name

      if duplicated_survey.save
        duplicated_survey.survey_stat.update(answers_count: 0)
        duplicated_survey.reattach_plumbing_lines(survey)
      end
    end
  end

  def set_account_stat
    AccountStat.create(account: self, identifier: identifier)
  end

  def set_viewed_impressions_enabled_at
    self.viewed_impressions_enabled_at ||= Time.current
  end

  def validate_domain_characters
    domains_to_allow_for_redirection.each do |domain|
      errors.add(:domains_to_allow_for_redirection, "#{domain} includes more than one invalid characters") unless domain.match?(/^([a-zA-Z0-9\-.]?)+$/)
    end
  end
end

# == Schema Information
#
# Table name: accounts
#
#  id                                :integer          not null, primary key
#  ai_summaries_enabled              :boolean          default(FALSE), not null
#  cancelled_at                      :datetime
#  custom_content_link_click_enabled :boolean          default(FALSE), not null
#  custom_data_enabled               :boolean          default(FALSE)
#  custom_data_snippet               :text
#  domains_to_allow_for_redirection  :text             default([]), not null, is an Array
#  enabled                           :boolean          default(TRUE)
#  frequency_cap_duration            :integer
#  frequency_cap_enabled             :boolean          default(FALSE)
#  frequency_cap_limit               :integer
#  frequency_cap_type                :string
#  identifier                        :string(255)
#  ip_storage_policy                 :integer          default("store_full")
#  ips_to_block                      :text
#  is_observed                       :boolean          default(FALSE), not null
#  max_submissions                   :integer          default(500)
#  max_submissions_per_month         :integer
#  name                              :string(255)
#  next_insights_agent_enabled       :boolean          default(FALSE), not null
#  onanswer_callback_code            :text
#  onanswer_callback_enabled         :boolean          default(FALSE)
#  onclick_callback_code             :text
#  onclick_callback_enabled          :boolean          default(FALSE), not null
#  onclose_callback_code             :text
#  onclose_callback_enabled          :boolean          default(FALSE), not null
#  oncomplete_callback_code          :text
#  oncomplete_callback_enabled       :boolean          default(FALSE)
#  onview_callback_code              :text
#  onview_callback_enabled           :boolean          default(FALSE), not null
#  pulse_insights_branding           :boolean          default(TRUE)
#  qrvey_enabled                     :boolean          default(TRUE)
#  region                            :string           default("en-US")
#  survey_brief_agent_enabled        :boolean          default(FALSE)
#  tag_automation_enabled            :boolean          default(FALSE), not null
#  tag_js_version                    :string           default("1.0.2"), not null
#  use_new_spa_behaviour             :boolean          default(TRUE)
#  viewed_impressions_enabled_at     :timestamptz
#  created_at                        :datetime
#  updated_at                        :datetime
#
# Indexes
#
#  index_accounts_on_cancelled_at  (cancelled_at)
#  index_accounts_on_identifier    (identifier)
#  index_accounts_on_name          (name)
#
