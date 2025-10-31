# frozen_string_literal: true

task attach_account_stats: :environment do
  Account.all.each do |account|
    next if account.account_stat

    AccountStat.create(account: account, identifier: account.identifier, calls_count: account.calls_count, last_call_at: account.last_call_at)
  end
end
