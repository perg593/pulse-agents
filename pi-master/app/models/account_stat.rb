# frozen_string_literal: true
class AccountStat < ActiveRecord::Base
  belongs_to :account
end

# == Schema Information
#
# Table name: account_stats
#
#  id                 :integer          not null, primary key
#  calls_count        :bigint           default(0)
#  calls_count_offset :integer          default(0), not null
#  identifier         :string
#  last_call_at       :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :integer
#
# Indexes
#
#  account_stats_identifier_idx       (identifier)
#  index_account_stats_on_account_id  (account_id)
#
