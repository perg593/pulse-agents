# frozen_string_literal: true

task backfill_native_impression_device_type: :environment do
  submissions = Submission.where(device_type: nil)
  submissions = submissions.where.not(mobile_type: nil)
  submissions.update_all(device_type: 'native_mobile')
end
