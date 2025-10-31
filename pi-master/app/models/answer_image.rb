# frozen_string_literal: true

class AnswerImage < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true

  mount_uploader :image, AnswerImageUploader
end

# == Schema Information
#
# Table name: answer_images
#
#  id             :integer          not null, primary key
#  image          :string
#  imageable_type :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  imageable_id   :integer
#
# Indexes
#
#  index_answer_images_on_imageable_type_and_imageable_id  (imageable_type,imageable_id)
#
