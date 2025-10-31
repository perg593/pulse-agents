# frozen_string_literal: true

class WorkerOutputCopy < ApplicationRecord
  scope :for_worker, ->(worker) { where(worker_name: worker.name.underscore) }
end

# == Schema Information
#
# Table name: worker_output_copies
#
#  id          :bigint           not null, primary key
#  file_name   :string
#  signed_url  :string
#  worker_name :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
