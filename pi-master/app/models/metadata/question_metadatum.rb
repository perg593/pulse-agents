# frozen_string_literal: true

module Metadata
  class QuestionMetadatum < Metadatum
    audited associated_with: :question

    belongs_to :question, class_name: "Question", foreign_key: :owner_record_id

    validate :name_unique_in_survey

    def name_unique_in_survey
      return unless question
      return unless QuestionMetadatum.where(owner_record_id: question.survey.question_ids, name: name).where.not(id: id).exists?

      errors.add(:name, "must be unique in survey")
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
