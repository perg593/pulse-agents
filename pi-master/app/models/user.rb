# frozen_string_literal: true
class User < ActiveRecord::Base
  devise :recoverable, :lockable, :two_factor_authenticatable, :two_factor_backupable

  WHERE_SQL = %w(accounts.name accounts.identifier users.email users.first_name users.last_name).map { |x| %~(#{x} LIKE :keyword)~ }.join(' OR ')
  include Lockable
  include Inviteable

  audited except: :last_action_at, associated_with: :account
  has_associated_audits

  attr_accessor :current_password, :password_tmp

  alias_attribute :join_date, :created_at

  belongs_to :account
  has_one  :primary_user, through: :account
  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users # represent all linked accounts
  has_many :users, ->(x) { where.not(id: x.id) }, through: :account
  has_many :surveys, through: :account
  has_many :impressions, through: :account
  has_many :submissions, through: :account
  has_many :successful_mfa_signins, dependent: :destroy

  accepts_nested_attributes_for :account

  validates :email, :first_name, :last_name, presence: true
  validates :email, email: true, uniqueness: true

  after_validation :validate_password

  after_create :link_account

  delegate :name, :identifier, :token, to: :account, prefix: true, allow_nil: true
  delegate :calls_count, :last_call_at, :company_name, to: :account, allow_nil: true
  delegate :ips_to_block, :frequency_cap_enabled,
           :frequency_cap_limit, :frequency_cap_duration, :frequency_cap_type,
           :ai_summaries_enabled, to: :account

  enum level: [:full, :reporting]

  scope :active, -> { where(active: true) }

  def multi_factor_qr_code_uri
    otp_provisioning_uri(email, issuer: "Pulse Insights")
  end

  # otp_secret and otp_backup_codes are generated in the controller as
  # part of the MFA configuration process.
  def activate_mfa!
    update!(otp_required_for_login: true)
  end

  def deactivate_mfa!
    update(
      otp_required_for_login: false,
      otp_secret: nil,
      otp_backup_codes: nil
    )
  end

  # Set value to password_tmp for prepare validate password format
  def password=(pwd)
    self.password_confirmation = pwd
    self.password_tmp = pwd.to_s
    super
  end

  def name
    [self[:first_name], self[:last_name]].compact.join(' ')
  end

  def account_name=(value)
    account && account.name = value
  end

  def update_password_if_authenticated(current_password, new_password)
    errors.add(:current_password, 'not correct') and return false unless authenticate(current_password)
    update(password: new_password)
  end

  # Used to search dataTables used by admin pages
  def self.search(keyword)
    @relation = all
    if keyword.present?
      @relation = @relation.left_joins(:accounts).where(WHERE_SQL, keyword: "%#{keyword}%").distinct(:id)
    end

    @relation
  end

  # Email is case-insensitive technically
  def self.find_by_unfolded_email(email)
    where('email ILIKE ?', email).first
  end

  def role
    return 'admin' if admin

    level
  end

  def update_signin_info
    update(last_sign_in_at: Time.now.utc, sign_in_count: sign_in_count + 1, last_action_at: Time.now.utc)
  end

  def autocomplete_tags
    potential_accounts = Account.where.not(id: AccountUser.where(user_id: id).pluck(:account_id))
    potential_accounts.map(&:autocomplete_name)
  end

  def switch_accounts(new_account_id)
    if new_account_id == account_id
      errors.add(:account_id, 'already using this account, cannot switch')
    elsif !accounts.where(id: new_account_id).exists?
      errors.add(:account_id, 'user does not have a link to this account')
    else
      update(account_id: new_account_id)
      update_signin_info
    end
  end

  def reset_email_token_expired?
    reset_email_token && reset_email_sent_at < 1.day.ago
  end

  private

  def link_account
    AccountUser.create(account_id: account_id, user_id: id)
  end

  def validate_password
    return if password_tmp.nil?
    if password_tmp.size < 8
      errors.add(:password, 'must be greater than 8 characters')
    elsif password_tmp !~ /[A-Z]/
      errors.add(:password, 'missing upper case character')
    elsif password_tmp !~ /[a-z]/
      errors.add(:password, 'missing lower case character')
    elsif password_tmp !~ /[0-9]/
      errors.add(:password, 'missing number')
    elsif password_tmp =~ /\s/
      errors.add(:password, 'should not included invalid character')
    elsif password_tmp !~ /[<>!@#%&=_\-;,\^$?\[\]{}+.*\\\/()]/
      errors.add(:password, 'should require special char')
    end
    self.password_tmp = nil
  end

  class << self
    def random_password
      SecureRandom.urlsafe_base64
    end
  end
end

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  active                 :boolean          default(TRUE)
#  admin                  :boolean          default(FALSE)
#  consumed_timestep      :integer
#  email                  :string(255)
#  encrypted_password     :string(255)
#  failed_attempts        :integer          default(0)
#  first_name             :string(255)
#  last_action_at         :datetime
#  last_name              :string(255)
#  last_sign_in_at        :datetime
#  level                  :integer          default("full")
#  live_preview_url       :string(255)
#  locked_at              :datetime
#  otp_backup_codes       :string           is an Array
#  otp_required_for_login :boolean          default(FALSE)
#  otp_secret             :string
#  reset_email_sent_at    :datetime
#  reset_email_token      :string
#  reset_password_sent_at :datetime
#  reset_password_token   :string(255)
#  sign_in_count          :integer          default(0)
#  unlock_token           :string
#  created_at             :datetime
#  updated_at             :datetime
#  account_id             :integer
#
# Indexes
#
#  index_users_on_account_id    (account_id)
#  index_users_on_email         (email)
#  index_users_on_first_name    (first_name)
#  index_users_on_last_name     (last_name)
#  index_users_on_unlock_token  (unlock_token) UNIQUE
#
