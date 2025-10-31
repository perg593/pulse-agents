# frozen_string_literal: true

module Metadata
  class PossibleAnswerMetadatum < Metadatum
    audited associated_with: :possible_answer

    belongs_to :possible_answer, foreign_key: :owner_record_id

    validate :name_unique_in_questions

    def name_unique_in_questions
      return unless possible_answer
      return unless PossibleAnswerMetadatum.where(owner_record_id: possible_answer.question.possible_answer_ids, name: name).where.not(id: id).exists?

      errors.add(:name, "must be unique in questions")
    end
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
