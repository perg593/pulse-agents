# frozen_string_literal: true

module Schemas
  def self.applied_tag_schema(answer_id)
    applied_tags = AppliedTag.where(answer_id: answer_id).joins(:tag).order("tags.name").map do |applied_tag|
      {
        tagId: applied_tag.tag.id,
        text: applied_tag.tag.name,
        tagApproved: applied_tag.approved?,
        appliedTagId: applied_tag.id,
        tagColor: applied_tag.tag.color
      }
    end

    {
      answerId: answer_id.to_i,
      appliedTags: applied_tags
    }
  end
end
