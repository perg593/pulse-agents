# frozen_string_literal: true
module Control
  class AnswerImagesController < BaseController
    def create
      @answer_image = AnswerImage.new(
        answer_image_params.merge(
          imageable_type: "Account",
          imageable_id: current_user.account_id
        )
      )

      # rubocop:disable Style/GuardClause
      # deal with it, rubocop
      if @answer_image.save
        render json: { answerImage: { id: @answer_image.id, url: @answer_image.image.url }}, status: :ok and return
      else
        render json: { error: @answer_image.errors.full_messages.join(',') }, status: 500 and return
      end
    end

    private

    def answer_image_params
      params.require(:answer_image).permit(:image)
    end
  end
end
