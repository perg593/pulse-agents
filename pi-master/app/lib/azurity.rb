# frozen_string_literal: true

module Azurity
  def self.weekly_report_worker_account_ids
    weekly_report_worker_account_info = AZURITY_CONFIG[:azurity_accounts].select do |account_info|
      AZURITY_CONFIG[:weekly_report_worker_account_identifiers].include?(account_info[:identifier])
    end

    weekly_report_worker_account_info.map { |account_info| account_info[:account_id] }
  end

  # Horizant, Vivimusta, Xatmep, Triptodur, Solutions, Danziten
  def self.adverse_event_account_identifier?(identifier)
    AZURITY_CONFIG[:adverse_event_acount_identifiers].include?(identifier)
  end
end
