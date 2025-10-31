# frozen_string_literal: true

module Metadata
  class Metadatum < ApplicationRecord
    validates :name, presence: true
  end
end

# == Schema Information
#
# Table name: metadata
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  type            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  owner_record_id :integer          not null
#
# Indexes
#
#  index_metadata_on_type_and_owner_record_id  (type,owner_record_id) UNIQUE
#
