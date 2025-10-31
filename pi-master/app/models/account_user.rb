# frozen_string_literal: true
class AccountUser < ActiveRecord::Base
  belongs_to :account
  belongs_to :user

  after_destroy :sync_orphaned_users

  private

  def sync_orphaned_users
    if user.account_users.exists?
      if user.account_id == account_id
        user.switch_accounts(user.accounts.first.id)
      end
    else
      user.destroy
    end
  end
end

# == Schema Information
#
# Table name: account_users
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_account_users_on_account_id              (account_id)
#  index_account_users_on_account_id_and_user_id  (account_id,user_id) UNIQUE
#  index_account_users_on_user_id                 (user_id)
#
